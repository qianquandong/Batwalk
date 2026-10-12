import XCTest
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    @MainActor
    func testOpeningGreetingNeverChangesRewardsSaveOrSync() throws {
        var commits = 0
        var syncs = 0
        let (watch, _) = try makeStore(commit: { context in commits += 1; try context.save() },
                                        onCommit: { _ in syncs += 1 })
        try watch.mutate {
            $0.start(seed: 1, now: .now)
            $0.ingestSteps(dayKey: "2026-10-11", dailyTotal: 2_000)
            _ = try $0.hatch(now: .now)
            for day in 1...10 {
                for _ in 0..<10 { _ = try $0.pet("mochi", dayKey: "day-\(day)") }
            }
        }
        let before = watch.state
        let oldCommits = commits
        let oldSyncs = syncs
        XCTAssertEqual(watch.companionOpeningRequest(time: .night, motionAllowed: true)?.actionIDs, ["thumb-ear-wash"])
        XCTAssertNil(watch.companionOpeningRequest(time: .night, motionAllowed: true))
        watch.endCompanionVisit()
        XCTAssertNotNil(watch.companionOpeningRequest(time: .night, motionAllowed: true))
        XCTAssertEqual(watch.state, before)
        XCTAssertEqual(commits, oldCommits)
        XCTAssertEqual(syncs, oldSyncs)
        let (phone, _) = try makeStore(role: .phone)
        phone.applyMirror(try JSONEncoder().encode(before))
        XCTAssertNil(phone.companionOpeningRequest(time: .night, motionAllowed: true))
    }
}
