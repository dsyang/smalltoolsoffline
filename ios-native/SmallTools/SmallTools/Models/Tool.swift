import Foundation

struct Tool: Identifiable, Hashable, Codable {
    let title: String
    let description: String
    let path: String
    let sha256: String
    let fileSizeBytes: Int?

    enum CodingKeys: String, CodingKey {
        case title, description, path, sha256
        case fileSizeBytes = "file_size_bytes"
    }

    var id: String { URL(string: path)!.deletingPathExtension().lastPathComponent }
    var name: String { title }
    var filename: String { URL(string: path)!.lastPathComponent }

    var downloadURL: URL {
        URL(string: "https://code.imdaniel.fyi/\(path)")!
    }

    static func find(_ slug: String, in tools: [Tool]) -> Tool? {
        tools.first { $0.id == slug }
    }
}

struct Manifest: Codable {
    let tools: [Tool]
}
