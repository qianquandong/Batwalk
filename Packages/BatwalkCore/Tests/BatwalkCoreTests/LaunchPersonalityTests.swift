import XCTest
@testable import BatwalkCore

final class LaunchPersonalityTests: XCTestCase {
    func testEveryDesignedLaunchActionHasArtAndCorrectLevelGate() throws {
        let launch = Roster.catalog.filter { $0.number <= 20 }
        XCTAssertEqual(launch.count, 20)
        var actions = 0
        var frames = Set<String>()
        for species in launch {
            let designed = ActionCatalog.actions(for: species.id)
            XCTAssertEqual(PilotAnimationCatalog.playableActions(for: species.id), designed)
            for action in designed {
                actions += 1
                for level in 0...5 {
                    let clip = PilotAnimationCatalog.unique(for: species.id, actionID: action.id, friendshipLevel: level)
                    XCTAssertEqual(clip != nil, level >= action.unlockLevel, "\(species.id)/\(action.id)/\(level)")
                }
                let clip = try XCTUnwrap(PilotAnimationCatalog.unique(for: species.id, actionID: action.id, friendshipLevel: 5))
                XCTAssertEqual(clip.actionID, action.id)
                XCTAssertTrue(clip.frames.allSatisfy { $0.seconds >= 0.1 && $0.seconds <= 1.2 && $0.offsetX == 0 })
                XCTAssertLessThanOrEqual(clip.frames.reduce(0) { $0 + $1.seconds }, 3)
                frames.formUnion(clip.frames.map(\.assetName))
            }
        }
        XCTAssertEqual(actions, 64)
        XCTAssertEqual(frames.count, 256) // Four portrait-derived poses per action.
        XCTAssertNil(PilotAnimationCatalog.unique(for: "ghost", actionID: "gift-giver", friendshipLevel: 5))
        XCTAssertNil(PilotAnimationCatalog.unique(for: "cocoa", actionID: "fruit-hug", friendshipLevel: 5))
    }

    func testInteractionsUseTheirActualDesignedTriggersAndFallbackBelowUnlock() {
        for species in Roster.catalog.filter({ $0.number <= 20 }) {
            for (event, trigger) in [(BatAnimationEvent.pet, ActionTrigger.pet), (.feed, .feed),
                                      (.walkReturn, .walkReturn), (.newDay, .newDay), (.hatch, .hatch)] {
                for level in 1...5 {
                    let expected = ActionCatalog.available(for: species.id, friendshipLevel: level, trigger: trigger)
                    let actual = PilotAnimationCatalog.reactions(for: species.id, event: event, friendshipLevel: level)
                    if !expected.isEmpty { XCTAssertEqual(actual.map(\.actionID), expected.map(\.id)) }
                    else if event == .newDay || event == .hatch { XCTAssertTrue(actual.isEmpty) }
                    else { XCTAssertEqual(actual.map(\.actionID), [event == .pet ? "pet" : event == .feed ? "eat" : "fly"]) }
                }
            }
        }
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "vampire", event: .feed, friendshipLevel: 4)?.actionID, "share-dinner")
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "galaxy", event: .hatch, friendshipLevel: 1)?.actionID, "star-map-hatch")
    }

    func testUnlockCelebratesAllCrossedTiersAndDoesNotRepeatMatchingReaction() {
        let request = BatAnimationRequest.interaction(.pet, speciesID: "mochi", levelBefore: 1, levelAfter: 4)
        XCTAssertEqual(request.actionIDs, ["thumb-ear-wash", "wing-eye-mask", "cartwheel-landing"])
        let clips = PilotAnimationCatalog.clips(for: request, speciesID: "mochi", friendshipLevel: 4)
        XCTAssertEqual(clips.map(\.actionID), ["wing-eye-mask", "thumb-ear-wash", "cartwheel-landing"])
        let normal = BatAnimationRequest.interaction(.pet, speciesID: "mochi", levelBefore: 3, levelAfter: 3)
        XCTAssertTrue(normal.actionIDs.isEmpty)
        // Explicit requests also obey friendship, even in a preview.
        XCTAssertTrue(PilotAnimationCatalog.clips(for: BatAnimationRequest(actionIDs: ["cartwheel-landing"]),
                                                 speciesID: "mochi", friendshipLevel: 1).isEmpty)
    }

    func testIdleUsesLocalPeriodAndOncePerPeriodRatherThanEveryLoop() {
        var memory = BatAmbientMemory()
        func next(_ id: String, _ level: Int, _ time: TimeOfDay, _ day: String = "2026-10-11") -> String? {
            memory.next(speciesID: id, friendshipLevel: level, time: time, day: day, minute: 1, rareRoll: 23)?.actionID
        }
        XCTAssertNil(next("mochi", 1, .night))
        XCTAssertNil(next("mochi", 2, .day))
        XCTAssertEqual(next("mochi", 2, .night), "thumb-ear-wash")
        XCTAssertNil(next("mochi", 2, .night))
        XCTAssertEqual(next("mochi", 2, .night, "2026-10-12"), "thumb-ear-wash")
        XCTAssertEqual(next("sunset", 4, .dusk), "sunset-compass")
        XCTAssertEqual(next("sunset", 4, .dusk), "batnado")
        XCTAssertNil(next("sunset", 4, .dusk))
        XCTAssertNil(next("sunset", 4, .night))
        XCTAssertEqual(next("moonwing", 4, .day), "termite-mound-den")
    }

    func testLegendarySecretsRespectLevelClockAndOneRollPerMinute() {
        var memory = BatAmbientMemory()
        func next(_ level: Int, _ time: TimeOfDay, _ minute: Int, _ roll: Int) -> String? {
            memory.next(speciesID: "eclipse", friendshipLevel: level, time: time, day: "2026-10-11",
                        minute: minute, rareRoll: roll)?.actionID
        }
        XCTAssertNil(next(4, .day, 1, 0))
        XCTAssertNil(next(5, .dusk, 2, 0))
        XCTAssertNil(next(5, .day, 3, 23))
        XCTAssertNil(next(5, .day, 3, 0)) // No repeated roll in the same minute.
        XCTAssertEqual(next(5, .day, 4, 0), "midday-dusk")
        XCTAssertNil(next(5, .day, 5, 0)) // A rare secret cannot loop all day.
    }

    func testExplicitPreviewIsConsumedEvenWhenMotionIsDisabled() {
        var memory = BatAnimationConsumption()
        let request = BatAnimationRequest(actionIDs: ["star-map-hatch"])
        XCTAssertFalse(memory.consume(request, enabled: false))
        XCTAssertFalse(memory.consume(request, enabled: true))
        let fresh = BatAnimationRequest(actionIDs: ["star-map-hatch"])
        XCTAssertTrue(memory.consume(fresh, enabled: true))
        XCTAssertFalse(memory.consume(fresh, enabled: true))
    }

    func testUnlockPreviewDoesNotImmediatelyRepeatAsAnAmbientBeat() throws {
        var memory = BatAmbientMemory()
        let clip = try XCTUnwrap(PilotAnimationCatalog.unique(for: "mochi", actionID: "thumb-ear-wash", friendshipLevel: 2))
        memory.record(clip, time: .night, day: "2026-10-11")
        XCTAssertNil(memory.next(speciesID: "mochi", friendshipLevel: 2, time: .night,
                                 day: "2026-10-11", minute: 1, rareRoll: 23))
    }
}
