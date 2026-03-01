import SwiftUI

struct ToolViewerView: View {
    let tool: Tool
    @Environment(ToolStore.self) private var store
    @State private var error: String?

    var body: some View {
        Group {
            if store.hasLocalFile(tool) {
                WebView(fileURL: store.localURL(for: tool))
            } else if let error {
                ContentUnavailableView("Download Failed", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Downloading \(tool.name)…")
            }
        }
        .navigationTitle(tool.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !store.hasLocalFile(tool) else { return }
            do {
                try await store.download(tool)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
