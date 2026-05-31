import Foundation

/// An additional file a tool depends on (e.g. an image referenced by its HTML).
/// Stored on the CDN alongside the tool and downloaded with it for offline use.
struct Asset: Codable, Hashable {
    let path: String
    let sha256: String
    let fileSizeBytes: Int?

    enum CodingKeys: String, CodingKey {
        case path, sha256
        case fileSizeBytes = "file_size_bytes"
    }

    var downloadURL: URL {
        URL(string: "https://code.imdaniel.fyi/\(path)")!
    }
}

struct Tool: Identifiable, Hashable, Codable {
    let title: String
    let description: String
    let path: String
    let sha256: String
    let fileSizeBytes: Int?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case title, description, path, sha256, assets
        case fileSizeBytes = "file_size_bytes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        path = try container.decode(String.self, forKey: .path)
        sha256 = try container.decode(String.self, forKey: .sha256)
        fileSizeBytes = try container.decodeIfPresent(Int.self, forKey: .fileSizeBytes)
        // Older cached manifests may not include the assets array.
        assets = try container.decodeIfPresent([Asset].self, forKey: .assets) ?? []
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
