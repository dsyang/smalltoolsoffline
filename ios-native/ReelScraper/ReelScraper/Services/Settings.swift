import Foundation

enum Settings {
    private static let suite = UserDefaults(suiteName: "group.fyi.imdaniel.reelscraper")!

    static var apifyToken: String? {
        get { suite.string(forKey: "apifyToken") }
        set { suite.set(newValue, forKey: "apifyToken") }
    }

    static var notionToken: String? {
        get { suite.string(forKey: "notionToken") }
        set { suite.set(newValue, forKey: "notionToken") }
    }

    static var notionDatabaseID: String? {
        get { suite.string(forKey: "notionDatabaseID") }
        set { suite.set(newValue, forKey: "notionDatabaseID") }
    }
}
