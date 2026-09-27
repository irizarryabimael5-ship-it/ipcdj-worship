import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var songs: [SongProject] = []
    @Published var currentSongID: UUID?
    @Published var page: WorkspacePage = .live
    @Published var selectedSectionID: UUID?
    @Published var livingColorEnabled = true
    @Published var livingColorIntensity: Double = 0.82

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("STEM Live Native", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("projects.json")
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
        if currentSongID == id {
            currentSongID = songs.first?.id
            selectedSectionID = songs.first?.sections.first?.id
        }
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

    func save() {
        struct Snapshot: Codable {
            var songs: [SongProject]
            var currentSongID: UUID?
            var livingColorEnabled: Bool
            var livingColorIntensity: Double
        }
        let snap = Snapshot(songs: songs, currentSongID: currentSongID, livingColorEnabled: livingColorEnabled, livingColorIntensity: livingColorIntensity)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        struct Snapshot: Codable {
            var songs: [SongProject]
            var currentSongID: UUID?
            var livingColorEnabled: Bool?
            var livingColorIntensity: Double?
        }
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        songs = snap.songs
        currentSongID = snap.currentSongID ?? songs.first?.id
        livingColorEnabled = snap.livingColorEnabled ?? true
        livingColorIntensity = snap.livingColorIntensity ?? 0.82
        selectedSectionID = currentSong?.sections.first?.id
    }
}
