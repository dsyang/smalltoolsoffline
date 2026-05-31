import ActivityKit
import Foundation

struct ScrapeActivityAttributes: ActivityAttributes {
    let reelID: UUID
    let reelURL: String

    struct ContentState: Codable, Hashable {
        var status: ReelStatus
        var message: String
    }
}
