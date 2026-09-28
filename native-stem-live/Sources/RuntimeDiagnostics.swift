import Foundation
import AppKit

enum RuntimeDiagnostics {
    private static let lock = NSLock()
    private static let fileName = "runtime-audio.log"
    private static let maxBytes = 512 * 1024

    static var fileURL: URL {
        MediaLibrary.supportRoot.appendingPathComponent(fileName)
    }

    static func install() {
        mark("APP launch · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        NSSetUncaughtExceptionHandler { exception in
            let reason = exception.reason ?? "No reason"
            RuntimeDiagnostics.mark("UNCAUGHT EXCEPTION · \(exception.name.rawValue) · \(reason)")
        }
    }

    static func mark(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "\(formatter.string(from: Date()))  \(message)\n"

        do {
            let url = fileURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber,
               size.intValue > maxBytes {
                let rotated = url.deletingLastPathComponent().appendingPathComponent("runtime-audio.previous.log")
                try? FileManager.default.removeItem(at: rotated)
                try? FileManager.default.moveItem(at: url, to: rotated)
            }

            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
                try handle.synchronize()
            }
            try handle.close()
        } catch {
            // Diagnostics must never interfere with live audio.
        }
    }

    static func tail(maxLines: Int = 30) -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else {
            return "No runtime diagnostics yet."
        }
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(maxLines)
            .joined(separator: "\n")
    }
}
