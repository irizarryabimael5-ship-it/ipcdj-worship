import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @AppStorage("stemlive.native.lastSeenVersion") private var lastSeenVersion = ""
    @State private var whatsNew = false
    @State private var quickClick = false
    private let version = "0.6.0"

    var body: some View {
        ZStack {
            LivingColorView(metrics: audio.visual, enabled: store.livingColorEnabled, intensity: store.livingColorIntensity)
                .ignoresSafeArea()
            HStack(spacing: 14) {
                Sidebar().frame(width: 218)
                VStack(spacing: 12) {
                    Header()
                    Group {
                        switch store.page {
                        case .live: LivePage(quickClick: $quickClick)
                        case .set: SetPage()
                        case .arrange: ArrangePage()
                        case .mix: MixPage()
                        case .click: ClickPage()
                        case .system: SystemPage(whatsNew: $whatsNew)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
        .sheet(isPresented: $whatsNew) {
            WhatsNew {
                lastSeenVersion = version
                whatsNew = false
            }
            .frame(width: 620, height: 500)
        }
        .onAppear {
            if lastSeenVersion != version { whatsNew = true }
            if let song = store.currentSong { audio.reloadIfNeeded(song: song) }
        }
        .onChange(of: store.currentSongID) { _ in
            if let song = store.currentSong { audio.reloadIfNeeded(song: song) }
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12).fill(.white)
                    .frame(width: 40, height: 40)
                    .overlay(Text("S").foregroundColor(.black).font(.system(size: 18, weight: .black)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEM LIVE").font(.system(size: 12, weight: .black)).tracking(1.1)
                    Text("Native Performance").font(.system(size: 9)).foregroundColor(.secondary)
                }
                Spacer()
            }.padding(15)

            if let song = store.currentSong {
                VStack(alignment: .leading, spacing: 4) {
                    LabelText("CURRENT SONG")
                    Text(song.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                    Text("\(song.bpm, specifier: "%.1f") BPM · \(song.meterText)")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(13)
                .background(Card(corner: 17)).padding(.horizontal, 9)
            }

            HStack { LabelText("SETLIST"); Spacer(); Text("\(store.songs.count)").font(.caption2).foregroundColor(.secondary) }
                .padding(.horizontal, 15).padding(.top, 18).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(Array(store.songs.enumerated()), id: \.element.id) { idx, song in
                        Button {
                            store.selectSong(song.id)
                        } label: {
                            HStack(spacing: 9) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(store.currentSongID == song.id ? Color.white : Color.white.opacity(0.07))
                                    .frame(width: 28, height: 28)
                                    .overlay(Text("\(idx + 1)").font(.system(size: 9, weight: .black))
                                        .foregroundColor(store.currentSongID == song.id ? .black : .white))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title).font(.system(size: 10, weight: .bold)).lineLimit(1)
                                    Text("\(song.stems.count) stems").font(.system(size: 8)).foregroundColor(.secondary)
                                }
                                Spacer()
                            }.padding(9)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 8)
            }

            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(audio.isPlaying ? .green : .gray).frame(width: 6, height: 6)
                    Text(audio.engineStatus).font(.system(size: 8)).foregroundColor(.secondary).lineLimit(1)
                }
                Text("Native 0.6.0").font(.system(size: 8)).foregroundColor(.secondary.opacity(0.7))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
        }
        .background(RoundedRectangle(cornerRadius: 26).fill(.regularMaterial.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.09)))
    }
}

struct Header: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentSong?.title ?? "No Song").font(.system(size: 19, weight: .bold)).lineLimit(1)
                if let s = store.currentSong {
                    Text("\(s.bpm, specifier: "%.1f") BPM · \(s.meterText) · \(formatTime(s.duration)) · \(s.stems.filter{!$0.reference}.count) live stems")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 3) {
                ForEach(WorkspacePage.allCases) { page in
                    Button(page.rawValue) { store.page = page }
                        .buttonStyle(TabButton(active: store.page == page))
                }
            }.padding(4).background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.30)))
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(audio.engineStatus.contains("error") ? .orange : .green).frame(width: 6, height: 6)
                Text(audio.engineStatus.contains("error") ? "CHECK" : "READY")
                    .font(.system(size: 8, weight: .black)).tracking(1)
                    .foregroundColor(audio.engineStatus.contains("error") ? .orange : .green)
            }.padding(.horizontal, 12).frame(height: 34).background(Card(corner: 12))
        }
        .padding(.horizontal, 17).frame(height: 74)
        .background(RoundedRectangle(cornerRadius: 23).fill(.regularMaterial.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.white.opacity(0.09)))
    }
}

struct LivePage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @Binding var quickClick: Bool

    private var song: SongProject? { store.currentSong }
    private var active: SectionMarker? {
        guard let song else { return nil }
        return song.sections.last(where: { $0.start <= audio.currentTime }) ?? song.sections.first
    }

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    LabelText("NOW PLAYING")
                    Text(active?.name.uppercased() ?? "READY").font(.system(size: 27, weight: .bold))
                }
                Spacer()
                Text(formatTime(audio.currentTime)).font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
                Button(audio.loopEnabled ? "LOOP ON" : "LOOP OFF") { audio.loopEnabled.toggle() }.buttonStyle(SmallButton(primary: false))
                if song?.outputMode == .split {
                    Button("CLICK") { quickClick.toggle() }.buttonStyle(SmallButton(primary: quickClick))
                }
            }.padding(17).background(Card())

            if quickClick, let song, song.outputMode == .split {
                QuickClick(song: song)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let song {
                let columns = [GridItem(.adaptive(minimum: 220), spacing: 10)]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(song.sections) { section in
                            let isActive = active?.id == section.id
                            Button {
                                store.selectedSectionID = section.id
                                audio.jumpToSection(section, song: song)
                            } label: {
                                SectionCard(section: section, active: isActive, metrics: audio.visual)
                            }.buttonStyle(.plain)
                        }
                    }.padding(2)
                }
            } else {
                EmptyState(title: "No song loaded", subtitle: "Create a song in SET and import stems.")
            }

            if let song {
                HStack(spacing: 9) {
                    Button {
                        audio.togglePlay(song: song)
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill").frame(width: 48, height: 44)
                    }.buttonStyle(BigControl(primary: true))
                    Button { audio.stop(immediate: true) } label: {
                        Image(systemName: "stop.fill").frame(width: 44, height: 44)
                    }.buttonStyle(BigControl(primary: false))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(active?.name.uppercased() ?? "—").font(.system(size: 10, weight: .black))
                        ProgressView(value: song.duration > 0 ? audio.currentTime / song.duration : 0)
                    }.padding(.horizontal, 10).frame(maxWidth: .infinity)
                    Button("FADE OUT") { audio.fadeOut(seconds: 6.5) }.buttonStyle(DangerButton())
                }.padding(10).background(Card(corner: 18))
            }
        }.padding(4)
    }
}

struct SectionCard: View {
    let section: SectionMarker
    let active: Bool
    let metrics: VisualMetrics
    var body: some View {
        let dynamic = Color(red: 0.10 + metrics.mid * 0.18, green: 0.30 + metrics.air * 0.24, blue: 0.72 + metrics.bass * 0.18)
        VStack(alignment: .leading, spacing: 9) {
            HStack { LabelText(active ? "CURRENT" : (section.loopable ? "LOOPABLE" : "SECTION")); Spacer(); if section.verified { Image(systemName: "checkmark.seal.fill").foregroundColor(.green) } }
            Spacer()
            Text(section.name.uppercased()).font(.system(size: 22, weight: .bold))
            Text("\(formatTime(section.start)) · loop \(formatTime(section.loopStart))–\(formatTime(section.loopEnd))")
                .font(.system(size: 9)).foregroundColor(active ? .white.opacity(0.82) : .secondary)
        }
        .padding(18).frame(minHeight: 150, maxHeight: 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(active ? dynamic.opacity(0.78) : Color.black.opacity(0.23)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(active ? dynamic.opacity(0.95) : Color.white.opacity(0.09), lineWidth: active ? 1.5 : 1))
        .animation(.easeInOut(duration: 0.55), value: metrics)
    }
}

struct QuickClick: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    let song: SongProject
    var body: some View {
        HStack(spacing: 13) {
            Toggle("CLICK", isOn: Binding(get: { song.click.enabled }, set: { v in store.mutateCurrent { $0.click.enabled = v }; refresh() })).toggleStyle(.switch)
            Picker("Sound", selection: Binding(get: { song.click.preset }, set: { v in store.mutateCurrent { $0.click.preset = v }; refresh() })) {
                ForEach(ClickPreset.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 180)
            Slider(value: Binding(get: { song.click.levelDB }, set: { v in store.mutateCurrent { $0.click.levelDB = v }; refresh() }), in: -30...0).frame(width: 160)
            Text("\(song.click.levelDB, specifier: "%.1f") dB").font(.caption2).monospacedDigit().frame(width: 60)
            Toggle("1/8", isOn: Binding(get: { song.click.eighths }, set: { v in store.mutateCurrent { $0.click.eighths = v; if v { $0.click.sixteenths = false } }; refresh() }))
            Toggle("1/16", isOn: Binding(get: { song.click.sixteenths }, set: { v in store.mutateCurrent { $0.click.sixteenths = v; if v { $0.click.eighths = false } }; refresh() }))
            Spacer()
            Button("PREVIEW") { audio.previewClick(song: store.currentSong ?? song) }.buttonStyle(SmallButton(primary: true))
        }.padding(13).background(Card(corner: 17))
    }
    private func refresh() { if let s = store.currentSong { audio.applyStemState(s) } }
}

struct SetPage: View {
    @EnvironmentObject var store: ProjectStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeading(title: "Set", subtitle: "Songs for the current performance.")
            HStack {
                Button("+ NEW SONG") { store.addSong() }.buttonStyle(SmallButton(primary: true))
                Spacer()
            }
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(Array(store.songs.enumerated()), id: \.element.id) { idx, song in
                        Button { store.selectSong(song.id) } label: {
                            HStack {
                                Text(String(format: "%02d", idx + 1)).font(.system(size: 16, weight: .black)).foregroundColor(.secondary)
                                VStack(alignment: .leading) {
                                    Text(song.title).font(.system(size: 16, weight: .bold))
                                    Text("\(song.bpm, specifier: "%.1f") BPM · \(song.stems.count) stems · \(song.sections.count) sections").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                            }.padding(17).background(Card(corner: 18))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }.padding(5)
    }
}

struct ArrangePage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @State private var zoom: Double = 1
    @State private var newSectionName = "VERSE"
    private var selected: SectionMarker? {
        guard let song = store.currentSong else { return nil }
        return song.sections.first(where: { $0.id == store.selectedSectionID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                PageHeading(title: "Arrange", subtitle: "Native waveform editor · exact cut and loop boundaries.")
                Spacer()
                Button("IMPORT STEMS") { importStems() }.buttonStyle(SmallButton(primary: true))
                Button("+ SECTION @ PLAYHEAD") {
                    store.addSection(name: newSectionName, at: audio.currentTime)
                }.buttonStyle(SmallButton(primary: false))
            }
            if let song = store.currentSong {
                HStack(spacing: 10) {
                    Text("ZOOM").font(.caption2).foregroundColor(.secondary)
                    Slider(value: $zoom, in: 1...8).frame(width: 170)
                    Text(formatTime(audio.currentTime)).font(.system(size: 11, weight: .bold, design: .monospaced))
                    Spacer()
                    TextField("Section", text: $newSectionName).textFieldStyle(.roundedBorder).frame(width: 120)
                }.padding(.horizontal, 6)

                TimelineView(song: song, zoom: zoom, selectedID: store.selectedSectionID, playhead: audio.currentTime) { t in
                    audio.seek(song: song, to: t, smooth: false)
                } select: { id in
                    store.selectedSectionID = id
                } moveMarker: { id, time in
                    if var sec = song.sections.first(where: { $0.id == id }) {
                        let delta = time - sec.start
                        sec.start = max(0, time)
                        sec.loopStart = max(sec.start, sec.loopStart + delta)
                        sec.loopEnd = max(sec.loopStart + 0.001, sec.loopEnd + delta)
                        store.updateSection(sec)
                    }
                }
                .frame(maxHeight: .infinity)

                if let sec = selected {
                    SectionInspector(section: sec)
                }
            } else {
                EmptyState(title: "No song", subtitle: "Create a song first.")
            }
        }.padding(4)
    }

    private func importStems() {
        guard store.currentSong != nil else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        DispatchQueue.global(qos: .userInitiated).async {
            var built: [StemTrack] = []
            for url in urls {
                if let result = try? WaveformBuilder.inspect(url: url) {
                    let lower = url.deletingPathExtension().lastPathComponent.lowercased()
                    let ref = lower.contains("original") || lower.contains("master") || lower.contains("full mix")
                    built.append(StemTrack(name: url.deletingPathExtension().lastPathComponent, path: url.path, reference: ref, waveform: result.waveform, duration: result.duration))
                }
            }
            DispatchQueue.main.async {
                store.mutateCurrent { $0.stems.append(contentsOf: built) }
                if let s = store.currentSong { try? audio.prepare(song: s) }
            }
        }
    }
}

struct TimelineView: View {
    let song: SongProject
    let zoom: Double
    let selectedID: UUID?
    let playhead: Double
    let seek: (Double) -> Void
    let select: (UUID) -> Void
    let moveMarker: (UUID, Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let baseWidth = max(geo.size.width, geo.size.width * zoom)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    ruler(width: baseWidth)
                    ForEach(song.stems.filter { !$0.reference }) { stem in
                        HStack(spacing: 0) {
                            Text(stem.name).font(.system(size: 8, weight: .semibold)).lineLimit(1).frame(width: 130, alignment: .leading).padding(.horizontal, 8)
                            WaveLane(stem: stem, width: max(10, baseWidth - 130), duration: max(0.001, song.duration))
                        }.frame(height: 54).background(Color.black.opacity(0.24))
                    }
                }
                .frame(width: baseWidth)
                .overlay(alignment: .topLeading) {
                    let usable = max(1, baseWidth - 130)
                    ZStack(alignment: .topLeading) {
                        ForEach(song.sections) { sec in
                            let x = 130 + usable * CGFloat(sec.start / max(0.001, song.duration))
                            Rectangle().fill(selectedID == sec.id ? Color.cyan : Color.white.opacity(0.55)).frame(width: 2)
                                .offset(x: x)
                                .overlay(alignment: .topLeading) {
                                    Text(sec.name.uppercased()).font(.system(size: 7, weight: .black)).padding(4)
                                        .background(Color.black.opacity(0.8)).cornerRadius(5).offset(x: x + 3, y: 28)
                                }
                                .contentShape(Rectangle().size(width: 16, height: max(1, geo.size.height)))
                                .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                                    let local = max(0, min(usable, value.location.x - 130))
                                    let t = Double(local / usable) * song.duration
                                    moveMarker(sec.id, t)
                                    select(sec.id)
                                })
                                .onTapGesture { select(sec.id) }
                        }
                        let px = 130 + usable * CGFloat(playhead / max(0.001, song.duration))
                        Rectangle().fill(Color.white).frame(width: 1.5).offset(x: px)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { value in
                    let usable = max(1, baseWidth - 130)
                    let local = max(0, min(usable, value.location.x - 130))
                    seek(Double(local / usable) * song.duration)
                })
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.28)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.09)))
        }
    }

    private func ruler(width: CGFloat) -> some View {
        Canvas { ctx, size in
            let w = max(1, size.width - 130)
            let beats = max(1, Int(song.duration / (60 / max(30, song.bpm))))
            for b in 0...beats {
                if b % max(1, song.meterTop) == 0 {
                    let x = 130 + w * CGFloat(Double(b) / Double(beats))
                    var p = Path(); p.move(to: CGPoint(x: x, y: 16)); p.addLine(to: CGPoint(x: x, y: 30))
                    ctx.stroke(p, with: .color(.white.opacity(0.35)), lineWidth: 1)
                    ctx.draw(Text("\(b / max(1, song.meterTop) + 1)").font(.system(size: 7)).foregroundColor(.secondary), at: CGPoint(x: x + 8, y: 9))
                }
            }
        }.frame(width: width, height: 31)
    }
}

struct WaveLane: View {
    let stem: StemTrack
    let width: CGFloat
    let duration: Double
    var body: some View {
        Canvas { ctx, size in
            guard stem.waveform.count > 1 else { return }
            let mid = size.height / 2
            let n = stem.waveform.count
            var path = Path()
            for i in 0..<n {
                let x = CGFloat(i) / CGFloat(n - 1) * size.width
                let amp = CGFloat(stem.waveform[i]) * (size.height * 0.42)
                path.move(to: CGPoint(x: x, y: mid - amp))
                path.addLine(to: CGPoint(x: x, y: mid + amp))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.62)), lineWidth: 0.75)
        }.frame(width: width).background(Color.white.opacity(0.018))
    }
}

struct SectionInspector: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    let section: SectionMarker

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                LabelText("SELECTED")
                Text(section.name.uppercased()).font(.system(size: 15, weight: .bold))
            }.frame(width: 130, alignment: .leading)
            TimeField(title: "START", value: section.start) { v in edit { $0.start = v } }
            TimeField(title: "LOOP A", value: section.loopStart) { v in edit { $0.loopStart = v } }
            TimeField(title: "LOOP B", value: section.loopEnd) { v in edit { $0.loopEnd = v } }
            Button("START = PLAYHEAD") { edit { $0.start = audio.currentTime } }.buttonStyle(SmallButton(primary: false))
            Button("A = PLAYHEAD") { edit { $0.loopStart = audio.currentTime } }.buttonStyle(SmallButton(primary: false))
            Button("B = PLAYHEAD") { edit { $0.loopEnd = audio.currentTime } }.buttonStyle(SmallButton(primary: false))
            Button(section.verified ? "VERIFIED ✓" : "VERIFY CUT") { edit { $0.verified = true } }.buttonStyle(SmallButton(primary: section.verified))
        }.padding(12).background(Card(corner: 17))
    }

    private func edit(_ body: (inout SectionMarker) -> Void) {
        var s = section; body(&s); store.updateSection(s)
    }
}

struct TimeField: View {
    let title: String
    let value: Double
    let set: (Double) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabelText(title)
            TextField("", value: Binding(get: { value }, set: { set(max(0, $0)) }), format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder).frame(width: 90)
        }
    }
}

struct MixPage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            PageHeading(title: "Mix", subtitle: "Native stem levels, mute and solo.")
            if let song = store.currentSong {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(song.stems) { stem in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text(stem.name).font(.system(size: 11, weight: .bold))
                                    Text(stem.reference ? "REFERENCE · EXCLUDED" : "LIVE STEM").font(.system(size: 8, weight: .black)).foregroundColor(stem.reference ? .orange : .secondary)
                                }.frame(width: 260, alignment: .leading)
                                Slider(value: Binding(get: { stem.volume }, set: { v in update(stem) { $0.volume = v } }), in: 0...1.5)
                                Button("M") { update(stem) { $0.muted.toggle() } }.buttonStyle(SmallButton(primary: stem.muted))
                                Button("S") { update(stem) { $0.solo.toggle() } }.buttonStyle(SmallButton(primary: stem.solo))
                            }.padding(13).background(Card(corner: 16))
                        }
                    }
                }
            } else { EmptyState(title: "No song", subtitle: "Import stems in ARRANGE.") }
            Spacer()
        }.padding(5)
    }
    private func update(_ stem: StemTrack, _ body: (inout StemTrack) -> Void) {
        store.mutateCurrent { song in
            if let i = song.stems.firstIndex(where: { $0.id == stem.id }) { body(&song.stems[i]) }
        }
        if let s = store.currentSong { audio.applyStemState(s) }
    }
}

struct ClickPage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeading(title: "Click", subtitle: "Native host-clock click for split-output performance.")
            if let song = store.currentSong {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Generated Click", isOn: bind(song.click.enabled) { $0.enabled = $1 }).toggleStyle(.switch)
                        Picker("Sound", selection: bind(song.click.preset) { $0.preset = $1 }) {
                            ForEach(ClickPreset.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Button("PREVIEW CLICK") { audio.previewClick(song: store.currentSong ?? song) }.buttonStyle(SmallButton(primary: true))
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Card())
                    VStack(alignment: .leading, spacing: 16) {
                        SettingSlider(title: "LEVEL", value: song.click.levelDB, range: -30...0, suffix: "dB") { v in change { $0.levelDB = v } }
                        SettingSlider(title: "ACCENT", value: song.click.accentDB, range: -3...9, suffix: "dB") { v in change { $0.accentDB = v } }
                        SettingSlider(title: "GRID NUDGE", value: song.click.offsetMS, range: -500...500, suffix: "ms") { v in change { $0.offsetMS = v } }
                        HStack { Toggle("1/8", isOn: bind(song.click.eighths) { c,v in c.eighths = v; if v { c.sixteenths = false } }); Toggle("1/16", isOn: bind(song.click.sixteenths) { c,v in c.sixteenths = v; if v { c.eighths = false } }) }
                    }.padding(18).frame(width: 390).background(Card())
                }
            }
            Spacer()
        }.padding(5)
    }

    private func bind<T>(_ value: T, _ setter: @escaping (inout ClickSettings, T) -> Void) -> Binding<T> {
        Binding(get: { value }, set: { v in change { setter(&$0, v) } })
    }
    private func change(_ body: (inout ClickSettings) -> Void) {
        store.mutateCurrent { body(&$0.click) }
        if let s = store.currentSong { audio.applyStemState(s) }
    }
}

struct SystemPage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @Binding var whatsNew: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { PageHeading(title: "System", subtitle: "CoreAudio engine and stage appearance."); Spacer(); Button("WHAT'S NEW…") { whatsNew = true }.buttonStyle(SmallButton(primary: false)) }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 13) {
                    LabelText("AUDIO ENGINE")
                    Text("AVAudioEngine / CoreAudio").font(.system(size: 20, weight: .bold))
                    Text(audio.engineStatus).foregroundColor(.green).font(.system(size: 11, weight: .semibold))
                    if let song = store.currentSong {
                        Picker("Output", selection: Binding(get: { song.outputMode }, set: { mode in
                            store.mutateCurrent { $0.outputMode = mode }
                            if let s = store.currentSong { try? audio.prepare(song: s) }
                        })) { ForEach(OutputMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    }
                    Text("This preview contains no Chrome/WebAudio playback path. Audio scheduling uses CoreAudio host time and the native render graph.")
                        .font(.system(size: 10)).foregroundColor(.secondary).lineSpacing(4)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Card())
                VStack(alignment: .leading, spacing: 14) {
                    LabelText("STAGE APPEARANCE")
                    Toggle("Living Color", isOn: Binding(get: { store.livingColorEnabled }, set: { store.livingColorEnabled = $0; store.save() })).toggleStyle(.switch)
                    SettingSlider(title: "INTENSITY", value: store.livingColorIntensity, range: 0.25...1.15, suffix: "") { store.livingColorIntensity = $0; store.save() }
                    Text("Music metrics update around 20 Hz. Native Core Animation performs the visual interpolation; audio timing never waits on the UI.")
                        .font(.system(size: 9)).foregroundColor(.secondary).lineSpacing(4)
                }.padding(18).frame(width: 370, alignment: .leading).background(Card())
            }
            Spacer()
        }.padding(5)
    }
}

struct PageHeading: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 34, weight: .bold))
            Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
        }.padding(.horizontal, 5)
    }
}

struct Card: View {
    var corner: CGFloat = 21
    var body: some View {
        RoundedRectangle(cornerRadius: corner).fill(.regularMaterial.opacity(0.58))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.09)))
    }
}

struct LabelText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 8, weight: .black)).tracking(1.2).foregroundColor(.secondary) }
}

struct TabButton: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 8, weight: .black)).tracking(0.7)
            .foregroundColor(active ? .black : .secondary)
            .frame(minWidth: 61, minHeight: 37)
            .background(RoundedRectangle(cornerRadius: 11).fill(active ? Color.white : Color.clear))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct SmallButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 8, weight: .black)).tracking(0.4)
            .foregroundColor(primary ? .black : .white)
            .padding(.horizontal, 13).frame(minHeight: 39)
            .background(RoundedRectangle(cornerRadius: 11).fill(primary ? Color.white : Color.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(primary ? 0.8 : 0.10)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct BigControl: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundColor(primary ? .black : .white)
            .background(RoundedRectangle(cornerRadius: 13).fill(primary ? Color.white : Color.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.11)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct DangerButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 8, weight: .black)).foregroundColor(.pink)
            .padding(.horizontal, 13).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.pink.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.pink.opacity(0.25)))
    }
}

struct SettingSlider: View {
    let title: String, value: Double, range: ClosedRange<Double>, suffix: String
    let onChange: (Double) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { LabelText(title); Spacer(); Text("\(value, specifier: "%.1f") \(suffix)").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary) }
            Slider(value: Binding(get: { value }, set: onChange), in: range)
        }
    }
}

struct EmptyState: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(spacing: 8) { Text(title).font(.title2.bold()); Text(subtitle).foregroundColor(.secondary) }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Card())
    }
}

struct WhatsNew: View {
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15).fill(.white).frame(width: 52, height: 52)
                    .overlay(Text("S").foregroundColor(.black).font(.system(size: 23, weight: .black)))
                VStack(alignment: .leading) {
                    Text("What's New in STEM Live 0.6.0").font(.system(size: 23, weight: .bold))
                    Text("Native Performance Foundation").foregroundColor(.secondary)
                }
            }
            UpdateRow("01", "Native audio engine", "Chrome and WebAudio are removed from the live path. Playback uses AVAudioEngine and CoreAudio host-time scheduling.")
            UpdateRow("02", "Native Living Color", "The stage color is rendered with Core Animation and wakes/decays from the actual post-music signal.")
            UpdateRow("03", "Waveform Arrange", "Each live stem gets a native waveform lane with draggable section markers and exact millisecond editing.")
            UpdateRow("04", "Native Click", "The generated click shares the CoreAudio host clock and Quick Click appears in LIVE only for Music L / Click R.")
            UpdateRow("05", "Safe migration", "This installs as STEM Live Native beside the Chrome Alpha while we validate the new engine.")
            Spacer()
            HStack { Spacer(); Button("START TESTING") { dismiss() }.buttonStyle(SmallButton(primary: true)) }
        }.padding(24).background(Color.black.opacity(0.96))
    }
}

struct UpdateRow: View {
    let n: String, title: String, detail: String
    init(_ n: String, _ title: String, _ detail: String) { self.n=n; self.title=title; self.detail=detail }
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(n).font(.system(size: 9, weight: .black)).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .bold)); Text(detail).font(.system(size: 9)).foregroundColor(.secondary).lineSpacing(3) }
        }.padding(10).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
    }
}
