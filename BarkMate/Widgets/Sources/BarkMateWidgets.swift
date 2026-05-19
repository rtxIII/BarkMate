//
//  BarkMateWidgets.swift
//  BarkMateWidgets
//
//  Phase 1 骨架：Widget Bundle 占位。
//  具体 Widget（Timeline / Quick Memo）将在 V1.x 实现。
//

import WidgetKit
import SwiftUI

@main
struct BarkMateWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
        // V1.x: TimelineWidget()
        // V1.x: QuickMemoWidget()
        // iOS 18+: BarkMateControlWidget() (via @available)
    }
}

struct PlaceholderWidget: Widget {
    let kind: String = "BarkMatePlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            PlaceholderView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("BarkMate")
        .description("Placeholder widget. Real widgets will land in V1.x.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let timeline = Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never)
        completion(timeline)
    }
}

struct PlaceholderView: View {
    let entry: PlaceholderEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray.full")
                .font(.title2)
            Text("BarkMate")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
    }
}
