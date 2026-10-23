import XCTest
import SwiftUI
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    func testOldTransferRetryBytesAreRedactedBeforeRequeue() throws {
        var state = GameState()
        state.start(seed: 1, now: .now.addingTimeInterval(-86_400))
        state.ingestSteps(dayKey: "2026-10-23", dailyTotal: Tuning.introEggTargetSteps)
        _ = try state.hatch(now: .now)
        let original = try JSONEncoder().encode(state)
        let redacted = try XCTUnwrap(PhoneSync.sanitizedMirrorData(original))
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: redacted), state.collectionMirror())
        XCTAssertNil(PhoneSync.sanitizedMirrorData(Data("unknown save".utf8)))
        XCTAssertTrue(PhoneSync.mirrorTransferNeedsRedaction(original))
        XCTAssertFalse(PhoneSync.mirrorTransferNeedsRedaction(redacted))
        XCTAssertTrue(PhoneSync.mirrorTransferNeedsRedaction(nil))
        XCTAssertTrue(PhoneSync.mirrorTransferNeedsRedaction(Data("unknown save".utf8)))
    }

    @MainActor
    func testCertificateAndPosterRenderAtTwelveHundredSquare() async throws {
        var state = GameState()
        state.start(seed: 1, now: .now.addingTimeInterval(-172_800))
        state.ingestSteps(dayKey: "2026-10-23", dailyTotal: Tuning.introEggTargetSteps)
        let record = try state.hatch(now: .now).record
        for showSteps in [false, true] {
            let card = BirthCertificateCard(record: record, nickname: "A very long little nickname",
                                            ordinal: 12, showSteps: showSteps)
            let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            XCTAssertEqual(image.width, 1_200)
            XCTAssertEqual(image.height, 1_200)
        }
        let poster = ImageRenderer(content: CollectionPosterCard(state: state))
        poster.scale = 3
        XCTAssertEqual(poster.uiImage?.cgImage?.width, 1_200)
        XCTAssertEqual(poster.uiImage?.cgImage?.height, 1_200)
    }

    @MainActor
    func testLegacyPhoneArchiveRemovesWalkMetricsFromBothRotatingCopies() async throws {
        let (phone, container) = try makeStore(role: .phone)
        var state = GameState()
        state.start(seed: 1, now: .now)
        state.ingestSteps(dayKey: "2026-10-23", dailyTotal: Tuning.introEggTargetSteps)
        _ = try state.hatch(now: .now)
        try state.startEgg(.tiny, seed: 2, now: .now)
        state.ingestSteps(dayKey: "2026-10-23", dailyTotal: 7_123)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SaveArchive(name: "privacy", directory: directory)
        let bytes = try JSONEncoder().encode(state)
        try archive.save(bytes)
        try archive.save(bytes)
        let reloaded = GameStore(container: container, role: .phone, archive: archive)
        XCTAssertEqual(reloaded.state, state.collectionMirror())
        XCTAssertNotEqual(phone.state.saveID, reloaded.state.saveID)
        for name in ["current.json", "previous.json"] {
            let value = try JSONDecoder().decode(GameState.self, from: Data(contentsOf: directory.appendingPathComponent(name)))
            XCTAssertNil(value.egg)
            XCTAssertNil(value.history.first?.eggSteps)
            XCTAssertNil(value.history.first?.eggStartedAt)
            XCTAssertEqual(value.lifetimeCreditedSteps, 0)
            XCTAssertEqual(value.ledger, StepLedger())
        }
    }
}
