import Foundation

enum ReelStatus: String, Codable {
    case pending, scraping, scraped, failed, exported
}

struct Reel: Identifiable, Codable, Hashable {
    var id: UUID
    var url: String
    var status: ReelStatus
    var savedAt: Date
    var ownerUsername: String?
    var caption: String?
    var hashtags: [String]?
    var likesCount: Int?
    var viewsCount: Int?
    var commentsCount: Int?
    var thumbnailURL: String?
    var notionPageID: String?
    var exportedAt: Date?
}
