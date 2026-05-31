import UIKit
import UniformTypeIdentifiers
import ActivityKit

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleShare()
    }

    private func handleShare() {
        AppLogger.shared.log("Share extension activated", source: "share")

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            AppLogger.shared.log("No extension item or attachment found", source: "share")
            dismiss()
            return
        }

        let urlType = UTType.url.identifier

        guard itemProvider.hasItemConformingToTypeIdentifier(urlType) else {
            AppLogger.shared.log("Attachment is not a URL", source: "share")
            dismiss()
            return
        }

        itemProvider.loadItem(forTypeIdentifier: urlType) { [weak self] item, error in
            guard let self else { return }

            if let error {
                AppLogger.shared.log("loadItem error: \(error.localizedDescription)", source: "share")
            }

            var urlString: String?

            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                urlString = url.absoluteString
            } else if let text = item as? String {
                urlString = text
            }

            AppLogger.shared.log("Extracted URL: \(urlString ?? "nil")", source: "share")

            guard let urlString, urlString.contains("instagram.com") else {
                AppLogger.shared.log("Not an Instagram URL, dismissing", source: "share")
                DispatchQueue.main.async { self.dismiss() }
                return
            }

            DispatchQueue.main.async {
                self.processURL(urlString)
            }
        }
    }

    private func processURL(_ urlString: String) {
        let store = ReelStore()

        if var existing = store.existingReel(for: urlString) {
            AppLogger.shared.log("Duplicate reel found (\(existing.id)), updating savedAt", source: "share")
            existing.savedAt = Date()
            store.updateReel(existing)
            dismiss()
            return
        }

        let reel = store.addReel(url: urlString)
        AppLogger.shared.log("Saved pending reel \(reel.id) for \(urlString)", source: "share")

        startLiveActivity(for: reel)

        let handler = ApifyBackgroundHandler()
        let session = ApifyService.makeBackgroundSession(delegate: handler)
        ApifyService.startBackgroundScrape(reelURL: urlString, reelID: reel.id, session: session)
        AppLogger.shared.log("Started background scrape for reel \(reel.id)", source: "share")

        dismiss()
    }

    private func startLiveActivity(for reel: Reel) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.shared.log("Live Activities not enabled", source: "share")
            return
        }

        let attributes = ScrapeActivityAttributes(
            reelID: reel.id,
            reelURL: reel.url
        )
        let initialState = ScrapeActivityAttributes.ContentState(
            status: .pending,
            message: "Scraping reel..."
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(300))
            )
            AppLogger.shared.log("Live Activity started", source: "share")
        } catch {
            AppLogger.shared.log("Live Activity failed: \(error.localizedDescription)", source: "share")
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
