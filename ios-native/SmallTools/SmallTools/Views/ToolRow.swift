import SwiftUI

struct ToolRow: View {
    let tool: Tool
    @Environment(ToolStore.self) private var store

    var body: some View {
        HStack {
            Text(tool.name)
            Spacer()
            if store.isDownloading(tool) {
                ProgressView()
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
