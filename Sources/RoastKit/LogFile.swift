import Foundation

struct LogFile {
    static let roast = LogFile(
        url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Roast/roast.log"),
        maxBytes: 1_000_000
    )

    let url: URL
    let maxBytes: Int

    func append(_ message: String, at date: Date = Date()) {
        let fileManager = FileManager.default
        let line = Data("\(ISO8601DateFormatter().string(from: date)) \(message)\n".utf8)

        if let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int, size >= maxBytes {
            let previous = url.appendingPathExtension("1")
            try? fileManager.removeItem(at: previous)
            try? fileManager.moveItem(at: url, to: previous)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? line.write(to: url)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }
}
