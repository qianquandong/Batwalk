import XCTest
@testable import BatwalkCore

final class BatAnimationTests: XCTestCase {
    func testUniversalReactionsDoNotRequireFriendshipAndSignaturesUnlockAtFour() {
        for species in PilotAnimationCatalog.pilotSpeciesIDs {
            for level in 1...5 {
                XCTAssertNotNil(PilotAnimationCatalog.reaction(for: species, event: .pet, friendshipLevel: level))
                XCTAssertNotNil(PilotAnimationCatalog.reaction(for: species, event: .feed, friendshipLevel: level))
                XCTAssertEqual(PilotAnimationCatalog.signature(for: species, friendshipLevel: level) != nil, level >= 4)
            }
        }
        XCTAssertNotNil(PilotAnimationCatalog.signature(for: "galaxy", friendshipLevel: 5))
        XCTAssertNil(PilotAnimationCatalog.universal(for: "missing", action: .idle))
    }

    func testEveryCataloguedSpeciesHasAnIdentityPreservingFallback() {
        XCTAssertEqual(Set(PilotAnimationCatalog.speciesIDs), Set(Roster.catalog.map(\.id)))
        XCTAssertEqual(PilotAnimationCatalog.portraitSpeciesIDs.count, Roster.catalog.count - 3)
        XCTAssertTrue(PilotAnimationCatalog.portraitSpeciesIDs.allSatisfy { !PilotAnimationCatalog.pilotSpeciesIDs.contains($0) })
        for species in PilotAnimationCatalog.portraitSpeciesIDs {
            for level in 1...5 {
                XCTAssertNotNil(PilotAnimationCatalog.reaction(for: species, event: .pet, friendshipLevel: level))
                XCTAssertNotNil(PilotAnimationCatalog.reaction(for: species, event: .feed, friendshipLevel: level))
                if Roster.species(species)!.number > 20 {
                    // Wave two keeps its portrait; no invented signature frames.
                    XCTAssertNil(PilotAnimationCatalog.signature(for: species, friendshipLevel: level), species)
                    XCTAssertNil(PilotAnimationCatalog.reaction(for: species, event: .newDay, friendshipLevel: level), species)
                } else {
                    XCTAssertEqual(PilotAnimationCatalog.signature(for: species, friendshipLevel: level) != nil, level >= 4)
                }
            }
            XCTAssertNotNil(PilotAnimationCatalog.reaction(for: species, event: .walkReturn, friendshipLevel: 5))
        }
    }

    func testUniversalFallbackCannotReturnDiscardedCharacterArt() throws {
        for species in PilotAnimationCatalog.portraitSpeciesIDs {
            for action in UniversalAction.allCases {
                let clip = try XCTUnwrap(PilotAnimationCatalog.universal(for: species, action: action))
                XCTAssertEqual(clip.frames.count, 1)
                XCTAssertEqual(clip.frames.first?.assetName, "portrait_bat_\(species)")
                XCTAssertEqual(clip.actionID, action.rawValue)
                XCTAssertEqual(clip.frames.first?.offsetX, 0)
                XCTAssertEqual(clip.restSeconds, action == .idle || action == .sleep ? 4 : 0)
            }
            for mood in [BatMood.sleeping, .drowsy, .awake, .happy, .eating, .playing] {
                XCTAssertEqual(PilotAnimationCatalog.still(for: species, mood: mood), "portrait_bat_\(species)")
            }
        }
    }
    func testNaturalTriggersUseTheDesignedSignatureOrUniversalFlyFallback() {
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "mochi", event: .walkReturn, friendshipLevel: 4)?.actionID, "cartwheel-landing")
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "walker", event: .walkReturn, friendshipLevel: 4)?.actionID, "power-walk")
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "sticky", event: .newDay, friendshipLevel: 4)?.actionID, "moving-day")
        XCTAssertNil(PilotAnimationCatalog.reaction(for: "sticky", event: .newDay, friendshipLevel: 3))
        XCTAssertNil(PilotAnimationCatalog.reaction(for: "mochi", event: .newDay, friendshipLevel: 5))
        XCTAssertEqual(PilotAnimationCatalog.reaction(for: "walker", event: .walkReturn, friendshipLevel: 1)?.actionID, "fly")
    }

    func testOnlyVisibleActiveFullBrightnessMotionEnabledPageMayAnimate() {
        for page in [false, true] {
            for active in [false, true] {
                for dim in [false, true] {
                    for reduced in [false, true] {
                        XCTAssertEqual(BatPlaybackPolicy.permitsAnimation(pageVisible: page, sceneActive: active,
                            luminanceReduced: dim, reduceMotion: reduced), page && active && !dim && !reduced)
                    }
                }
            }
        }
    }

    func testConsumedOrDisabledReactionCannotReplayAfterTaskRestart() {
        var memory = BatAnimationConsumption()
        let first = BatAnimationRequest([.pet, .signature])
        XCTAssertEqual(memory.take(first, enabled: true), [.pet, .signature])
        XCTAssertEqual(memory.take(first, enabled: true), [])
        XCTAssertEqual(memory.take(first, enabled: false), [])
        XCTAssertEqual(memory.take(first, enabled: true), [])
        let disabled = BatAnimationRequest([.feed])
        XCTAssertEqual(memory.take(disabled, enabled: false), [])
        XCTAssertEqual(memory.take(disabled, enabled: true), [])
        XCTAssertEqual(memory.take(BatAnimationRequest([.feed]), enabled: true), [.feed])
    }

    func testVisitDoesNotCelebrateHistoricalStepsOrRepeatAcrossLaunches() throws {
        var visits = BatVisitMemory()
        XCTAssertEqual(visits.visit(speciesID: "mochi", day: "2026-10-09", creditedSteps: 8000), [.newDay])
        XCTAssertEqual(visits.visit(speciesID: "mochi", day: "2026-10-09", creditedSteps: 8000), [])
        let data = try JSONEncoder().encode(visits)
        visits = try JSONDecoder().decode(BatVisitMemory.self, from: data)
        XCTAssertEqual(visits.visit(speciesID: "mochi", day: "2026-10-09", creditedSteps: 8000), [])
        XCTAssertEqual(visits.visit(speciesID: "mochi", day: "2026-10-09", creditedSteps: 8100), [.walkReturn])
        XCTAssertEqual(visits.visit(speciesID: "mochi", day: "2026-10-10", creditedSteps: 8100), [.newDay])
        XCTAssertEqual(visits.visit(speciesID: "sticky", day: "2026-10-10", creditedSteps: 8100), [.newDay])
    }

    func testVisitCanRecoverAfterRestoringALowerStepTotal() {
        var visits = BatVisitMemory()
        _ = visits.visit(speciesID: "walker", day: "2026-10-10", creditedSteps: 9000)
        XCTAssertEqual(visits.visit(speciesID: "walker", day: "2026-10-10", creditedSteps: 2000), [])
        XCTAssertEqual(visits.visit(speciesID: "walker", day: "2026-10-10", creditedSteps: 2100), [.walkReturn])
    }

    func testAnimationHasBoundedCadenceAndWalkerEndsWithNectar() throws {
        for species in PilotAnimationCatalog.pilotSpeciesIDs {
            let clips = UniversalAction.allCases.compactMap { PilotAnimationCatalog.universal(for: species, action: $0) }
                + [try XCTUnwrap(PilotAnimationCatalog.signature(for: species, friendshipLevel: 4))]
            for clip in clips {
                XCTAssertTrue(clip.frames.allSatisfy { $0.seconds >= 0.16 && abs($0.offsetX) <= 0.121 })
                XCTAssertTrue(clip.frames.allSatisfy { $0.assetName.hasPrefix("pilot_bat_") })
                XCTAssertLessThan(clip.frames.reduce(0) { $0 + $1.seconds }, 4)
            }
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(PilotAnimationCatalog.ambient(for: species, mood: .awake)).restSeconds, 3)
        }
        let walk = try XCTUnwrap(PilotAnimationCatalog.signature(for: "walker", friendshipLevel: 4))
        XCTAssertEqual(walk.frames.last?.assetName, "pilot_bat_walker_power-walk_5")
        XCTAssertLessThan(try XCTUnwrap(walk.frames.first?.offsetX), try XCTUnwrap(walk.frames.last?.offsetX))
    }
}
