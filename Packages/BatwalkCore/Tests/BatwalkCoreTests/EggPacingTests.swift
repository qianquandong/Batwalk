import XCTest
@testable import BatwalkCore

final class EggPacingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testNewTinyEggNeedsTenThousandStepsAcrossDays() throws {
        var state = GameState()
        state.start(seed: 1, now: now)
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: 2_000)
        _ = try state.hatch(now: now)
        try state.startEgg(.tiny, seed: 1, now: now)
        XCTAssertEqual(state.egg?.targetSteps, 10_000)
        state.ingestSteps(dayKey: "2026-10-02", dailyTotal: 6_000)
        state.ingestSteps(dayKey: "2026-10-03", dailyTotal: 3_999)
        XCTAssertFalse(state.isEggReady)
        XCTAssertEqual(state.egg?.stepsRemaining, 1)
        state.ingestSteps(dayKey: "2026-10-03", dailyTotal: 4_000)
        XCTAssertTrue(state.isEggReady)
        XCTAssertNoThrow(try state.hatch(now: now))
    }

    func testLegacyEggKeepsItsFinishLineIncludingAlreadyReady() throws {
        for type in EggType.allCases {
            let oldTarget = Tuning.legacyEggTargetSteps[type]!
            for credited in [oldTarget - 1, oldTarget] {
                // The missing target key is the exact shape of a shipping save.
                let old = ActiveEgg(type: type, seed: 42, creditedSteps: credited, startedAt: now)
                let data = try JSONEncoder().encode(old)
                let decoded = try JSONDecoder().decode(ActiveEgg.self, from: data)
                XCTAssertEqual(decoded.targetSteps, oldTarget)
                XCTAssertEqual(decoded.creditedSteps, credited)
                XCTAssertEqual(decoded.isReady, credited == oldTarget)
                XCTAssertEqual(decoded.stepsRemaining, oldTarget - credited)
            }
        }
    }

    func testLegacyGameCanHatchOldEggThenStartAtNewTarget() throws {
        var state = GameState()
        state.start(seed: 1, now: now)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var egg = try XCTUnwrap(json["egg"] as? [String: Any])
        egg["type"] = "tiny"
        egg["creditedSteps"] = 2_500
        egg.removeValue(forKey: "frozenTargetSteps")
        json["egg"] = egg
        state = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(state.isEggReady)
        XCTAssertEqual(try state.hatch(now: now).record.speciesID, "mochi")
        try state.startEgg(.tiny, seed: 42, now: now)
        XCTAssertEqual(state.egg?.targetSteps, 10_000)
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.egg?.targetSteps, 10_000)
        XCTAssertEqual(restored.egg?.frozenSpeciesID, state.egg?.frozenSpeciesID)
    }

    func testRepeatedBatLevelsUpWithoutCreatingCurrencyOrCopies() throws {
        let tuning = Tuning(shinyChance: 0, shinyPityHatches: 0,
                            maxFriendshipShinyMultiplier: 1, newSpeciesPityHatches: 0)
        var state = GameState()
        state.start(seed: 1, now: now, tuning: tuning)
        state.ingestSteps(dayKey: "2026-10-01", dailyTotal: 2_000, tuning: tuning)
        _ = try state.hatch(now: now, tuning: tuning)
        let seed = try XCTUnwrap((UInt64(0)..<10_000).first {
            HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false, tuning: tuning).species.id == "mochi"
        })
        for i in 0..<27 {
            try state.startEgg(.tiny, seed: seed, now: now, tuning: tuning)
            let day = String(format: "2026-10-%02d", i + 2)
            state.ingestSteps(dayKey: day, dailyTotal: 10_000, tuning: tuning)
            let result = try state.hatch(now: now, tuning: tuning)
            XCTAssertEqual(result.friendshipGained, 40)
            XCTAssertEqual(result.moonDustGained, 0)
            XCTAssertEqual(result.record.friendshipBefore, i * 40)
            XCTAssertEqual(result.record.friendshipGained, 40)
            XCTAssertEqual(try JSONDecoder().decode(HatchRecord.self,
                from: JSONEncoder().encode(result.record)), result.record)
            if i == 2 { XCTAssertEqual(Friendship.level(forEXP: result.bat.friendshipEXP), 2) }
        }
        XCTAssertEqual(state.collection.count, 1)
        XCTAssertEqual(state.companion?.friendshipEXP, 1_080)
        XCTAssertEqual(Friendship.level(forEXP: state.companion!.friendshipEXP), 5)
        XCTAssertEqual(state.moonDust, 0)
    }
}
