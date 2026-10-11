import XCTest
@testable import BatwalkCore

final class BatActionTests: XCTestCase {
    func testFiveUniversalActionsMapToExistingMoods() {
        XCTAssertEqual(UniversalAction.allCases.map(\.rawValue), ["idle", "sleep", "fly", "pet", "eat"])
        XCTAssertEqual(UniversalAction.allCases.map(\.mood), [.awake, .sleeping, .playing, .happy, .eating])
    }

    func testEverySpeciesHasThreeUniqueActionsAndLegendariesFive() {
        for species in Roster.all {
            let actions = ActionCatalog.actions(for: species.id)
            let tiers = Set(actions.map(\.tier))
            if species.rarity == .legendary {
                XCTAssertEqual(actions.count, 5, species.id)
                XCTAssertEqual(tiers, Set(ActionTier.allCases), species.id)
            } else {
                XCTAssertEqual(actions.count, 3, species.id)
                XCTAssertEqual(tiers, [.idleQuirk, .reaction, .signature], species.id)
            }
        }
    }

    func testCatalogOnlyReferencesRealSpecies() {
        for action in ActionCatalog.all {
            XCTAssertNotNil(Roster.species(action.speciesID), action.assetName)
        }
        XCTAssertEqual(ActionCatalog.all.count, 102)
    }

    func testActionIDsAreUniqueSlugsThatDontCollideWithMoodAssets() {
        let moods = Set(BatMood.allCases.map(\.rawValue))
        let slug = try! NSRegularExpression(pattern: "^[a-z0-9]+(-[a-z0-9]+)*$")
        for species in Roster.all {
            let ids = ActionCatalog.actions(for: species.id).map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count, "\(species.id) has a duplicate action id")
            for id in ids {
                XCTAssertFalse(moods.contains(id), "\(id) collides with a mood sprite name")
                XCTAssertFalse(id.hasSuffix("shiny") || id.hasSuffix("sheet"), id)
                let range = NSRange(id.startIndex..., in: id)
                XCTAssertNotNil(slug.firstMatch(in: id, range: range), "\(id) is not a lowercase slug")
            }
        }
        XCTAssertEqual(Set(ActionCatalog.all.map(\.assetName)).count, ActionCatalog.all.count)
    }

    func testTiersUnlockAtPRDFriendshipLevels() {
        XCTAssertEqual(ActionTier.hatchReveal.unlockLevel, 1)
        XCTAssertEqual(ActionTier.idleQuirk.unlockLevel, 2)
        XCTAssertEqual(ActionTier.reaction.unlockLevel, 3)
        XCTAssertEqual(ActionTier.signature.unlockLevel, 4)
        XCTAssertEqual(ActionTier.secret.unlockLevel, 5)
        XCTAssertTrue(ActionTier.allCases.allSatisfy { (1...Friendship.maxLevel).contains($0.unlockLevel) })
    }

    func testTriggersFitTheirTier() {
        for action in ActionCatalog.all {
            switch action.tier {
            case .reaction:
                XCTAssertTrue([ActionTrigger.pet, .feed].contains(action.trigger), action.assetName)
            case .hatchReveal:
                XCTAssertEqual(action.trigger, .hatch, action.assetName)
            case .secret:
                XCTAssertEqual(action.trigger, .rare, action.assetName)
            case .idleQuirk, .signature:
                XCTAssertFalse([ActionTrigger.hatch, .rare, .pet].contains(action.trigger), action.assetName)
            }
        }
    }

    func testEveryActionHasCopyAndARealBasis() {
        for action in ActionCatalog.all {
            XCTAssertFalse(action.name.isEmpty, action.assetName)
            XCTAssertFalse(action.summary.isEmpty, action.assetName)
            XCTAssertFalse(action.realBasis.isEmpty, action.assetName)
        }
    }

    func testFriendshipOnlyAddsActions() {
        for species in Roster.all {
            var previous = 0
            for level in 1...Friendship.maxLevel {
                let count = ActionCatalog.unlocked(for: species.id, friendshipLevel: level).count
                XCTAssertGreaterThanOrEqual(count, previous, "\(species.id) lost an action at Lv.\(level)")
                previous = count
            }
            XCTAssertEqual(previous, ActionCatalog.actions(for: species.id).count)
        }
    }

    func testLevelOneOnlyHasUniversalActionsExceptLegendaryHatch() {
        XCTAssertTrue(ActionCatalog.unlocked(for: "mochi", friendshipLevel: 1).isEmpty)
        XCTAssertEqual(ActionCatalog.unlocked(for: "galaxy", friendshipLevel: 1).map(\.id), ["star-map-hatch"])
        XCTAssertEqual(ActionCatalog.available(for: "ghost", friendshipLevel: 1, trigger: .hatch).map(\.id),
                       ["moonlit-unveiling"])
    }

    func testAvailableFiltersByTriggerAndLevel() {
        XCTAssertTrue(ActionCatalog.available(for: "mochi", friendshipLevel: 2, trigger: .pet).isEmpty)
        XCTAssertEqual(ActionCatalog.available(for: "mochi", friendshipLevel: 3, trigger: .pet).map(\.id),
                       ["wing-eye-mask"])
        XCTAssertEqual(ActionCatalog.available(for: "walker", friendshipLevel: 4, trigger: .walkReturn).map(\.id),
                       ["power-walk"])
        XCTAssertTrue(ActionCatalog.available(for: "eclipse", friendshipLevel: 4, trigger: .rare).isEmpty)
        XCTAssertEqual(ActionCatalog.available(for: "eclipse", friendshipLevel: 5, trigger: .rare).map(\.id),
                       ["midday-dusk"])
        XCTAssertTrue(ActionCatalog.available(for: "unknown", friendshipLevel: 5, trigger: .pet).isEmpty)
    }

    func testNewlyUnlockedAtEachLevel() {
        XCTAssertEqual(ActionCatalog.newlyUnlocked(for: "vampire", atLevel: 4).map(\.id), ["share-dinner"])
        XCTAssertTrue(ActionCatalog.newlyUnlocked(for: "vampire", atLevel: 5).isEmpty)
        XCTAssertEqual(ActionCatalog.newlyUnlocked(for: "ghost", atLevel: 5).map(\.id), ["cloak-swoop"])
    }

    func testAssetNamesFollowTheSpriteContract() {
        let action = ActionCatalog.actions(for: "marshmallow").first { $0.id == "fig-yellow" }
        XCTAssertEqual(action?.assetName, "bat_marshmallow_fig-yellow")
    }
}
