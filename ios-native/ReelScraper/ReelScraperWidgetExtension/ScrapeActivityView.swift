import SwiftUI
import WidgetKit
import ActivityKit

struct ScrapeActivityView: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScrapeActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: activityIcon(for: context.state.status))
                    .font(.title2)
                    .foregroundStyle(activityColor(for: context.state.status))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reel Scraper")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }

                Spacer()

                if context.state.status == .pending || context.state.status == .scraping {
                    ProgressView()
                        .tint(.purple)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: activityIcon(for: context.state.status))
                        .foregroundStyle(activityColor(for: context.state.status))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.message)
                        .font(.caption)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == .pending || context.state.status == .scraping {
                        ProgressView()
                            .tint(.purple)
                    }
                }
            } compactLeading: {
                Image(systemName: "film")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                if context.state.status == .scraped {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if context.state.status == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                        .tint(.purple)
                }
            } minimal: {
                Image(systemName: "film")
                    .foregroundStyle(.purple)
            }
        }
    }

    private func activityIcon(for status: ReelStatus) -> String {
        switch status {
        case .pending, .scraping: "film"
        case .scraped: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .exported: "square.and.arrow.up.fill"
        }
    }

    private func activityColor(for status: ReelStatus) -> Color {
        switch status {
        case .pending, .scraping: .purple
        case .scraped, .exported: .green
        case .failed: .red
        }
    }
}
