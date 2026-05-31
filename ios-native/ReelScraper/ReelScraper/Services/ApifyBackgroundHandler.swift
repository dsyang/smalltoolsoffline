import Foundation
import ActivityKit

final class ApifyBackgroundHandler: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    private var receivedData: [Int: Data] = [:]
    var backgroundCompletionHandler: (() -> Void)?

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskID = dataTask.taskIdentifier
        AppLogger.shared.log("Received \(data.count) bytes for task \(taskID)", source: "bg")
        if receivedData[taskID] == nil {
            receivedData[taskID] = data
        } else {
            receivedData[taskID]?.append(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let reelIDString = task.taskDescription ?? "unknown"
        AppLogger.shared.log("Background task completed for reel \(reelIDString)", source: "bg")

        let store = ReelStore()

        guard let reelIDString = task.taskDescription,
              let reelID = UUID(uuidString: reelIDString),
              var reel = store.reel(for: reelID) else {
            AppLogger.shared.log("Could not find reel for task \(reelIDString)", source: "bg")
            finishBackground()
            return
        }

        if let error {
            AppLogger.shared.log("Background request failed: \(error.localizedDescription)", source: "bg")
            reel.status = .failed
            store.updateReel(reel)
            endLiveActivity(for: reel, success: false)
            finishBackground()
            return
        }

        let totalBytes = receivedData[task.taskIdentifier]?.count ?? 0
        AppLogger.shared.log("Total response: \(totalBytes) bytes", source: "bg")

        if let data = receivedData[task.taskIdentifier],
           let result = ApifyService.parseApifyResponse(data: data) {
            ApifyService.applyResult(result, to: &reel)
            store.updateReel(reel)
            AppLogger.shared.log("Scraped reel → @\(reel.ownerUsername ?? "?"), caption: \(reel.caption?.prefix(80) ?? "none")", source: "bg")
            endLiveActivity(for: reel, success: true)
        } else {
            AppLogger.shared.log("Failed to parse Apify response", source: "bg")
            if let data = receivedData[task.taskIdentifier],
               let body = String(data: data, encoding: .utf8) {
                AppLogger.shared.log("Response body: \(String(body.prefix(500)))", source: "bg")
            }
            reel.status = .failed
            store.updateReel(reel)
            endLiveActivity(for: reel, success: false)
        }

        receivedData.removeValue(forKey: task.taskIdentifier)
        finishBackground()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        AppLogger.shared.log("All background events finished", source: "bg")
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    private func finishBackground() {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    private func endLiveActivity(for reel: Reel, success: Bool) {
        guard #available(iOS 16.2, *) else { return }

        let activities = Activity<ScrapeActivityAttributes>.activities
        guard let activity = activities.first(where: {
            $0.attributes.reelID == reel.id
        }) else { return }

        let state = ScrapeActivityAttributes.ContentState(
            status: success ? .scraped : .failed,
            message: success
                ? "Scraped @\(reel.ownerUsername ?? "unknown")"
                : "Scrape failed"
        )

        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(.now + 5)
            )
        }
    }
}
