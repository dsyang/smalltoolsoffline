import Foundation

enum ReelStatus: String, Codable {
    case pending, scraping, scraped, failed, exported
}
