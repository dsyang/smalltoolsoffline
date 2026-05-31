import SwiftUI

struct ReelDetailView: View {
    @Environment(ReelStore.self) private var store
    let reel: Reel
    @State private var isExporting = false
    @State private var isScraping = false
    @State private var errorMessage: String?

    private var currentReel: Reel {
        store.reel(for: reel.id) ?? reel
    }

    var body: some View {
        List {
            Section("Status") {
                LabeledContent("Status", value: currentReel.status.rawValue.capitalized)
                LabeledContent("Saved") {
                    Text(currentReel.savedAt, style: .date)
                }
            }

            if let username = currentReel.ownerUsername {
                Section("Author") {
                    Text("@\(username)")
                        .font(.headline)
                }
            }

            if let caption = currentReel.caption {
                Section("Caption") {
                    Text(caption)
                        .textSelection(.enabled)
                }
            }

            if let hashtags = currentReel.hashtags, !hashtags.isEmpty {
                Section("Hashtags") {
                    FlowLayout(spacing: 6) {
                        ForEach(hashtags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if currentReel.likesCount != nil || currentReel.viewsCount != nil || currentReel.commentsCount != nil {
                Section("Metrics") {
                    if let views = currentReel.viewsCount {
                        LabeledContent("Views", value: views.formatted())
                    }
                    if let likes = currentReel.likesCount {
                        LabeledContent("Likes", value: likes.formatted())
                    }
                    if let comments = currentReel.commentsCount {
                        LabeledContent("Comments", value: comments.formatted())
                    }
                }
            }

            if let notionPageID = currentReel.notionPageID {
                Section("Notion") {
                    LabeledContent("Page ID", value: notionPageID)
                    if let exportedAt = currentReel.exportedAt {
                        LabeledContent("Exported") {
                            Text(exportedAt, style: .date)
                        }
                    }
                }
            }

            Section {
                Link(destination: URL(string: currentReel.url)!) {
                    Label("Open in Instagram", systemImage: "arrow.up.right")
                }

                if currentReel.status == .scraped {
                    Button {
                        Task { await exportToNotion() }
                    } label: {
                        if isExporting {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Exporting...")
                            }
                        } else {
                            Label("Export to Notion", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                }

                if currentReel.status == .failed || currentReel.status == .pending {
                    Button {
                        Task { await reScrape() }
                    } label: {
                        if isScraping {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Scraping...")
                            }
                        } else {
                            Label("Re-scrape", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isScraping)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(currentReel.ownerUsername.map { "@\($0)" } ?? "Reel")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportToNotion() async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let pageID = try await NotionService.exportReel(currentReel)
            var updated = currentReel
            updated.notionPageID = pageID
            updated.exportedAt = Date()
            updated.status = .exported
            store.updateReel(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reScrape() async {
        isScraping = true
        errorMessage = nil
        defer { isScraping = false }

        var updated = currentReel
        updated.status = .scraping
        store.updateReel(updated)

        do {
            let result = try await ApifyService.scrape(reelURL: currentReel.url)
            ApifyService.applyResult(result, to: &updated)
            store.updateReel(updated)
        } catch {
            updated.status = .failed
            store.updateReel(updated)
            errorMessage = error.localizedDescription
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
