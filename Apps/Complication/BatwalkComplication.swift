import SwiftUI
import WidgetKit

/// Persistent Watch-face presence (PRD §4.1). Reads only the App Group snapshot
/// the Watch app writes; the app reloads timelines whenever the snapshot changes.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: ComplicationSnapshot(
            companionName: "Mochi", companionSpeciesID: "mochi",
            eggProgress: 0.6, eggStepsRemaining: 800, isEggReady: false, updatedAt: .now))
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
}

struct BatwalkComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var stale: Bool { entry.snapshot.isStale(at: entry.date) }
    private var progress: Double { stale ? 0 : entry.snapshot.isEggReady ? 1 : (entry.snapshot.eggProgress ?? 0) }

    private var shortLine: String {
        let s = entry.snapshot
        if !SharedConfig.appGroupEnabled { return "Open Batwalk" }
        if stale { return "Open to update" }
        if s.isEggReady { return "Ready to hatch!" }
        if let remaining = s.eggStepsRemaining { return "\(remaining.formatted()) to hatch" }
        return s.companionName ?? "Batwalk"
    }

    var body: some View {
        Group { switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "moon.stars.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryCorner:
            Image(systemName: !stale && entry.snapshot.isEggReady ? "sparkles" : "moon.stars.fill")
                .widgetLabel {
                    Gauge(value: progress) { EmptyView() }
                }
        case .accessoryInline:
            Text("🦇 \(shortLine)")
        default: // .accessoryRectangular
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.companionName ?? "Batwalk").font(.headline)
                Text(shortLine).font(.caption)
                if entry.snapshot.eggProgress != nil && !stale {
                    ProgressView(value: progress)
                }
            }
        }
        }
        .widgetURL(entry.snapshot.destination)
        .privacySensitive()
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
