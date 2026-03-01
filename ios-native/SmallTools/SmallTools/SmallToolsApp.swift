import SwiftUI

@main
struct SmallToolsApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = ToolStore()
    @State private var navigationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                ToolListView()
                    .navigationDestination(for: Tool.self) { tool in
                        ToolViewerView(tool: tool)
                    }
            }
            .environment(store)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: appDelegate.pendingShortcutSlug) { _, slug in
                guard let slug, let tool = Tool.find(slug) else { return }
                appDelegate.pendingShortcutSlug = nil
                navigate(to: tool)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                QuickActions.update(with: store)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "smalltools",
              url.host() == "open",
              let slug = url.pathComponents.dropFirst().first,
              let tool = Tool.find(slug) else { return }
        navigate(to: tool)
    }

    private func navigate(to tool: Tool) {
        navigationPath = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationPath.append(tool)
        }
    }
}

@Observable
final class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingShortcutSlug: String?

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem,
           let tool = QuickActions.tool(for: shortcutItem) {
            pendingShortcutSlug = tool.id
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem
    ) async -> Bool {
        guard let tool = QuickActions.tool(for: shortcutItem) else { return false }
        // Find the AppDelegate via UIApplication and set the pending slug
        if let appDelegate = await UIApplication.shared.delegate as? AppDelegate {
            await MainActor.run { appDelegate.pendingShortcutSlug = tool.id }
        }
        return true
    }
}
