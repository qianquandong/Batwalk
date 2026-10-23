import XCTest
import SwiftData
import SwiftUI
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    @MainActor
    private func birthdayWatch() throws -> GameStore {
        let (watch, _) = try makeStore()
        try watch.mutate {
            $0.start(seed: 1, now: .now)
            $0.ingestSteps(dayKey: "2026-10-23", dailyTotal: Tuning.introEggTargetSteps)
            _ = try $0.hatch(now: .now)
            try $0.startEgg(.tiny, seed: 1, now: .now)
        }
        return watch
    }

    @MainActor
    func testBirthdayRequestConfirmsOnlyAfterWatchReceiptAndMirror() async throws {
        let watch = try birthdayWatch()
        let (phone, _) = try makeStore(role: .phone)
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        let previous = phone.state
        let egg = watch.state.egg
        var requests: [PlayerSettingsRequest] = []
        let birthday = MonthDay(month: 2, day: 29)!
        phone.chooseBirthday(birthday, send: { requests.append($0); return .sent })
        phone.chooseBirthday(birthday, send: { requests.append($0); return .sent })
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(phone.state, previous)
        let request = try XCTUnwrap(requests.first)
        let receipt = watch.applySettingsRequest(request)
        XCTAssertEqual(receipt.outcome, .applied)
        XCTAssertEqual(watch.state.egg, egg)
        let revision = watch.state.revision
        XCTAssertEqual(watch.applySettingsRequest(request).outcome, .applied)
        XCTAssertEqual(watch.state.revision, revision)
        phone.receiveSettingsReceipt(receipt)
        XCTAssertTrue(phone.settingsHandoff.isWaiting)
        XCTAssertNil(phone.state.birthday)
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        XCTAssertFalse(phone.settingsHandoff.isWaiting)
        XCTAssertEqual(phone.state.birthday, birthday)
        XCTAssertNil(phone.state.egg)
        XCTAssertNil(phone.state.history.first?.eggSteps)
    }

    @MainActor
    func testBirthdayPendingRequestSurvivesRelaunchWithoutPhoneSaveMutation() async throws {
        let watch = try birthdayWatch()
        let (_, container) = try makeStore(role: .phone)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = SaveArchive(name: "birthday", directory: directory)
        let phone = GameStore(container: container, role: .phone, archive: archive)
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        var request: PlayerSettingsRequest?
        phone.chooseBirthday(MonthDay(month: 5, day: 2), send: { request = $0; return .sent })
        let reload = GameStore(container: container, role: .phone, archive: archive)
        XCTAssertEqual(reload.settingsHandoff.request, request)
        XCTAssertTrue(reload.settingsHandoff.isWaiting)
        XCTAssertNil(reload.state.birthday)
        let receipt = watch.applySettingsRequest(try XCTUnwrap(request))
        reload.applyMirror(try JSONEncoder().encode(watch.state))
        XCTAssertTrue(reload.settingsHandoff.isWaiting)
        reload.receiveSettingsReceipt(receipt)
        XCTAssertFalse(reload.settingsHandoff.isWaiting)
        XCTAssertEqual(reload.state.birthday, MonthDay(month: 5, day: 2))
    }

    @MainActor
    func testBirthdayUnavailableWatchDoesNotLeavePendingRequest() async throws {
        let watch = try birthdayWatch()
        let (phone, _) = try makeStore(role: .phone)
        phone.applyMirror(try JSONEncoder().encode(watch.state))
        let before = phone.state
        phone.chooseBirthday(MonthDay(month: 3, day: 4), send: { _ in .noWatchApp })
        XCTAssertFalse(phone.settingsHandoff.isWaiting)
        XCTAssertNotNil(phone.settingsRequestError)
        XCTAssertEqual(phone.state, before)
    }

    @MainActor
    func testBirthdayFailedWatchWritePreservesPreviousSettings() async throws {
        enum Failure: Error { case disk }
        var fail = false
        let (watch, _) = try makeStore(commit: { context in if fail { throw Failure.disk }; try context.save() })
        try watch.mutate { $0.start(seed: 1, now: .now) }
        let before = watch.state
        fail = true
        let request = PlayerSettingsRequest(saveID: before.saveID, baseRevision: before.revision,
                                            birthday: MonthDay(month: 10, day: 23))
        XCTAssertEqual(watch.applySettingsRequest(request).outcome, .saveFailed)
        XCTAssertEqual(watch.state, before)
    }

    @MainActor
    func testOldQueuedBirthdayCannotUndoNewerChoice() async throws {
        let watch = try birthdayWatch()
        let base = watch.state
        let old = PlayerSettingsRequest(saveID: base.saveID, baseRevision: base.revision,
            requestedAt: .now.addingTimeInterval(-2), birthday: MonthDay(month: 5, day: 2))
        let newer = PlayerSettingsRequest(saveID: base.saveID, baseRevision: base.revision,
            birthday: MonthDay(month: 6, day: 3))
        XCTAssertEqual(watch.applySettingsRequest(newer).outcome, .applied)
        let revision = watch.state.revision
        XCTAssertEqual(watch.applySettingsRequest(old).outcome, .superseded)
        XCTAssertEqual(watch.state.birthday, newer.birthday)
        XCTAssertEqual(watch.state.revision, revision)
    }

    @MainActor
    func testBirthdayCertificateRendersAndDoesNotChangeState() async throws {
        var state = GameState()
        let date = Date()
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        _ = state.applyPlayerSettings(PlayerSettingsRequest(saveID: state.saveID, baseRevision: 0,
            birthday: MonthDay(month: components.month!, day: components.day!)), now: date)
        state.start(seed: 1, now: date)
        state.ingestSteps(dayKey: DayKey.make(date), dailyTotal: Tuning.introEggTargetSteps)
        let record = try state.hatch(now: date).record
        let before = state
        XCTAssertNotNil(record.birthdayYear)
        let renderer = ImageRenderer(content: BirthCertificateCard(record: record.withoutActivityMetrics,
            nickname: nil, ordinal: 1, showSteps: false))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        XCTAssertEqual(image.width, 1_200)
        XCTAssertEqual(image.height, 1_200)
        XCTAssertEqual(state, before)
    }
}
