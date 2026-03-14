import SwiftUI

struct ToolListView: View {
    @Environment(ToolStore.self) private var store

    var body: some View {
        List {
            ForEach(store.tools) { tool in
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
            .onMove { store.moveTools(from: $0, to: $1) }
        }
        .overlay {
            if store.tools.isEmpty && store.isFetchingManifest {
                ProgressView("Loading tools…")
            } else if store.tools.isEmpty {
                ContentUnavailableView("No Tools", systemImage: "wrench.and.screwdriver", description: Text("Pull to refresh to load tools"))
            }
        }
        .refreshable { await store.fetchManifest() }
        .task { await store.fetchManifest() }
        .onAppear { WebViewPool.shared.warmUp() }
        .navigationTitle("Small Tools")
    }
}
