import Foundation

@Observable
final class ToolStore {
    private(set) var downloadedToolIDs: Set<String> = []
    private(set) var downloadingToolIDs: Set<String> = []
    var selectedTool: Tool?
    var isSyncingAll = false

    private let toolsDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        toolsDirectory = docs.appendingPathComponent("tools", isDirectory: true)
        try? FileManager.default.createDirectory(at: toolsDirectory, withIntermediateDirectories: true)
        scanDownloaded()
    }

    private func scanDownloaded() {
        downloadedToolIDs = []
        for tool in Tool.all {
            let path = localURL(for: tool)
            if FileManager.default.fileExists(atPath: path.path()) {
                downloadedToolIDs.insert(tool.id)
            }
        }
    }

    func localURL(for tool: Tool) -> URL {
        toolsDirectory.appendingPathComponent(tool.filename)
    }

    func isDownloaded(_ tool: Tool) -> Bool {
        downloadedToolIDs.contains(tool.id)
    }

    func isDownloading(_ tool: Tool) -> Bool {
        downloadingToolIDs.contains(tool.id)
    }

    @MainActor
    func download(_ tool: Tool) async throws {
        guard !downloadingToolIDs.contains(tool.id) else { return }
        downloadingToolIDs.insert(tool.id)
        defer { downloadingToolIDs.remove(tool.id) }

        let (data, _) = try await URLSession.shared.data(from: tool.remoteURL)
        try data.write(to: localURL(for: tool), options: .atomic)
        downloadedToolIDs.insert(tool.id)
    }

    @MainActor
    func syncAll() async {
        isSyncingAll = true
        defer { isSyncingAll = false }

        await withTaskGroup(of: Void.self) { group in
            for tool in Tool.all where !isDownloaded(tool) {
                group.addTask { [self] in
                    try? await self.download(tool)
                }
            }
        }
    }
}
