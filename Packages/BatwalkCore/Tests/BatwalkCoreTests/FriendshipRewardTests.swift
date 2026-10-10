import XCTest
@testable import BatwalkCore

final class FriendshipRewardTests: XCTestCase {
    func testPermanentKeepsakesAtEveryThreshold() {
        let expected: [String?] = [nil, "Heart charm", "Forest charm", "Star charm", "Best friend crown"]
        for (i, threshold) in Tuning.default.friendshipThresholds.enumerated() {
            XCTAssertEqual(Friendship.keepsake(forEXP: threshold), expected[i])
            if i > 0 { XCTAssertEqual(Friendship.keepsake(forEXP: threshold - 1), expected[i - 1]) }
        }
        XCTAssertEqual(Friendship.nextKeepsake(forEXP: 0), "Heart charm")
        XCTAssertNil(Friendship.nextKeepsake(forEXP: 1_000_000))
    }
}
