import SwiftUI

struct ToolViewerView: View {
    let tool: Tool
    @Environment(ToolStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if store.hasLocalFile(tool) {
                WebView(fileURL: store.localURL(for: tool))
                    .ignoresSafeArea()
            } else if let error {
                ContentUnavailableView("Download Failed", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Downloading \(tool.name)…")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 6)
            .padding(.leading, 12)
        }
        .navigationBarHidden(true)
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
