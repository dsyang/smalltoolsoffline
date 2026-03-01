import SwiftUI

struct ToolListView: View {
    @Environment(ToolStore.self) private var store

    var body: some View {
        List(store.tools) { tool in
            NavigationLink(value: tool) {
                ToolRow(tool: tool)
            }
            .swipeActions(edge: .trailing) {
                if store.hasLocalFile(tool) {
                    Button {
                        store.deleteLocal(tool)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .overlay {
            if store.tools.isEmpty && store.isFetchingManifest {
                ProgressView("Loading tools…")
            } else if store.tools.isEmpty {
                ContentUnavailableView("No Tools", systemImage: "wrench.and.screwdriver", description: Text("Pull to refresh or tap Sync All"))
            }
        }
        .task { await store.fetchManifest() }
        .navigationTitle("Small Tools")
    }
}
