import SwiftUI

struct ToolRow: View {
    let tool: Tool
    @Environment(ToolStore.self) private var store

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                if let bytes = tool.fileSizeBytes {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.isDownloading(tool) {
                ProgressView()
            } else if store.isOutdated(tool) {
                Button {
                    Task { try? await store.download(tool) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            } else if store.isDownloaded(tool) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
