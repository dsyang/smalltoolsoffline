import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private static let maxLines = 500

    private var fileURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.fyi.imdaniel.reelscraper"
        )!
        return container.appendingPathComponent("logs.txt")
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    func log(_ message: String, source: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(source)] \(message)\n"

        let url = fileURL
        var coordinator: NSFileCoordinator? = NSFileCoordinator()
        var error: NSError?

        coordinator?.coordinate(writingItemAt: url, options: .forMerging, error: &error) { writeURL in
            if FileManager.default.fileExists(atPath: writeURL.path) {
                if let handle = try? FileHandle(forWritingTo: writeURL) {
                    handle.seekToEndOfFile()
                    handle.write(Data(line.utf8))
                    handle.closeFile()
                }
            } else {
                try? Data(line.utf8).write(to: writeURL)
            }
        }
        coordinator = nil
    }

    func readAll() -> String {
        let url = fileURL
        var coordinator: NSFileCoordinator? = NSFileCoordinator()
        var error: NSError?
        var contents = ""

        coordinator?.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            contents = (try? String(contentsOf: readURL, encoding: .utf8)) ?? ""
        }
        coordinator = nil

        // Trim to last N lines
        let lines = contents.components(separatedBy: "\n")
        if lines.count > Self.maxLines {
            return lines.suffix(Self.maxLines).joined(separator: "\n")
        }
        return contents
    }

    func clear() {
        let url = fileURL
        var coordinator: NSFileCoordinator? = NSFileCoordinator()
        var error: NSError?

        coordinator?.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            try? "".write(to: writeURL, atomically: true, encoding: .utf8)
        }
        coordinator = nil
    }
}
