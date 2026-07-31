import Foundation
import os

// MARK: - DebugLogger
/// Thread-safe singleton that captures log messages for the in-app debug overlay.
/// Also mirrors output to Xcode console via `os_log`.
final class DebugLogger: ObservableObject {

    static let shared = DebugLogger()

    private let lock = NSLock()
    private let osLog = Logger(subsystem: "com.legiondeck.app", category: "Debug")
    private let maxLines = 200

    @Published private(set) var lines: [LogLine] = []

    private init() {}

    struct LogLine: Identifiable {
        let id = UUID()
        let timestamp: String
        let message: String

        var display: String { "[\(timestamp)] \(message)" }
    }

    func log(_ message: String) {
        let ts = DateFormatter.logFormatter.string(from: Date())
        let line = LogLine(timestamp: ts, message: message)

        lock.lock()
        var copy = lines
        copy.append(line)
        if copy.count > maxLines { copy.removeFirst(copy.count - maxLines) }
        lock.unlock()

        DispatchQueue.main.async {
            self.lines = copy
        }
        osLog.info("\(message, privacy: .public)")
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
