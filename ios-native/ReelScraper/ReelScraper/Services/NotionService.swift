import Foundation

enum NotionService {
    static func exportReel(_ reel: Reel) async throws -> String {
        guard let token = Settings.notionToken, !token.isEmpty else {
            throw NotionError.missingToken
        }
        guard let databaseID = Settings.notionDatabaseID, !databaseID.isEmpty else {
            throw NotionError.missingDatabaseID
        }

        let title = reel.ownerUsername.map { "@\($0)" } ?? "Instagram Reel"

        var properties: [String: Any] = [
            "Name": [
                "title": [["text": ["content": title]]]
            ],
            "URL": [
                "url": reel.url
            ],
            "Platform": [
                "select": ["name": "Instagram"]
            ],
            "Saved At": [
                "date": ["start": ISO8601DateFormatter().string(from: reel.savedAt)]
            ]
        ]

        if let caption = reel.caption {
            properties["Caption"] = [
                "rich_text": [["text": ["content": String(caption.prefix(2000))]]]
            ]
        }

        if let author = reel.ownerUsername {
            properties["Author"] = [
                "rich_text": [["text": ["content": author]]]
            ]
        }

        if let hashtags = reel.hashtags, !hashtags.isEmpty {
            properties["Hashtags"] = [
                "multi_select": hashtags.map { ["name": $0] }
            ]
        }

        let body: [String: Any] = [
            "parent": ["database_id": databaseID],
            "properties": properties
        ]

        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/pages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NotionError.requestFailed(errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pageID = json["id"] as? String else {
            throw NotionError.invalidResponse
        }

        return pageID
    }

    enum NotionError: LocalizedError {
        case missingToken, missingDatabaseID, requestFailed(String), invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingToken: "Notion token not set"
            case .missingDatabaseID: "Notion database ID not set"
            case .requestFailed(let msg): "Notion error: \(msg)"
            case .invalidResponse: "Invalid response from Notion"
            }
        }
    }
}
