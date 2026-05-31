import Foundation

@Observable
final class ReelStore {
    private(set) var reels: [Reel] = []

    private static let fileName = "reels.json"
    static let didChangeNotification = "fyi.imdaniel.reelscraper.reelsChanged" as CFString

    private var fileURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.fyi.imdaniel.reelscraper"
        )!
        return container.appendingPathComponent(Self.fileName)
    }

    init() {
        load()
    }

    /// Call from the main app to start listening for cross-process changes
    func startListening() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let store = Unmanaged<ReelStore>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    store.load()
                }
            },
            Self.didChangeNotification,
            nil,
            .deliverImmediately
        )
    }

    func stopListening() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(center, observer, nil, nil)
    }

    /// Post a Darwin notification so other processes know reels.json changed
    static func notifyChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(didChangeNotification),
            nil,
            nil,
            true
        )
    }

    func load() {
        let url = fileURL
        var coordinator: NSFileCoordinator? = NSFileCoordinator()
        var error: NSError?
        var loadedReels: [Reel] = []

        coordinator?.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            guard let data = try? Data(contentsOf: readURL),
                  let decoded = try? JSONDecoder.reelDecoder.decode([Reel].self, from: data) else { return }
            loadedReels = decoded
        }
        coordinator = nil

        reels = loadedReels.sorted { $0.savedAt > $1.savedAt }
    }

    func save() {
        let url = fileURL
        guard let data = try? JSONEncoder.reelEncoder.encode(reels) else { return }

        var coordinator: NSFileCoordinator? = NSFileCoordinator()
        var error: NSError?

        coordinator?.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            try? data.write(to: writeURL, options: .atomic)
        }
        coordinator = nil

        Self.notifyChange()
    }

    func addReel(url: String) -> Reel {
        load() // pick up any changes from other processes first
        let reel = Reel(
            id: UUID(),
            url: url,
            status: .pending,
            savedAt: Date()
        )
        reels.insert(reel, at: 0)
        save()
        return reel
    }

    func updateReel(_ reel: Reel) {
        if let index = reels.firstIndex(where: { $0.id == reel.id }) {
            reels[index] = reel
        } else {
            // Reel was added by another process, reload then update
            load()
            guard let index = reels.firstIndex(where: { $0.id == reel.id }) else { return }
            reels[index] = reel
        }
        save()
    }

    func deleteReel(_ reel: Reel) {
        reels.removeAll { $0.id == reel.id }
        save()
    }

    func reel(for id: UUID) -> Reel? {
        load() // always read latest from disk
        return reels.first { $0.id == id }
    }

    var pendingReels: [Reel] {
        reels.filter { $0.status == .pending }
    }

    /// Find an existing reel matching this URL (ignoring query params)
    func existingReel(for url: String) -> Reel? {
        let normalized = Self.normalizeURL(url)
        return reels.first { Self.normalizeURL($0.url) == normalized }
    }

    static func normalizeURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        // Strip trailing slash
        var result = components?.string ?? urlString
        while result.hasSuffix("/") { result.removeLast() }
        return result.lowercased()
    }
}

extension JSONDecoder {
    static let reelDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let reelEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()
}
