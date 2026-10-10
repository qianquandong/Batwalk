import XCTest
@testable import BatwalkCore

final class RosterTests: XCTestCase {
    func testRosterHas32UniqueSpeciesNumbered1to32() {
        XCTAssertEqual(Roster.all.count, 32)
        XCTAssertEqual(Set(Roster.all.map(\.id)).count, 32)
        XCTAssertEqual(Roster.all.map(\.number), Array(1...32))
    }

    func testRarityCountsMatchPRD() {
        // Launch roster 8 / 6 / 4 / 2 (§6) + Oddball Bats 2 / 5 / 4 / 1 (§6.3).
        let counts = Dictionary(grouping: Roster.all, by: \.rarity).mapValues(\.count)
        XCTAssertEqual(counts[.common], 10)
        XCTAssertEqual(counts[.uncommon], 11)
        XCTAssertEqual(counts[.rare], 8)
        XCTAssertEqual(counts[.legendary], 3)
    }

    func testLaunchSpeciesIDsAreUnchanged() {
        // Save keys and asset names — must never change (CLAUDE.md).
        XCTAssertEqual(Roster.all.prefix(20).map(\.id), [
            "mochi", "cocoa", "long-ear", "fruit", "cave", "sleepy", "dust", "pebble",
            "strawberry", "blossom", "moss", "sunset", "snow", "cloud",
            "moonwing", "golden", "crystal", "vampire", "galaxy", "eclipse",
        ])
    }

    func testOddballBatsArePaidAndHaveARealLifeCousin() {
        let oddballs = Roster.all.filter { $0.number > 20 }
        XCTAssertEqual(oddballs.map(\.id), [
            "bumblebee", "sticky", "marshmallow", "honk", "ember", "nectar",
            "tube-nose", "polka", "wrinkle", "walker", "fox", "ghost",
        ])
        for bat in oddballs {
            XCTAssertFalse(bat.isFree, "\(bat.id) should need the full unlock")
            XCTAssertFalse(bat.realLifeCousin?.isEmpty ?? true, "\(bat.id) is missing its real-life cousin")
        }
        XCTAssertTrue(Roster.all.prefix(20).allSatisfy { $0.realLifeCousin == nil })
    }

    func testEachSpeciesAppearsAtMostOncePerEgg() {
        for egg in EggType.allCases {
            XCTAssertEqual(egg.pool.count, Set(egg.pool).count, "\(egg) pool has a duplicate")
        }
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

    func testPaidTinyEggIsStillAllCommonAndCanYieldOddballs() {
        let rolls = (UInt64(0)..<5_000).map { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: true).species }
        XCTAssertTrue(rolls.allSatisfy { $0.rarity == .common })
        XCTAssertTrue(Set(rolls.map(\.id)).isSuperset(of: ["bumblebee", "sticky"]))
    }

    func testCrystalEggCanYieldWalkerAndGhost() {
        let seen = Set((UInt64(0)..<20_000).map { HatchEngine.roll(egg: .crystal, seed: $0, isUnlocked: true).species.id })
        XCTAssertTrue(seen.contains("walker"))
        XCTAssertTrue(seen.contains("ghost"))
    }

    func testMoonEggCanYieldLegendary() {
        let rarities = Set((UInt64(0)..<5_000).map { HatchEngine.roll(egg: .moon, seed: $0, isUnlocked: true).species.rarity })
        XCTAssertTrue(rarities.contains(.legendary))
        XCTAssertFalse(rarities.contains(.common))
    }
}
