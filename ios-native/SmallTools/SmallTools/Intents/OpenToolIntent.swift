import AppIntents
import UIKit

struct ToolEntity: AppEntity {
    static var defaultQuery = ToolQuery()
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tool")

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(tool: Tool) {
        self.id = tool.id
        self.name = tool.name
    }
}

struct ToolQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ToolEntity] {
        Tool.all.filter { identifiers.contains($0.id) }.map { ToolEntity(tool: $0) }
    }

    func suggestedEntities() async throws -> [ToolEntity] {
        Tool.all.map { ToolEntity(tool: $0) }
    }
}

struct OpenToolIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tool"
    static var description = IntentDescription("Opens a tool in Small Tools")
    static var openAppWhenRun = true

    @Parameter(title: "Tool")
    var tool: ToolEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "smalltools://open/\(tool.id)") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct SmallToolsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenToolIntent(),
            phrases: [
                "Open \(\.$tool) in \(.applicationName)",
                "Launch \(\.$tool) in \(.applicationName)",
            ],
            shortTitle: "Open Tool",
            systemImageName: "wrench.and.screwdriver"
        )
    }
}
