import SwiftUI

struct ReelListView: View {
    @Environment(ReelStore.self) private var store
    @State private var isRetrying = false
    @State private var showLogs = false

    var body: some View {
        Group {
            if store.reels.isEmpty {
                ContentUnavailableView(
                    "No Reels Yet",
                    systemImage: "film",
                    description: Text("Share a reel from Instagram to get started")
                )
            } else {
                List {
                    ForEach(store.reels) { reel in
                        NavigationLink(value: reel) {
                            ReelRow(reel: reel)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteReel(store.reels[index])
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await retryPendingReels()
                }
            }
        }
        .navigationTitle("Reels")
        .navigationDestination(for: Reel.self) { reel in
            ReelDetailView(reel: reel)
        }
        .navigationDestination(isPresented: $showLogs) {
            LogsView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        showLogs = true
                    }
                )
            }

            if store.reels.contains(where: { $0.status == .scraped }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await batchExport() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            store.load()
            await retryPendingReels()
        }
    }

    private func retryPendingReels() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }

        let pending = store.pendingReels
        AppLogger.shared.log("Retrying \(pending.count) pending reel(s)", source: "app")

        for reel in pending {
            var updated = reel
            updated.status = .scraping
            store.updateReel(updated)
            AppLogger.shared.log("Scraping \(reel.url)", source: "app")

            do {
                let result = try await ApifyService.scrape(reelURL: reel.url)
                ApifyService.applyResult(result, to: &updated)
                store.updateReel(updated)
                AppLogger.shared.log("Scraped \(reel.url) → @\(updated.ownerUsername ?? "?")", source: "app")
            } catch {
                updated.status = .failed
                store.updateReel(updated)
                AppLogger.shared.log("Failed \(reel.url): \(error.localizedDescription)", source: "app")
            }
        }
    }

    private func batchExport() async {
        for reel in store.reels where reel.status == .scraped {
            var updated = reel
            do {
                let pageID = try await NotionService.exportReel(reel)
                updated.notionPageID = pageID
                updated.exportedAt = Date()
                updated.status = .exported
                store.updateReel(updated)
            } catch {
                // Skip failures in batch
            }
        }
    }
}
