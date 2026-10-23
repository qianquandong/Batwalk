import XCTest
@testable import BatwalkCore

/// Runs `body` with a different enabled content wave, then restores the default.
func withContentWave<T>(_ wave: Int, _ body: () throws -> T) rethrows -> T {
    let previous = Roster.enabledWave
    Roster.enabledWave = wave
    defer { Roster.enabledWave = previous }
    return try body()
}

final class RosterTests: XCTestCase {
    func testCatalogHas32UniqueSpeciesNumbered1to32() {
        XCTAssertEqual(Roster.catalog.count, 32)
        XCTAssertEqual(Set(Roster.catalog.map(\.id)).count, 32)
        XCTAssertEqual(Roster.catalog.map(\.number), Array(1...32))
    }

    func testRarityCountsMatchPRD() {
        // Launch roster 8 / 6 / 4 / 2 (§6) + Oddball Bats 2 / 5 / 4 / 1 (§6.3).
        let counts = Dictionary(grouping: Roster.catalog, by: \.rarity).mapValues(\.count)
        XCTAssertEqual(counts[.common], 10)
        XCTAssertEqual(counts[.uncommon], 11)
        XCTAssertEqual(counts[.rare], 8)
        XCTAssertEqual(counts[.legendary], 3)
        let launch = Dictionary(grouping: Roster.all, by: \.rarity).mapValues(\.count)
        XCTAssertEqual(launch[.common], 8)
        XCTAssertEqual(launch[.legendary], 2)
    }

    func testLaunchSpeciesIDsAreUnchanged() {
        // Save keys and asset names — must never change (CLAUDE.md).
        let launch = [
            "mochi", "cocoa", "long-ear", "fruit", "cave", "sleepy", "dust", "pebble",
            "strawberry", "blossom", "moss", "sunset", "snow", "cloud",
            "moonwing", "golden", "crystal", "vampire", "galaxy", "eclipse",
        ]
        XCTAssertEqual(Roster.catalog.prefix(20).map(\.id), launch)
        XCTAssertEqual(Roster.all.map(\.id), launch)
    }

    func testOddballBatsAreFreeWaveTwoAndHaveARealLifeCousin() {
        let oddballs = Roster.catalog.filter { $0.number > 20 }
        XCTAssertEqual(oddballs.map(\.id), [
            "bumblebee", "sticky", "marshmallow", "honk", "ember", "nectar",
            "tube-nose", "polka", "wrinkle", "walker", "fox", "ghost",
        ])
        for bat in oddballs {
            XCTAssertTrue(bat.isFree, "\(bat.id) must never need payment")
            XCTAssertFalse(bat.realLifeCousin?.isEmpty ?? true, "\(bat.id) is missing its real-life cousin")
            XCTAssertEqual(bat.wave, 2, "\(bat.id) ships in the first content update (Q12)")
        }
        XCTAssertTrue(Roster.catalog.prefix(20).allSatisfy { $0.realLifeCousin == nil && $0.wave == 1 })
    }

    func testLaunchBuildHidesOddballsUntilTheirWaveIsEnabled() {
        XCTAssertEqual(Roster.enabledWave, 1)
        XCTAssertEqual(Roster.all.count, 20)
        XCTAssertNotNil(Roster.species("ghost"), "old saves and Batpedia numbers must still resolve")
        XCTAssertFalse(Roster.isAvailable("ghost"))
        for egg in EggType.allCases {
            XCTAssertTrue(egg.pool.allSatisfy { Roster.species($0)?.wave == 1 }, "\(egg) leaks a wave-2 species")
        }
        XCTAssertEqual(Set(EggType.allCases.flatMap(\.pool)), Set(Roster.all.map(\.id)))

        withContentWave(2) {
            XCTAssertEqual(Roster.all.count, 32)
            XCTAssertTrue(Roster.isAvailable("ghost"))
            XCTAssertTrue(EggType.crystal.pool.contains("ghost"))
            XCTAssertTrue(EggType.crystal.pool.contains("walker"))
            XCTAssertEqual(Set(EggType.allCases.flatMap(\.pool)), Set(Roster.catalog.map(\.id)))
        }
        XCTAssertEqual(Roster.all.count, 20)
    }

    func testEachSpeciesAppearsAtMostOncePerEgg() {
        for egg in EggType.allCases {
            XCTAssertEqual(egg.designedPool.count, Set(egg.designedPool).count, "\(egg) pool has a duplicate")
        }
    }

    func testEveryEnabledBatAndEggIsFree() {
        XCTAssertEqual(Roster.freeSpecies, Roster.all)
        XCTAssertEqual(EggType.allCases.filter(\.isFree), EggType.allCases)
    }

    func testLongEarHatchesFromTinyAndForest() {
        // Q1 (decided 2026-10-10): the third free bat has a free egg to come from.
        XCTAssertTrue(EggType.tiny.pool.contains("long-ear"))
        XCTAssertTrue(EggType.forest.pool.contains("long-ear"))
        XCTAssertEqual(EggType.primaryEgg(for: "long-ear"), .tiny)
        XCTAssertEqual(EggType.primaryEgg(for: "moonwing"), .moon)
        XCTAssertEqual(EggType.primaryEgg(for: "ghost"), .crystal)
        XCTAssertEqual(EggType.primaryEgg(for: "not-a-bat"), .tiny)
    }

    func testEveryPoolReferencesRealSpecies() {
        for egg in EggType.allCases {
            for id in egg.designedPool + egg.freePool {
                XCTAssertNotNil(Roster.species(id), "\(egg) references unknown species \(id)")
            }
        }
    }

    func testEverySpeciesIsHatchableFromSomeEgg() {
        let reachable = Set(EggType.allCases.flatMap(\.pool))
        XCTAssertEqual(reachable, Set(Roster.all.map(\.id)))
        let designed = Set(EggType.allCases.flatMap(\.designedPool))
        XCTAssertEqual(designed, Set(Roster.catalog.map(\.id)))
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
        XCTAssertEqual(EggType.tiny.targetSteps, 10_000)
        XCTAssertEqual(EggType.forest.targetSteps, 40_000)
        XCTAssertEqual(EggType.moon.targetSteps, 50_000)
        XCTAssertEqual(EggType.crystal.targetSteps, 60_000)
    }

    func testPickableEggs() {
        XCTAssertEqual(EggType.pickable(isUnlocked: false), EggType.allCases)
        XCTAssertEqual(EggType.pickable(isUnlocked: true), EggType.allCases)
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

    func testEntitlementNeverChangesAnyPoolOrShinyOutcome() {
        for egg in EggType.allCases {
            XCTAssertEqual(egg.pool(isUnlocked: false), egg.pool(isUnlocked: true))
            var sawShiny = false
            for seed in UInt64(0)..<2_000 {
                let free = HatchEngine.roll(egg: egg, seed: seed, isUnlocked: false)
                XCTAssertEqual(free, HatchEngine.roll(egg: egg, seed: seed, isUnlocked: true))
                sawShiny = sawShiny || free.isShiny
            }
            XCTAssertTrue(sawShiny, "Every egg can hatch Shiny without payment")
        }
    }

    func testTinyEggCanYieldEveryEnabledCommon() {
        let seen = Set((UInt64(0)..<2_000).map { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: false).species.id })
        XCTAssertEqual(seen, Set(EggType.tiny.pool))
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

    func testShinyRateMatchesTuning() {
        let n = 200_000
        var shinies = 0
        for seed in 0..<n where HatchEngine.roll(egg: .crystal, seed: UInt64(seed) &* 104_729, isUnlocked: true).isShiny {
            shinies += 1
        }
        XCTAssertEqual(Double(shinies) / Double(n), Tuning.default.shinyChance, accuracy: 0.004)
        XCTAssertEqual(Tuning.default.shinyChance, 0.03)
    }

    func testPaidTinyEggIsStillAllCommon() {
        let rolls = (UInt64(0)..<5_000).map { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: true).species }
        XCTAssertTrue(rolls.allSatisfy { $0.rarity == .common })
        XCTAssertTrue(Set(rolls.map(\.id)).isSuperset(of: ["mochi", "cocoa", "long-ear", "cave", "sleepy", "pebble"]))
        withContentWave(2) {
            let wave2 = Set((UInt64(0)..<5_000).map { HatchEngine.roll(egg: .tiny, seed: $0, isUnlocked: true).species.id })
            XCTAssertTrue(wave2.isSuperset(of: ["bumblebee", "sticky"]))
        }
    }

    func testCrystalEggCanYieldWalkerAndGhostOnceWaveTwoShips() {
        let launch = Set((UInt64(0)..<20_000).map { HatchEngine.roll(egg: .crystal, seed: $0, isUnlocked: true).species.id })
        XCTAssertFalse(launch.contains("walker"))
        withContentWave(2) {
            let seen = Set((UInt64(0)..<20_000).map { HatchEngine.roll(egg: .crystal, seed: $0, isUnlocked: true).species.id })
            XCTAssertTrue(seen.contains("walker"))
            XCTAssertTrue(seen.contains("ghost"))
        }
    }

    func testMoonEggCanYieldLegendary() {
        let rarities = Set((UInt64(0)..<5_000).map { HatchEngine.roll(egg: .moon, seed: $0, isUnlocked: true).species.rarity })
        XCTAssertTrue(rarities.contains(.legendary))
        XCTAssertFalse(rarities.contains(.common))
    }
}
