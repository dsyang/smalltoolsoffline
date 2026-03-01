import Foundation

struct Tool: Identifiable, Hashable {
    let id: String // slug
    let name: String
    let filename: String

    var remoteURL: URL {
        URL(string: "https://code.imdaniel.fyi/tools/\(filename)")!
    }

    static let all: [Tool] = [
        Tool(id: "2048", name: "2048", filename: "2048.html"),
        Tool(id: "kinship", name: "Chinese Kinship Calculator", filename: "kinship-calculator.html"),
        Tool(id: "currency", name: "Currency Converter", filename: "currency.html"),
        Tool(id: "time", name: "Exact Time", filename: "time-display.html"),
        Tool(id: "pick1", name: "Pick 1", filename: "pick1.html"),
        Tool(id: "candles", name: "Birthday Candles", filename: "candles.html"),
        Tool(id: "calendar", name: "Calendar 2026", filename: "calendar-2026.html"),
        Tool(id: "collage", name: "How You See Me", filename: "collage.html"),
        Tool(id: "wordcount", name: "Word Counter", filename: "wordcount.html"),
    ]

    static func find(_ slug: String) -> Tool? {
        all.first { $0.id == slug }
    }
}
