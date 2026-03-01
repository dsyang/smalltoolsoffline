import UIKit

enum QuickActions {
    static func update(with store: ToolStore) {
        let downloaded = Tool.all.filter { store.isDownloaded($0) }
        let items = downloaded.prefix(4).map { tool in
            UIApplicationShortcutItem(
                type: "open-tool",
                localizedTitle: tool.name,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "wrench.and.screwdriver"),
                userInfo: ["slug": tool.id as NSSecureCoding]
            )
        }
        UIApplication.shared.shortcutItems = items
    }

    static func tool(for shortcutItem: UIApplicationShortcutItem) -> Tool? {
        guard shortcutItem.type == "open-tool",
              let slug = shortcutItem.userInfo?["slug"] as? String else { return nil }
        return Tool.find(slug)
    }
}
