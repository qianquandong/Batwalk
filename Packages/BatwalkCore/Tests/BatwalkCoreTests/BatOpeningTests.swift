import XCTest
@testable import BatwalkCore

final class BatOpeningTests: XCTestCase {
    func testGreetingIsDeterministicAndChangesWithFriendship() {
        XCTAssertNil(PilotAnimationCatalog.opening(for: "mochi", friendshipLevel: 1, time: .night))
        for level in 2...3 {
            XCTAssertEqual(PilotAnimationCatalog.opening(for: "mochi", friendshipLevel: level, time: .night)?.actionID, "thumb-ear-wash")
        }
        for _ in 0..<10 {
            XCTAssertEqual(PilotAnimationCatalog.opening(for: "mochi", friendshipLevel: 4, time: .night)?.actionID, "cartwheel-landing")
        }
        XCTAssertEqual(PilotAnimationCatalog.opening(for: "cocoa", friendshipLevel: 4, time: .night)?.actionID, "creche-babysitter")
    }

    func testAllLaunchBatsUseOnlyUnlockedShippedHabitsAndRespectDaytime() throws {
        for species in Roster.catalog where species.number <= 20 {
            var hasHabit = false
            for level in 1...5 {
                for time in [TimeOfDay.day, .dusk, .night] {
                    guard let clip = PilotAnimationCatalog.opening(for: species.id, friendshipLevel: level, time: time) else { continue }
                    hasHabit = true
                    let action = try XCTUnwrap(ActionCatalog.actions(for: species.id).first { $0.id == clip.actionID })
                    XCTAssertLessThanOrEqual(action.unlockLevel, level)
                    XCTAssertTrue(action.tier == .idleQuirk || action.tier == .signature)
                    if time == .day { XCTAssertEqual(action.trigger, .asleep) }
                    XCTAssertFalse(clip.frames.isEmpty)
                    XCTAssertLessThanOrEqual(clip.frames.reduce(0) { $0 + $1.seconds }, 3)
                }
            }
            XCTAssertTrue(hasHabit, species.id)
        }
        XCTAssertNil(PilotAnimationCatalog.opening(for: "mochi", friendshipLevel: 5, time: .day))
        XCTAssertEqual(PilotAnimationCatalog.opening(for: "long-ear", friendshipLevel: 2, time: .day)?.actionID, "ram-horn-ears")
        XCTAssertEqual(PilotAnimationCatalog.opening(for: "sunset", friendshipLevel: 4, time: .dusk)?.actionID, "batnado")
    }

    func testPagesLevelsAndWristChangesDoNotReplayUntilLeavingApp() throws {
        var memory = BatOpeningMemory()
        let first = try XCTUnwrap(memory.request(speciesID: "mochi", friendshipLevel: 2, time: .night, motionAllowed: true))
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .dusk, motionAllowed: true))
        XCTAssertNotNil(memory.request(speciesID: "cocoa", friendshipLevel: 4, time: .night, motionAllowed: true))
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
        memory.leaveApp()
        let next = try XCTUnwrap(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
        XCTAssertNotEqual(first.id, next.id)
        XCTAssertEqual(next.actionIDs, ["cartwheel-landing"])
    }

    func testReduceMotionAndLockedGreetingsAreConsumedWithoutLateSurprise() {
        var memory = BatOpeningMemory()
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: false))
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
        memory.leaveApp()
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 1, time: .night, motionAllowed: true))
        XCTAssertNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
        memory.leaveApp()
        XCTAssertNotNil(memory.request(speciesID: "mochi", friendshipLevel: 4, time: .night, motionAllowed: true))
    }
}
