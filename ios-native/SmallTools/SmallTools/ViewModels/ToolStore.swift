import Foundation
import CryptoKit

@Observable
final class ToolStore {
    private(set) var tools: [Tool] = []
    private(set) var downloadedToolIDs: Set<String> = []
    private(set) var outdatedToolIDs: Set<String> = []
    private(set) var downloadingToolIDs: Set<String> = []
    private(set) var isFetchingManifest = false
    var isSyncingAll = false

    private var _allTools: [Tool] = []
    private let orderKey = "toolOrder"
    private let toolsDirectory: URL
    private let manifestURL = URL(string: "https://code.imdaniel.fyi/assets.json")!

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        toolsDirectory = docs.appendingPathComponent("tools", isDirectory: true)
        try? FileManager.default.createDirectory(at: toolsDirectory, withIntermediateDirectories: true)
        if let cached = loadCachedManifest() {
            _allTools = cached
            applyOrder()
            scanDownloaded()
        }
    }

    // MARK: - Ordering

    private var savedOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: orderKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: orderKey) }
    }

    private func applyOrder() {
        let order = savedOrder
        guard !order.isEmpty else {
            tools = _allTools
            return
        }
        let toolsByID = Dictionary(uniqueKeysWithValues: _allTools.map { ($0.id, $0) })
        var ordered: [Tool] = order.compactMap { toolsByID[$0] }
        let orderedIDs = Set(order)
        ordered += _allTools.filter { !orderedIDs.contains($0.id) }
        tools = ordered
    }

    func moveTools(from source: IndexSet, to destination: Int) {
        tools.move(fromOffsets: source, toOffset: destination)
        savedOrder = tools.map(\.id)
    }

    // MARK: - Manifest

    private var cachedManifestURL: URL {
        toolsDirectory.deletingLastPathComponent().appendingPathComponent("manifest.json")
    }

    private func loadCachedManifest() -> [Tool]? {
        guard let data = try? Data(contentsOf: cachedManifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        return manifest.tools
    }

    @MainActor
    func fetchManifest() async {
        isFetchingManifest = true
        defer { isFetchingManifest = false }

        do {
            let request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalCacheData)
            let (data, _) = try await URLSession.shared.data(for: request)
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            try data.write(to: cachedManifestURL, options: .atomic)
            _allTools = manifest.tools
            deleteRemovedTools(currentManifestTools: manifest.tools)
            applyOrder()
            scanDownloaded()
        } catch {
            // Keep using cached tools if fetch fails
        }
    }

    // MARK: - Filesystem

    private func deleteRemovedTools(currentManifestTools: [Tool]) {
        let fm = FileManager.default
        // Every file we expect to keep: each tool's HTML plus all of its assets.
        var knownPaths = Set<String>()
        for tool in currentManifestTools {
            knownPaths.insert(localURL(for: tool).standardizedFileURL.path)
            for asset in tool.assets {
                knownPaths.insert(localURL(forRelativePath: asset.path).standardizedFileURL.path)
            }
        }

        guard let enumerator = fm.enumerator(at: toolsDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        var directories: [URL] = []
        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                directories.append(url)
            } else if !knownPaths.contains(url.standardizedFileURL.path) {
                try? fm.removeItem(at: url)
            }
        }
        // Remove now-empty asset directories, deepest first.
        for dir in directories.sorted(by: { $0.path.count > $1.path.count }) {
            if let contents = try? fm.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }
    }

    private func scanDownloaded() {
        downloadedToolIDs = []
        outdatedToolIDs = []
        for tool in tools {
            guard let data = try? Data(contentsOf: localURL(for: tool)) else { continue }
            downloadedToolIDs.insert(tool.id)
            // A tool is up to date only when its HTML and every asset match.
            if sha256Hex(of: data) != tool.sha256 || !assetsUpToDate(tool) {
                outdatedToolIDs.insert(tool.id)
            }
        }
    }

    /// True when every asset for the tool exists locally and matches its hash.
    private func assetsUpToDate(_ tool: Tool) -> Bool {
        for asset in tool.assets {
            guard let data = try? Data(contentsOf: localURL(forRelativePath: asset.path)),
                  sha256Hex(of: data) == asset.sha256 else { return false }
        }
        return true
    }

    private func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func localURL(for tool: Tool) -> URL {
        localURL(forRelativePath: tool.path)
    }

    /// Maps a CDN path to its on-disk location, mirroring the CDN's `tools/`
    /// directory structure so relative asset references in the HTML resolve.
    func localURL(forRelativePath path: String) -> URL {
        let relative = path.hasPrefix("tools/") ? String(path.dropFirst("tools/".count)) : path
        return toolsDirectory.appendingPathComponent(relative)
    }

    func hasLocalFile(_ tool: Tool) -> Bool {
        downloadedToolIDs.contains(tool.id)
    }

    func isDownloaded(_ tool: Tool) -> Bool {
        downloadedToolIDs.contains(tool.id) && !outdatedToolIDs.contains(tool.id)
    }

    func isOutdated(_ tool: Tool) -> Bool {
        outdatedToolIDs.contains(tool.id)
    }

    func isDownloading(_ tool: Tool) -> Bool {
        downloadingToolIDs.contains(tool.id)
    }

    func needsDownload(_ tool: Tool) -> Bool {
        !downloadedToolIDs.contains(tool.id) || outdatedToolIDs.contains(tool.id)
    }

    func deleteLocal(_ tool: Tool) {
        try? FileManager.default.removeItem(at: localURL(for: tool))
        for asset in tool.assets {
            try? FileManager.default.removeItem(at: localURL(forRelativePath: asset.path))
        }
        downloadedToolIDs.remove(tool.id)
        outdatedToolIDs.remove(tool.id)
    }

    // MARK: - Downloads

    @MainActor
    func download(_ tool: Tool) async throws {
        guard !downloadingToolIDs.contains(tool.id) else { return }
        downloadingToolIDs.insert(tool.id)
        defer { downloadingToolIDs.remove(tool.id) }

        let (data, _) = try await URLSession.shared.data(from: tool.downloadURL)
        try write(data, to: localURL(for: tool))

        // Download all dependent assets (images, etc.) concurrently.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for asset in tool.assets {
                group.addTask { [self] in
                    let (assetData, _) = try await URLSession.shared.data(from: asset.downloadURL)
                    try write(assetData, to: localURL(forRelativePath: asset.path))
                }
            }
            try await group.waitForAll()
        }

        downloadedToolIDs.insert(tool.id)
        outdatedToolIDs.remove(tool.id)
    }

    /// Writes data atomically, creating any intermediate directories first.
    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    @MainActor
    func syncAll() async {
        isSyncingAll = true
        defer { isSyncingAll = false }

        await fetchManifest()

        await withTaskGroup(of: Void.self) { group in
            for tool in tools where needsDownload(tool) {
                group.addTask { [self] in
                    try? await self.download(tool)
                }
            }
        }
    }
}
