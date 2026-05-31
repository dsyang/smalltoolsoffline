import SwiftUI

@main
struct ReelScraperApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ReelScraperAppDelegate
    @State private var store = ReelStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ReelListView()
            }
            .environment(store)
            .onAppear {
                appDelegate.store = store
                store.startListening()
            }
        }
    }
}

@Observable
final class ReelScraperAppDelegate: NSObject, UIApplicationDelegate {
    let backgroundHandler = ApifyBackgroundHandler()
    var store: ReelStore?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == ApifyService.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        backgroundHandler.backgroundCompletionHandler = completionHandler
        _ = ApifyService.makeBackgroundSession(delegate: backgroundHandler)
    }
}
