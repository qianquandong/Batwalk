import XCTest
@testable import BatwalkCore

final class RosterTests: XCTestCase {
    func testRosterHas20UniqueSpeciesNumbered1to20() {
        XCTAssertEqual(Roster.all.count, 20)
        XCTAssertEqual(Set(Roster.all.map(\.id)).count, 20)
        XCTAssertEqual(Roster.all.map(\.number), Array(1...20))
    }

    func testRarityCountsMatchPRD() {
        let counts = Dictionary(grouping: Roster.all, by: \.rarity).mapValues(\.count)
        XCTAssertEqual(counts[.common], 8)
        XCTAssertEqual(counts[.uncommon], 6)
        XCTAssertEqual(counts[.rare], 4)
        XCTAssertEqual(counts[.legendary], 2)
    }

    func testFreeTierIsMochiCocoaLongEar() {
        XCTAssertEqual(Roster.freeSpecies.map(\.id), ["mochi", "cocoa", "long-ear"])
        XCTAssertEqual(EggType.allCases.filter(\.isFree), [.starter, .tiny])
    }

    func testEveryPoolReferencesRealSpecies() {
        for egg in EggType.allCases {
            for id in egg.pool + egg.freePool {
                XCTAssertNotNil(Roster.species(id), "\(egg) references unknown species \(id)")
            }
        }
    }

    func testEverySpeciesIsHatchableFromSomeEgg() {
        let reachable = Set(EggType.allCases.flatMap(\.pool))
        XCTAssertEqual(reachable, Set(Roster.all.map(\.id)))
    }

    func testFreePoolsOnlyContainFreeSpecies() {
        for egg in EggType.allCases {
            for id in egg.freePool {
                XCTAssertTrue(Roster.species(id)!.isFree, "\(id) in free pool of \(egg)")
            }
        }
    }

    func testEggTargets() {
        XCTAssertEqual(EggType.starter.targetSteps, 2_000)
        XCTAssertEqual(EggType.tiny.targetSteps, 2_500)
        XCTAssertEqual(EggType.forest.targetSteps, 4_000)
        XCTAssertEqual(EggType.moon.targetSteps, 5_000)
        XCTAssertEqual(EggType.crystal.targetSteps, 6_000)
    }

    func testPickableEggs() {
        XCTAssertEqual(EggType.pickable(isUnlocked: false), [.tiny])
        XCTAssertEqual(EggType.pickable(isUnlocked: true), [.tiny, .forest, .moon, .crystal])
    }
}

final class HatchEngineTests: XCTestCase {
    func testSameSeedSameResult() {
        for seed in UInt64(0)..<200 {
            let a = HatchEngine.roll(egg: .moon, seed: seed, isUnlocked: true)
            let b = HatchEngine.roll(egg: .moon, seed: seed, isUnlocked: true)
            XCTAssertEqual(a, b)
        }
    }

    func testStarterAlwaysMochi() {
        for seed in UInt64(0)..<500 {
            XCTAssertEqual(HatchEngine.roll(egg: .starter, seed: seed, isUnlocked: false).species.id, "mochi")
        }
    }

    func testFreePlayerNeverGetsPaidContentOrShiny() {
        for seed in UInt64(0)..<20_000 {
            let roll = HatchEngine.roll(egg: .tiny, seed: seed, isUnlocked: false)
            XCTAssertTrue(roll.species.isFree)
            XCTAssertFalse(roll.isShiny)
        }
    }

    func testFreeTinyEggCanYieldAllThreeFreeSpecies() {
        let seen = Set((UInt64(0)..<2_000).map { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false).species.id })
        XCTAssertEqual(seen, ["mochi", "cocoa", "long-ear"])
    }

    func testForestRarityDistributionRoughlyMatchesWeights() {
        // Forest has Common + Uncommon only → 65 / (65+25) ≈ 72.2% Common.
        let n = 50_000
        var commons = 0
        for seed in 0..<n where HatchEngine.roll(egg: .forest, seed: UInt64(seed) &* 7919, isUnlocked: true).species.rarity == .common {
            commons += 1
        }
        XCTAssertEqual(Double(commons) / Double(n), 65.0 / 90.0, accuracy: 0.02)
    }

    func testShinyRateRoughlyHalfPercent() {
        let n = 200_000
        var shinies = 0
        for seed in 0..<n where HatchEngine.roll(egg: .crystal, seed: UInt64(seed) &* 104_729, isUnlocked: true).isShiny {
            shinies += 1
        }
        XCTAssertEqual(Double(shinies) / Double(n), 0.005, accuracy: 0.0015)
    }

    func testMoonEggCanYieldLegendary() {
        let rarities = Set((UInt64(0)..<5_000).map { HatchEngine.roll(egg: .moon, seed: $0, isUnlocked: true).species.rarity })
        XCTAssertTrue(rarities.contains(.legendary))
        XCTAssertFalse(rarities.contains(.common))
    }
}
