import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var songs: [SongProject] = []
    @Published var currentSongID: UUID?
    @Published var page: WorkspacePage = .live
    @Published var selectedSectionID: UUID?
    @Published var livingColorEnabled = true
    @Published var livingColorIntensity: Double = 0.82
    @Published var livingColorPalette: LivingColorPalette = .aurora
    @Published var livingColorMotion: Double = 0.72
    @Published var livingColorCardAmount: Double = 0.74
    @Published var sidebarVisible = true
    @Published var focusMode = false
    @Published var showSongInHeader = false

    private struct Snapshot: Codable, Sendable {
        var songs: [SongProject]
        var currentSongID: UUID?
        var livingColorEnabled: Bool?
        var livingColorIntensity: Double?
        var livingColorPalette: LivingColorPalette?
        var livingColorMotion: Double?
        var livingColorCardAmount: Double?
        var sidebarVisible: Bool?
        var focusMode: Bool?
        var showSongInHeader: Bool?
    }

    private let fileURL: URL
    private let backupURL: URL
    private let saveQueue = DispatchQueue(label: "org.stemlive.project-persistence", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    private var saveGeneration: UInt64 = 0

    init() {
        let base = MediaLibrary.supportRoot
        fileURL = base.appendingPathComponent("projects.json")
        backupURL = base.appendingPathComponent("projects.backup.json")
        load()
    }

    var currentSong: SongProject? {
        guard let id = currentSongID else { return songs.first }
        return songs.first(where: { $0.id == id })
    }

    var currentSongIndex: Int? {
        guard let id = currentSongID else { return songs.isEmpty ? nil : 0 }
        return songs.firstIndex(where: { $0.id == id })
    }

    func mutateCurrent(_ body: (inout SongProject) -> Void) {
        guard let idx = currentSongIndex else { return }
        body(&songs[idx])
        save()
    }

    func selectSong(_ id: UUID) {
        currentSongID = id
        selectedSectionID = songs.first(where: { $0.id == id })?.sections.first?.id
        save()
    }

    func addSong(title: String = "New Song") {
        let song = SongProject(title: title)
        songs.append(song)
        currentSongID = song.id
        selectedSectionID = nil
        save()
    }

    func removeSong(_ id: UUID) {
        songs.removeAll { $0.id == id }
        MediaLibrary.removeMedia(for: id)
        if currentSongID == id {
            currentSongID = songs.first?.id
            selectedSectionID = songs.first?.sections.first?.id
        }
        save()
    }

    func renameCurrentSong(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutateCurrent { $0.title = clean }
    }

    func installMigratedSongs(_ imported: [SongProject]) {
        guard !imported.isEmpty else { return }

        let existingTitles = Set(songs.map { $0.title.lowercased() })
        var additions: [SongProject] = []
        for var song in imported {
            if existingTitles.contains(song.title.lowercased()) || additions.contains(where: { $0.title.lowercased() == song.title.lowercased() }) {
                song.title += " · Migrated"
            }
            additions.append(song)
        }

        songs.append(contentsOf: additions)
        if currentSongID == nil || songs.count == additions.count {
            currentSongID = additions.first?.id
        }
        selectedSectionID = currentSong?.sections.first?.id
        save()
    }

    func addSection(name: String, at start: Double) {
        guard let idx = currentSongIndex else { return }
        let songDuration = max(songs[idx].duration, start + 8)
        let next = songs[idx].sections.map(\.start).filter { $0 > start }.min() ?? min(songDuration, start + 16)
        let sec = SectionMarker(name: name, start: start, end: max(start + 0.25, next), loopStart: start, loopEnd: max(start + 0.25, next))
        songs[idx].sections.append(sec)
        songs[idx].sections.sort { $0.start < $1.start }
        normalizeSectionEnds(index: idx)
        selectedSectionID = sec.id
        save()
    }

    func updateSection(_ section: SectionMarker) {
        guard let idx = currentSongIndex,
              let sidx = songs[idx].sections.firstIndex(where: { $0.id == section.id }) else { return }
        var fixed = section
        fixed.start = max(0, fixed.start)
        fixed.end = max(fixed.start + 0.001, fixed.end)
        fixed.loopStart = max(fixed.start, fixed.loopStart)
        fixed.loopEnd = max(fixed.loopStart + 0.001, min(fixed.end, fixed.loopEnd))
        songs[idx].sections[sidx] = fixed
        songs[idx].sections.sort { $0.start < $1.start }
        normalizeSectionEnds(index: idx)
        save()
    }

    func removeSection(_ id: UUID) {
        guard let idx = currentSongIndex else { return }
        songs[idx].sections.removeAll { $0.id == id }
        normalizeSectionEnds(index: idx)
        selectedSectionID = songs[idx].sections.first?.id
        save()
    }

    func setSidebarVisible(_ visible: Bool) {
        sidebarVisible = visible
        save()
    }

    func setFocusMode(_ enabled: Bool) {
        focusMode = enabled
        if enabled { page = .live }
        save()
    }

    func resetViewPreferences() {
        sidebarVisible = true
        focusMode = false
        showSongInHeader = false
        livingColorEnabled = true
        livingColorIntensity = 0.82
        livingColorPalette = .aurora
        livingColorMotion = 0.72
        livingColorCardAmount = 0.74
        save()
    }

    private func normalizeSectionEnds(index: Int) {
        let duration = songs[index].duration
        guard !songs[index].sections.isEmpty else { return }
        songs[index].sections.sort { $0.start < $1.start }
        for i in songs[index].sections.indices {
            let nextStart = i + 1 < songs[index].sections.count ? songs[index].sections[i + 1].start : max(duration, songs[index].sections[i].end)
            if songs[index].sections[i].end <= songs[index].sections[i].start || songs[index].sections[i].end > nextStart {
                songs[index].sections[i].end = max(songs[index].sections[i].start + 0.001, nextStart)
            }
            songs[index].sections[i].loopStart = songs[index].sections[i].loopStart.clamped(songs[index].sections[i].start...songs[index].sections[i].end)
            songs[index].sections[i].loopEnd = max(songs[index].sections[i].loopStart + 0.001, min(songs[index].sections[i].end, songs[index].sections[i].loopEnd))
        }
    }

    /// UI mutations call this frequently (sliders, markers, Mix). 0.6.5 encoded
    /// every waveform array synchronously on the main actor for each change.
    /// 0.6.6 snapshots the value model cheaply and performs compact JSON encoding,
    /// backup rotation and atomic I/O on a dedicated utility queue.
    func save() {
        saveGeneration &+= 1
        let generation = saveGeneration
        let snapshot = makeSnapshot()
        let fileURL = fileURL
        let backupURL = backupURL

        saveWorkItem?.cancel()
        let item = DispatchWorkItem {
            Self.persist(snapshot, fileURL: fileURL, backupURL: backupURL)
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 0.10, execute: item)

        // generation is intentionally captured to make the sequencing explicit;
        // cancelled work items are harmless if they have already begun.
        _ = generation
    }

    func flushSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        let snapshot = makeSnapshot()
        let fileURL = fileURL
        let backupURL = backupURL
        saveQueue.async {
            Self.persist(snapshot, fileURL: fileURL, backupURL: backupURL)
        }
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(
            songs: songs,
            currentSongID: currentSongID,
            livingColorEnabled: livingColorEnabled,
            livingColorIntensity: livingColorIntensity,
            livingColorPalette: livingColorPalette,
            livingColorMotion: livingColorMotion,
            livingColorCardAmount: livingColorCardAmount,
            sidebarVisible: sidebarVisible,
            focusMode: focusMode,
            showSongInHeader: showSongInHeader
        )
    }

    private nonisolated static func persist(_ snapshot: Snapshot, fileURL: URL, backupURL: URL) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }
        let fm = FileManager.default

        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: fileURL, to: backupURL)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            if !fm.fileExists(atPath: fileURL.path), fm.fileExists(atPath: backupURL.path) {
                try? fm.copyItem(at: backupURL, to: fileURL)
            }
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        let primary = try? Data(contentsOf: fileURL)
        let backup = try? Data(contentsOf: backupURL)
        guard let snap = primary.flatMap({ try? decoder.decode(Snapshot.self, from: $0) })
            ?? backup.flatMap({ try? decoder.decode(Snapshot.self, from: $0) }) else { return }

        songs = snap.songs
        currentSongID = snap.currentSongID ?? songs.first?.id
        livingColorEnabled = snap.livingColorEnabled ?? true
        livingColorIntensity = snap.livingColorIntensity ?? 0.82
        livingColorPalette = snap.livingColorPalette ?? .aurora
        livingColorMotion = snap.livingColorMotion ?? 0.72
        livingColorCardAmount = snap.livingColorCardAmount ?? 0.74
        sidebarVisible = snap.sidebarVisible ?? true
        focusMode = snap.focusMode ?? false
        showSongInHeader = snap.showSongInHeader ?? false
        selectedSectionID = currentSong?.sections.first?.id
    }
}
