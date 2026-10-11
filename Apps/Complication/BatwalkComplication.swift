import SwiftUI
import WidgetKit
import RelevanceKit
#if canImport(UIKit)
import UIKit
#endif

/// Persistent Watch-face presence (PRD §4.1): the companion's portrait and the
/// egg's progress ring. Reads only the App Group snapshot the Watch app writes;
/// the app reloads timelines whenever the snapshot visibly changes.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: ComplicationSnapshot(
            companionName: "Mochi", companionSpeciesID: "mochi", eggType: "tiny",
            eggProgress: 0.6, eggStepsRemaining: 800, eggVisualState: "cracked",
            isEggReady: false, updatedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = ComplicationSnapshot.load()
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)
        let expiry = snapshot.updatedAt.addingTimeInterval(2 * 60 * 60)
        let entries = expiry > .now ? [entry, SnapshotEntry(date: expiry, snapshot: snapshot)] : [entry]
        completion(Timeline(entries: entries, policy: .never))
    }

    /// Smart Stack (watchOS 11+): bring the card up while the egg is ready to
    /// hatch, and around dusk when the bat wakes. Time clues only — never location
    /// or fitness data (PRD §4.5).
    @available(watchOS 11.0, *)
    func relevance() async -> WidgetRelevance<Void> {
        let snapshot = ComplicationSnapshot.load()
        let now = Date()
        var attributes: [WidgetRelevanceAttribute<Void>] = []
        if snapshot.isEggReady {
            attributes.append(WidgetRelevanceAttribute(
                context: .date(interval: DateInterval(start: now, duration: 3 * 60 * 60), kind: .default)))
        }
        if snapshot.companionName != nil,
           let dusk = Calendar.current.nextDate(after: now, matching: DateComponents(hour: snapshot.duskHour, minute: 0),
                                                matchingPolicy: .nextTime) {
            attributes.append(WidgetRelevanceAttribute(
                context: .date(interval: DateInterval(start: dusk.addingTimeInterval(-15 * 60), duration: 90 * 60), kind: .scheduled)))
        }
        return WidgetRelevance(attributes)
    }
}

struct BatwalkComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: ComplicationSnapshot { entry.snapshot }
    private var stale: Bool { snapshot.isStale(at: entry.date) }
    private var hasData: Bool { SharedConfig.appGroupEnabled && snapshot.updatedAt != .distantPast }
    /// The last known progress stays on the face even when the data is a few hours
    /// old: an empty ring after a quiet afternoon read as a bug, not as caution.
    private var progress: Double { snapshot.isEggReady ? 1 : (snapshot.eggProgress ?? 0) }

    private var caption: String {
        if !hasData { return "Open Batwalk" }
        if snapshot.isEggReady { return "Ready to hatch!" }
        if let remaining = snapshot.eggStepsRemaining {
            return stale ? "\(remaining.formatted()) to go · open to update" : "\(remaining.formatted()) to hatch"
        }
        return snapshot.companionName == nil ? "Batwalk" : "Pick your next egg"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryCorner: corner
            case .accessoryInline: Text("🦇 \(caption)")
            default: rectangular
            }
        }
        .widgetURL(snapshot.destination)
        .privacySensitive()
    }

    private var circular: some View {
        Gauge(value: progress) {
            portrait(size: 24)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel(caption)
    }

    private var corner: some View {
        ZStack {
            portrait(size: 22)
            if snapshot.isEggReady {
                Image(systemName: "sparkles").font(.system(size: 9, weight: .bold)).offset(x: 10, y: -10)
            }
        }
        .widgetLabel {
            Gauge(value: progress) { EmptyView() }
        }
        .accessibilityLabel(caption)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            ZStack {
                portrait(size: 42)
                if snapshot.isEggReady {
                    Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).offset(x: 16, y: -16)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.companionName ?? "Batwalk").font(.headline).lineLimit(1)
                Text(caption).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                if hasData, snapshot.eggProgress != nil {
                    HStack(spacing: 4) {
                        eggIcon(size: 12)
                        Gauge(value: progress) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The companion's own portrait when the extension bundles it; the moon otherwise.
    @ViewBuilder
    private func portrait(size: CGFloat) -> some View {
        if let id = snapshot.companionSpeciesID, Self.hasImage("portrait_bat_\(id)") {
            Image("portrait_bat_\(id)")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .hueRotation(.degrees(snapshot.companionIsShiny ? 150 : 0))
                .frame(width: size, height: size)
        } else {
            Image(systemName: snapshot.isEggReady ? "sparkles" : "moon.stars.fill")
                .font(.system(size: size * 0.7, weight: .semibold))
        }
    }

    /// The egg shows its cracks on the face from 50 % on (PRD §3.5) — a reason to
    /// glance at the wrist mid-walk.
    @ViewBuilder
    private func eggIcon(size: CGFloat) -> some View {
        if let type = snapshot.eggType {
            let state = snapshot.eggVisualState ?? "calm"
            let pose = state == "ready" ? "ready" : (state == "cracked" || state == "rattling") ? "cracked" : "calm"
            let name = "gentle_egg_\(type)_\(pose)"
            if Self.hasImage(name) {
                Image(name).interpolation(.none).resizable().scaledToFit().frame(width: size, height: size)
            }
        }
    }

    private static func hasImage(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }
}

@main
struct BatwalkComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BatwalkComplication", provider: SnapshotProvider()) { entry in
            BatwalkComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Batwalk")
        .description("Your bat and how close your egg is to hatching.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
