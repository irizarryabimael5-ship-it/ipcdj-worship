import Foundation
import AppKit

struct LegacyMigrationResult: Sendable {
    var songs: [SongProject]
    var importedStemCount: Int
    var warnings: [String]
}

private struct LegacyManifest: Decodable {
    var version: Int?
    var songs: [LegacySong]
    var stems: [LegacyBlob]
}

private struct LegacySong: Decodable {
    var id: String
    var title: String?
    var bpm: Double?
    var meter: String?
    var outputMode: String?
    var notes: String?
    var lyricsRaw: String?
    var stems: [LegacyStemMeta]?
    var sections: [LegacySection]?
    var settings: LegacySettings?
}

private struct LegacyStemMeta: Decodable {
    var id: String
    var name: String?
    var route: String?
    var volume: Double?
    var muted: Bool?
    var solo: Bool?
}

private struct LegacyBlob: Decodable {
    var id: String
    var songId: String
    var name: String
    var size: Int?
    var type: String?
    var downloadName: String
}

private struct LegacySection: Decodable {
    var type: String?
    var liveKey: String?
    var name: String?
    var startTimeSec: Double?
    var endTimeSec: Double?
    var loopStartTimeSec: Double?
    var loopEndTimeSec: Double?
    var loopable: Bool?
    var lyrics: String?
    var verified: Bool?
}

private struct LegacySettings: Decodable {
    var splitMonoMode: String?
    var clickSource: String?
    var clickPreset: String?
    var clickLevelDb: Double?
    var clickAccentDb: Double?
    var clickEighth: Bool?
    var clickSixteenth: Bool?
    var clickOffsetMs: Double?
    var livingColor: Bool?
    var livingColorIntensity: Double?
}

enum LegacyMigrationBuilder {
    static func build(from directory: URL) throws -> LegacyMigrationResult {
        let manifestURL = directory.appendingPathComponent("migration_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(LegacyManifest.self, from: data)

        var output: [SongProject] = []
        var importedStems = 0
        var warnings: [String] = []

        let blobsBySong = Dictionary(grouping: manifest.stems, by: \.songId)

        for old in manifest.songs {
            let newSongID = UUID()
            var song = SongProject(
                id: newSongID,
                title: old.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? old.title! : "Imported Song",
                bpm: old.bpm ?? 120,
                meterTop: parseMeter(old.meter).0,
                meterBottom: parseMeter(old.meter).1,
                outputMode: (old.outputMode ?? "").lowercased().contains("stereo") ? .stereo : .split,
                monoDownmixMode: legacyMono(old.settings?.splitMonoMode),
                stems: [],
                sections: [],
                click: legacyClick(old.settings),
                lyricsRaw: old.lyricsRaw,
                notes: old.notes,
                createdAt: Date()
            )

            let oldMeta = Dictionary(uniqueKeysWithValues: (old.stems ?? []).map { ($0.id, $0) })
            for blob in blobsBySong[old.id] ?? [] {
                let src = directory.appendingPathComponent(blob.downloadName)
                guard FileManager.default.fileExists(atPath: src.path) else {
                    warnings.append("Missing legacy stem: \(blob.name)")
                    continue
                }

                let meta = oldMeta[blob.id]
                let stemID = UUID()
                do {
                    let managed = try MediaLibrary.copyIntoLibrary(source: src, songID: newSongID, stemID: stemID)
                    let inspected = try WaveformBuilder.inspect(url: managed)
                    let route = legacyRoute(meta?.route, name: blob.name)
                    song.stems.append(
                        StemTrack(
                            id: stemID,
                            name: meta?.name ?? URL(fileURLWithPath: blob.name).deletingPathExtension().lastPathComponent,
                            path: managed.path,
                            volume: meta?.volume ?? 1,
                            muted: meta?.muted ?? false,
                            solo: meta?.solo ?? false,
                            reference: route == .reference,
                            route: route,
                            waveform: inspected.waveform,
                            duration: inspected.duration
                        )
                    )
                    importedStems += 1
                } catch {
                    warnings.append("\(blob.name): \(error.localizedDescription)")
                }
            }

            let duration = song.duration
            let sortedLegacy = (old.sections ?? []).sorted { ($0.startTimeSec ?? 0) < ($1.startTimeSec ?? 0) }
            for (index, oldSection) in sortedLegacy.enumerated() {
                let start = max(0, oldSection.startTimeSec ?? 0)
                let nextStart = index + 1 < sortedLegacy.count ? (sortedLegacy[index + 1].startTimeSec ?? duration) : duration
                let end = max(start + 0.001, oldSection.endTimeSec ?? nextStart)
                let loopStart = max(start, oldSection.loopStartTimeSec ?? start)
                let loopEnd = max(loopStart + 0.001, min(end, oldSection.loopEndTimeSec ?? end))
                let label = oldSection.liveKey ?? oldSection.type ?? oldSection.name ?? "SECTION"
                song.sections.append(
                    SectionMarker(
                        name: label,
                        start: start,
                        end: end,
                        loopStart: loopStart,
                        loopEnd: loopEnd,
                        loopable: oldSection.loopable ?? !label.uppercased().contains("OUTRO"),
                        lyrics: oldSection.lyrics ?? "",
                        verified: oldSection.verified ?? false
                    )
                )
            }

            output.append(song)
        }

        return LegacyMigrationResult(songs: output, importedStemCount: importedStems, warnings: warnings)
    }

    private static func parseMeter(_ value: String?) -> (Int, Int) {
        let parts = (value ?? "4/4").split(separator: "/")
        if parts.count == 2, let top = Int(parts[0]), let bottom = Int(parts[1]) {
            return (max(1, top), max(1, bottom))
        }
        return (4, 4)
    }

    private static func legacyMono(_ value: String?) -> MonoDownmixMode? {
        switch (value ?? "").lowercased() {
        case "left": return .leftOnly
        case "right": return .rightOnly
        case "sum": return .safeSum
        default: return nil
        }
    }

    private static func legacyRoute(_ value: String?, name: String) -> StemRoute {
        switch (value ?? "").lowercased() {
        case "reference": return .reference
        case "click": return .click
        case "music": return .music
        default:
            let lower = name.lowercased()
            if lower.contains("click") || lower.contains("cue") { return .click }
            if lower.contains("original") || lower.contains("master") || lower.contains("full mix") { return .reference }
            return .music
        }
    }

    private static func legacyClick(_ settings: LegacySettings?) -> ClickSettings {
        let source = settings?.clickSource?.lowercased() ?? "generated"
        return ClickSettings(
            enabled: source != "off",
            preset: ClickPreset(rawValue: {
                switch settings?.clickPreset?.lowercased() {
                case "warmpulse": return "Warm Pulse"
                case "studioblock": return "Studio Block"
                case "deeptick": return "Deep Tick"
                default: return "Soft Wood"
                }
            }()) ?? .softWood,
            levelDB: settings?.clickLevelDb ?? -12,
            accentDB: settings?.clickAccentDb ?? 3,
            eighths: settings?.clickEighth ?? false,
            sixteenths: settings?.clickSixteenth ?? false,
            offsetMS: settings?.clickOffsetMs ?? 0
        )
    }
}

@MainActor
final class LegacyMigrationManager: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case exporting
        case importing
        case complete
        case failed
    }

    @Published var state: State = .idle
    @Published var message = "Legacy Alpha data can be brought into the native app."
    @Published var detail = ""
    @Published var showMigration = false

    var legacyAvailable: Bool {
        FileManager.default.fileExists(atPath: legacyProfileURL.path) &&
        FileManager.default.fileExists(atPath: legacyHTMLURL.path)
    }

    var shouldOfferMigration: Bool {
        legacyAvailable && state != .complete
    }

    private var legacyProfileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/STEM Live/ChromeProfile", isDirectory: true)
    }

    private var legacyHTMLURL: URL {
        let candidates = [
            URL(fileURLWithPath: "/Applications/STEM Live.app/Contents/Resources/app/index.html"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/STEM Live.app/Contents/Resources/app/index.html")
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) ?? candidates[0]
    }

    func begin(store: ProjectStore, audio: AudioEngineController) {
        guard state != .preparing, state != .exporting, state != .importing else { return }
        guard legacyAvailable else {
            state = .failed
            message = "Legacy Alpha was not found."
            detail = "Expected the old STEM Live app and ChromeProfile on this Mac."
            return
        }

        guard let helper = Bundle.main.url(forResource: "legacy-migrator", withExtension: nil, subdirectory: "bin") else {
            state = .failed
            message = "Migration helper is missing."
            detail = "Reinstall STEM Live Native from the 0.6.2 DMG."
            return
        }

        let out = MediaLibrary.migrationRoot.appendingPathComponent("current", isDirectory: true)
        try? FileManager.default.removeItem(at: out)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        state = .preparing
        message = "Preparing a safe copy of your Legacy Alpha library…"
        detail = "Your old Chrome data is read-only during migration."

        let process = Process()
        process.executableURL = helper
        process.arguments = [
            "--profile", legacyProfileURL.path,
            "--html", legacyHTMLURL.path,
            "--out", out.path
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.contains("EXPORTING") {
                    self.state = .exporting
                    self.message = "Exporting songs and embedded stem audio from Legacy Alpha…"
                } else if !line.isEmpty {
                    self.detail = line
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            output.fileHandleForReading.readabilityHandler = nil
            let status = proc.terminationStatus
            let tailData = status == 0 ? Data() : output.fileHandleForReading.readDataToEndOfFile()
            let tail = String(data: tailData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            Task { @MainActor [weak self] in
                guard let self else { return }

                if status != 0 {
                    self.state = .failed
                    self.message = "Legacy migration could not finish."
                    self.detail = tail.isEmpty ? "Close the old STEM Live Alpha completely, then try again." : tail
                    return
                }

                self.state = .importing
                self.message = "Moving the legacy library into native managed storage…"
                self.detail = "Waveforms are being rebuilt from the original stem files."

                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        let built = try LegacyMigrationBuilder.build(from: out)
                        try? FileManager.default.removeItem(at: out)
                        return built
                    }.value

                    store.installMigratedSongs(result.songs)
                    self.state = .complete
                    self.message = "Legacy Alpha migration complete."
                    self.detail = "\(result.songs.count) song(s) and \(result.importedStemCount) stem file(s) imported." +
                        (result.warnings.isEmpty ? "" : " \(result.warnings.count) item(s) need review.")
                    if let song = store.currentSong {
                        try? audio.prepare(song: song)
                    }
                } catch {
                    self.state = .failed
                    self.message = "Native import failed."
                    self.detail = error.localizedDescription
                }
            }
        }

        do {
            try process.run()
            state = .exporting
            message = "Reading Legacy Alpha through its existing Chrome profile…"
            detail = "This can take a few minutes if your stems are large."
        } catch {
            state = .failed
            message = "Migration helper could not launch."
            detail = error.localizedDescription
        }
    }

    func resetForRetry() {
        state = .idle
        message = "Legacy Alpha data can be brought into the native app."
        detail = ""
    }
}
