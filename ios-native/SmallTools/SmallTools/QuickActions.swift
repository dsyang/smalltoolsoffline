import UIKit

enum QuickActions {
    static func update(with store: ToolStore) {
        let downloaded = store.tools.filter { store.isDownloaded($0) }
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

    static func slug(for shortcutItem: UIApplicationShortcutItem) -> String? {
        guard shortcutItem.type == "open-tool" else { return nil }
        return shortcutItem.userInfo?["slug"] as? String
    }
}
