import Foundation

enum MediaLibrary {
    static var supportRoot: URL {
        let fm = FileManager.default
        let applicationSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let root = applicationSupport.appendingPathComponent("STEM Live Native", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static var mediaRoot: URL {
        let url = supportRoot.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var migrationRoot: URL {
        let url = supportRoot.appendingPathComponent("LegacyMigration", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func managedURL(for source: URL, songID: UUID, stemID: UUID) -> URL {
        let dir = mediaRoot.appendingPathComponent(songID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension.lowercased()
        let base = sanitize(source.deletingPathExtension().lastPathComponent)
        return dir.appendingPathComponent("\(stemID.uuidString)_\(base).\(ext)")
    }

    @discardableResult
    static func copyIntoLibrary(source: URL, songID: UUID, stemID: UUID) throws -> URL {
        let fm = FileManager.default
        let dest = managedURL(for: source, songID: songID, stemID: stemID)

        if source.standardizedFileURL == dest.standardizedFileURL {
            return dest
        }

        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)

        let sourceSize = (try? fm.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.int64Value
        let destSize = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value
        if let sourceSize, let destSize, sourceSize != destSize {
            try? fm.removeItem(at: dest)
            throw NSError(
                domain: "STEMLive.MediaLibrary",
                code: -31,
                userInfo: [NSLocalizedDescriptionKey: "The managed stem copy did not verify correctly."]
            )
        }
        return dest
    }

    static func removeMedia(for songID: UUID) {
        let dir = mediaRoot.appendingPathComponent(songID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    static func sanitize(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = value.components(separatedBy: invalid)
        let joined = parts.filter { !$0.isEmpty }.joined(separator: "_")
        return joined.isEmpty ? "stem" : joined
    }
}
