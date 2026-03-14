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
        let knownFilenames = Set(currentManifestTools.map(\.filename))
        let files = (try? FileManager.default.contentsOfDirectory(at: toolsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !knownFilenames.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func scanDownloaded() {
        downloadedToolIDs = []
        outdatedToolIDs = []
        for tool in tools {
            let path = localURL(for: tool)
            guard let data = try? Data(contentsOf: path) else { continue }
            downloadedToolIDs.insert(tool.id)
            let hash = SHA256.hash(data: data)
            let hex = hash.map { String(format: "%02x", $0) }.joined()
            if hex != tool.sha256 {
                outdatedToolIDs.insert(tool.id)
            }
        }
    }

    func localURL(for tool: Tool) -> URL {
        toolsDirectory.appendingPathComponent(tool.filename)
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
        try data.write(to: localURL(for: tool), options: .atomic)
        downloadedToolIDs.insert(tool.id)
        outdatedToolIDs.remove(tool.id)
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
