import Foundation

final class ApifyService {
    static let backgroundSessionIdentifier = "fyi.imdaniel.reelscraper.background"

    private static let actorEndpoint =
        "https://api.apify.com/v2/acts/apify~instagram-reel-scraper/run-sync-get-dataset-items"

    static func makeBackgroundSession(delegate: URLSessionDelegate) -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.sharedContainerIdentifier = "group.fyi.imdaniel.reelscraper"
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    static func startBackgroundScrape(reelURL: String, reelID: UUID, session: URLSession) {
        guard let token = Settings.apifyToken, !token.isEmpty else { return }

        let payload: [String: Any] = [
            "username": [reelURL],
            "resultsLimit": 1,
            "includeDownloadedVideo": false,
            "includeSharesCount": false,
            "includeTranscript": false,
            "skipPinnedPosts": false
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        // Background upload tasks require a file
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.fyi.imdaniel.reelscraper"
        )!
        let tempDir = container.appendingPathComponent("tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let uploadFile = tempDir.appendingPathComponent("\(reelID.uuidString).json")
        try? bodyData.write(to: uploadFile)

        var request = URLRequest(url: URL(string: "\(actorEndpoint)?token=\(token)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let task = session.uploadTask(with: request, fromFile: uploadFile)
        task.taskDescription = reelID.uuidString
        task.resume()
    }

    /// Fallback async scrape for retrying pending reels from the main app
    static func scrape(reelURL: String) async throws -> [String: Any] {
        guard let token = Settings.apifyToken, !token.isEmpty else {
            throw ApifyError.missingToken
        }

        let payload: [String: Any] = [
            "username": [reelURL],
            "resultsLimit": 1,
            "includeDownloadedVideo": false,
            "includeSharesCount": false,
            "includeTranscript": false,
            "skipPinnedPosts": false
        ]

        var request = URLRequest(url: URL(string: "\(actorEndpoint)?token=\(token)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ApifyError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else {
            throw ApifyError.noResults
        }

        return first
    }

    static func parseApifyResponse(data: Data) -> [String: Any]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first else { return nil }
        return first
    }

    static func applyResult(_ result: [String: Any], to reel: inout Reel) {
        reel.ownerUsername = result["ownerUsername"] as? String
            ?? result["author"] as? String
            ?? result["username"] as? String
        reel.caption = result["caption"] as? String
            ?? result["text"] as? String
            ?? result["description"] as? String
        reel.hashtags = result["hashtags"] as? [String]
        reel.likesCount = result["likesCount"] as? Int
        reel.viewsCount = result["viewsCount"] as? Int
        reel.commentsCount = result["commentsCount"] as? Int
        reel.thumbnailURL = result["displayUrl"] as? String
            ?? result["thumbnailUrl"] as? String
        reel.status = .scraped
    }

    enum ApifyError: LocalizedError {
        case missingToken, requestFailed, noResults

        var errorDescription: String? {
            switch self {
            case .missingToken: "Apify API token not set"
            case .requestFailed: "Apify request failed"
            case .noResults: "No results returned"
            }
        }
    }
}
