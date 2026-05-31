import SwiftUI

struct ReelRow: View {
    let reel: Reel

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnailURL = reel.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let username = reel.ownerUsername {
                    Text("@\(username)")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(reel.url)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let caption = reel.caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(reel.savedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            statusIndicator
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch reel.status {
        case .pending, .scraping:
            ProgressView()
                .controlSize(.small)
        case .scraped:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .exported:
            Image(systemName: "square.and.arrow.up.fill")
                .foregroundStyle(.purple)
        }
    }
}
