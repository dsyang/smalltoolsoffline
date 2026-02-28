// OpenToolIntent.swift
// Add this file to your Xcode iOS project (ios/App/App/)
//
// Provides Siri Shortcuts integration:
//   "Open 2048 in Small Tools"
//   "Open Currency Converter in Small Tools"

import AppIntents
import UIKit

// MARK: - Tool Entity

/// Represents a single tool that can be opened via Siri
struct ToolEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tool")
    static var defaultQuery = ToolQuery()

    var id: String          // slug
    var name: String        // display name

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    // All available tools — keep in sync with TOOLS in index.html
    static let all: [ToolEntity] = [
        ToolEntity(id: "2048", name: "2048"),
        ToolEntity(id: "candles", name: "Birthday Candles"),
        ToolEntity(id: "calendar", name: "Calendar 2026"),
        ToolEntity(id: "kinship", name: "Chinese Kinship Calculator"),
        ToolEntity(id: "currency", name: "Currency Converter"),
        ToolEntity(id: "time", name: "Exact Time"),
        ToolEntity(id: "collage", name: "How you see me collage"),
        ToolEntity(id: "pick1", name: "Pick 1"),
        ToolEntity(id: "wordcount", name: "Word Counter"),
    ]
}

// MARK: - Tool Query

struct ToolQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ToolEntity] {
        ToolEntity.all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ToolEntity] {
        ToolEntity.all
    }
}

// MARK: - Open Tool Intent

struct OpenToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tool"
    static var description = IntentDescription("Opens a tool in Small Tools for offline viewing.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Tool")
    var tool: ToolEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        // Open the app via URL scheme — the JS deep link handler picks this up
        let urlString = "smalltools://open/\(tool.id)"
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider (makes intents available with zero setup)

struct SmallToolsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenToolIntent(),
            phrases: [
                "Open \(\.$tool) in \(.applicationName)",
                "Launch \(\.$tool) in \(.applicationName)",
                "Show \(\.$tool) in \(.applicationName)",
            ],
            shortTitle: "Open Tool",
            systemImageName: "wrench.and.screwdriver"
        )
    }
}
