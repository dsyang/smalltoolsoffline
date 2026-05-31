import SwiftUI

struct LogsView: View {
    @State private var logText = ""

    var body: some View {
        Group {
            if logText.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text("Logs will appear here as the app and share extension run")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(logText)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .textSelection(.enabled)
                            .id("bottom")
                    }
                    .onAppear {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        AppLogger.shared.clear()
                        logText = ""
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }

                    Button {
                        logText = AppLogger.shared.readAll()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            logText = AppLogger.shared.readAll()
        }
    }
}
