import SwiftUI

struct ToolListView: View {
    @Environment(ToolStore.self) private var store

    var body: some View {
        List(Tool.all) { tool in
            NavigationLink(value: tool) {
                ToolRow(tool: tool)
            }
        }
        .navigationTitle("Small Tools")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.isSyncingAll {
                    ProgressView()
                } else {
                    Button("Sync All", systemImage: "arrow.clockwise") {
                        Task { await store.syncAll() }
                    }
                }
            }
        }
    }
}
