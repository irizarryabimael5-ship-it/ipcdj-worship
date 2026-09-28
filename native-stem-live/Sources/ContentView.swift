import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @AppStorage("stemlive.native.lastSeenVersion") private var lastSeenVersion = ""
    @State private var whatsNew = false
    @State private var quickClick = false
    @StateObject private var migration = LegacyMigrationManager()
    private let version = "0.6.6"

    var body: some View {
        ZStack {
            PerformanceBackdrop()

            HStack(spacing: store.focusMode ? 0 : 14) {
                if store.sidebarVisible && !store.focusMode {
                    Sidebar()
                        .frame(width: 248)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                VStack(spacing: store.focusMode ? 0 : 12) {
                    if !store.focusMode {
                        Header()
                    }

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
            .padding(store.focusMode ? 8 : 14)

            if migration.shouldOfferMigration && migration.state != .preparing && migration.state != .exporting && migration.state != .importing {
                VStack {
                    Spacer()
                    LegacyMigrationBanner(migration: migration)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 250)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            InstallLocationGate()
        }
        .background(WindowConfigurator())
        .preferredColorScheme(.dark)
        .background(Color.black)
        .sheet(isPresented: $whatsNew) {
            WhatsNew {
                lastSeenVersion = version
                whatsNew = false
            }
            .frame(width: 680, height: 590)
        }
        .sheet(isPresented: $migration.showMigration) {
            LegacyMigrationSheet(migration: migration)
                .environmentObject(store)
                .environmentObject(audio)
                .frame(width: 650, height: 470)
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

struct PerformanceBackdrop: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @EnvironmentObject var performance: AudioPerformanceState

    var body: some View {
        LivingColorView(
            metrics: performance.visual,
            enabled: store.livingColorEnabled,
            intensity: store.livingColorIntensity,
            palette: store.livingColorPalette,
            motion: store.livingColorMotion,
            playing: audio.isPlaying
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEM LIVE").font(.system(size: 14, weight: .black)).tracking(0.9)
                    Text("Native Performance").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                }
                Spacer()
            }.padding(15)

            if let song = store.currentSong {
                VStack(alignment: .leading, spacing: 4) {
                    LabelText("CURRENT SONG")
                    Text(song.title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                    Text("\(song.bpm, specifier: "%.1f") BPM · \(song.meterText)")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(13)
                .background(Card(corner: 17)).padding(.horizontal, 9)
            }

            HStack { LabelText("SETLIST"); Spacer(); Text("\(store.songs.count)").font(.system(size: 10.5, weight: .medium)).foregroundColor(.secondary) }
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
                                    .overlay(Text("\(idx + 1)").font(.system(size: 10, weight: .black))
                                        .foregroundColor(store.currentSongID == song.id ? .black : .white))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title).font(.system(size: 12, weight: .bold)).lineLimit(1)
                                    Text("\(song.stems.count) stems").font(.system(size: 10)).foregroundColor(.secondary)
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
                    Text(audio.engineStatus).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                }
                Text("Native 0.6.5").font(.system(size: 10.5, weight: .medium)).foregroundColor(.secondary.opacity(0.8))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
        }
        .background(RoundedRectangle(cornerRadius: 26).fill(.regularMaterial.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.09)))
    }
}

struct Header: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                LabelText("WORKSPACE")
                Text(store.showSongInHeader ? (store.currentSong?.title ?? "No Song") : store.page.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                if !store.showSongInHeader, let song = store.currentSong {
                    Text("\(song.bpm, specifier: "%.1f") BPM · \(song.meterText) · \(song.stems.filter{$0.effectiveRoute == .music}.count) live stems")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 180, alignment: .leading)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                ForEach(WorkspacePage.allCases) { page in
                    ImmediateTabButton(title: page.rawValue, active: store.page == page) {
                        store.page = page
                    }
                    .frame(width: 76, height: 40)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.30)))

            Spacer(minLength: 6)

            if let song = store.currentSong {
                HStack(spacing: 5) {
                    Button {
                        audio.togglePlay(song: song)
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(BigControl(primary: true))
                    .help("Play/Pause · Space")

                    Button {
                        audio.stop(immediate: true)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 27, height: 30)
                    }
                    .buttonStyle(BigControl(primary: false))
                    .help("Stop · Command-.")
                }
            }

            HStack(spacing: 6) {
                Circle().fill(audio.engineStatus.contains("error") ? .orange : .green).frame(width: 6, height: 6)
                Text(audio.engineStatus.contains("error") ? "CHECK" : "READY")
                    .font(.system(size: 10, weight: .black)).tracking(0.8)
                    .foregroundColor(audio.engineStatus.contains("error") ? .orange : .green)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Card(corner: 12))
        }
        .padding(.horizontal, 18)
        .frame(height: 78)
        .background(RoundedRectangle(cornerRadius: 23).fill(.regularMaterial.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.white.opacity(0.09)))
    }
}

struct LivePage: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @EnvironmentObject var performance: AudioPerformanceState
    @Binding var quickClick: Bool

    private var song: SongProject? { store.currentSong }

    private var active: SectionMarker? {
        guard let song else { return nil }
        return song.sections.last(where: { $0.start <= performance.currentTime }) ?? song.sections.first
    }

    private var nextSection: SectionMarker? {
        guard let song, let active,
              let index = song.sections.firstIndex(where: { $0.id == active.id }),
              index + 1 < song.sections.count else { return nil }
        return song.sections[index + 1]
    }

    var body: some View {
        VStack(spacing: store.focusMode ? 10 : 14) {
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    LabelText(audio.isPlaying ? "NOW PLAYING" : "READY")
                    Text(active?.name.uppercased() ?? "NO SECTION")
                        .font(.system(size: store.focusMode ? 34 : 31, weight: .bold))
                        .lineLimit(1)
                }

                if let nextSection {
                    Divider().frame(height: 42).opacity(0.25)
                    VStack(alignment: .leading, spacing: 5) {
                        LabelText("UP NEXT")
                        Text(nextSection.name.uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatTime(performance.currentTime))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("SPACE · PLAY / PAUSE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Button(audio.loopEnabled ? "LOOP ON" : "LOOP OFF") {
                    audio.setLoopEnabled(!audio.loopEnabled)
                }
                .buttonStyle(SmallButton(primary: audio.loopEnabled))

                if song?.outputMode == .split {
                    Button("QUICK CLICK") {
                        quickClick.toggle()
                    }
                    .buttonStyle(SmallButton(primary: quickClick))
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 92)
            .background(Card(corner: 22))

            if quickClick, let song, song.outputMode == .split {
                QuickClick(song: song)
            }

            if let song {
                let columns = [GridItem(.adaptive(minimum: store.focusMode ? 310 : 270), spacing: 12)]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(song.sections) { section in
                            let isActive = active?.id == section.id
                            Button {
                                store.selectedSectionID = section.id
                                audio.jumpToSection(section, song: song)
                            } label: {
                                SectionCard(
                                    section: section,
                                    active: isActive,
                                    metrics: performance.visual,
                                    playing: audio.isPlaying,
                                    palette: store.livingColorPalette,
                                    colorAmount: store.livingColorCardAmount
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Jump to \(section.name)") {
                                    store.selectedSectionID = section.id
                                    audio.jumpToSection(section, song: song)
                                }
                                Button(section.loopable && audio.loopEnabled ? "Disable Loop" : "Loop This Section") {
                                    store.selectedSectionID = section.id
                                    audio.jumpToSection(section, song: song)
                                    audio.setLoopEnabled(!(section.loopable && audio.loopEnabled))
                                }
                                Divider()
                                Button("Edit in Arrange") {
                                    store.selectedSectionID = section.id
                                    store.page = .arrange
                                }
                            }
                        }
                    }
                    .padding(2)
                }
            } else {
                EmptyState(title: "No song loaded", subtitle: "Create a song in SET and import stems in ARRANGE.")
            }

            if let song {
                HStack(spacing: 12) {
                    Button {
                        audio.togglePlay(song: song)
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 58, height: 52)
                    }
                    .buttonStyle(BigControl(primary: true))

                    Button {
                        audio.stop(immediate: true)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 50, height: 52)
                    }
                    .buttonStyle(BigControl(primary: false))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(active?.name.uppercased() ?? "—")
                                .font(.system(size: 12, weight: .black))
                            Spacer()
                            Text(song.duration > 0 ? formatTime(song.duration) : "—")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: song.duration > 0 ? performance.currentTime / song.duration : 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)

                    Button("FADE OUT") {
                        audio.fadeOut(seconds: 6.5)
                    }
                    .buttonStyle(DangerButton())
                }
                .padding(11)
                .background(Card(corner: 18))
            }
        }
        .padding(store.focusMode ? 0 : 4)
    }
}

struct SectionCard: View {
    let section: SectionMarker
    let active: Bool
    let metrics: VisualMetrics
    let playing: Bool
    let palette: LivingColorPalette
    let colorAmount: Double

    var body: some View {
        let colors = performanceColors(palette)
        let level = playing ? max(0.08, metrics.level) : 0
        let activeStrength = active ? 1.0 : 0.30
        let energy = level * activeStrength * colorAmount.clamped(0...1.2)
        let accentA = metrics.mid > metrics.bass ? colors.1 : colors.0
        let accentB = metrics.transient > 0.38 ? colors.2 : colors.3

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LabelText(active ? "CURRENT" : (section.loopable ? "LOOPABLE" : "SECTION"))
                Spacer()
                if section.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green)
                }
            }

            Spacer(minLength: 12)

            Text(section.name.uppercased())
                .font(.system(size: 25, weight: .bold))
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("START \(formatTime(section.start))")
                if section.loopable {
                    Text("•")
                    Text("LOOP \(formatTime(section.loopStart))–\(formatTime(section.loopEnd))")
                }
            }
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundColor(active && playing ? .white.opacity(0.88) : .secondary)
        }
        .padding(20)
        .frame(minHeight: 166, maxHeight: 190)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(active ? 0.18 : 0.28))

                if playing {
                    LinearGradient(
                        colors: [
                            accentA.opacity((active ? 0.30 : 0.075) + energy * (active ? 0.42 : 0.16)),
                            accentB.opacity((active ? 0.13 : 0.045) + energy * (active ? 0.30 : 0.10)),
                            Color.black.opacity(active ? 0.08 : 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    playing
                        ? accentA.opacity(active ? 0.70 : 0.10 + energy * 0.28)
                        : Color.white.opacity(active ? 0.20 : 0.09),
                    lineWidth: active ? 1.5 : 1
                )
        )
        .scaleEffect(active ? 1.0 : 0.997)
    }
}

private func performanceColors(_ palette: LivingColorPalette) -> (Color, Color, Color, Color) {
    switch palette {
    case .aurora:
        return (
            Color(red: 0.04, green: 0.48, blue: 1.0),
            Color(red: 0.69, green: 0.30, blue: 0.96),
            Color(red: 1.0, green: 0.25, blue: 0.51),
            Color(red: 0.12, green: 0.79, blue: 0.98)
        )
    case .ocean:
        return (
            Color(red: 0.04, green: 0.48, blue: 1.0),
            Color(red: 0.12, green: 0.79, blue: 0.98),
            Color(red: 0.08, green: 0.72, blue: 0.70),
            Color(red: 0.38, green: 0.90, blue: 1.0)
        )
    case .violet:
        return (
            Color(red: 0.34, green: 0.32, blue: 0.96),
            Color(red: 0.69, green: 0.30, blue: 0.96),
            Color(red: 1.0, green: 0.25, blue: 0.51),
            Color(red: 0.12, green: 0.79, blue: 0.98)
        )
    case .warmStage:
        return (
            Color(red: 0.34, green: 0.32, blue: 0.96),
            Color(red: 0.69, green: 0.30, blue: 0.96),
            Color(red: 1.0, green: 0.55, blue: 0.08),
            Color(red: 1.0, green: 0.72, blue: 0.18)
        )
    }
}

struct QuickClick: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    let song: SongProject
    @State private var tapTimes: [TimeInterval] = []

    var body: some View {
        HStack(spacing: 11) {
            Toggle("CLICK", isOn: Binding(
                get: { song.click.enabled },
                set: { v in change { $0.enabled = v } }
            ))
            .toggleStyle(.switch)

            Picker("", selection: Binding(
                get: { song.click.effectiveTempoMode },
                set: { v in
                    change {
                        $0.tempoMode = v
                        if v == .custom && $0.customBPM == nil { $0.customBPM = song.bpm }
                    }
                }
            )) {
                ForEach(ClickTempoMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 130)

            TextField(
                "",
                value: Binding(
                    get: { song.click.effectiveBPM(songBPM: song.bpm) },
                    set: { v in change { $0.tempoMode = .custom; $0.customBPM = v.clamped(30...300) } }
                ),
                format: .number.precision(.fractionLength(1))
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 66)

            Text("BPM").font(.system(size: 9.5, weight: .black)).foregroundColor(.secondary)

            Button("TAP") { registerTap() }
                .buttonStyle(SmallButton(primary: false))

            Picker("", selection: Binding(
                get: { song.click.division },
                set: { v in change { $0.setDivision(v) } }
            )) {
                ForEach(ClickDivision.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 76)

            Picker("", selection: Binding(
                get: { song.click.preset },
                set: { v in change { $0.preset = v } }
            )) {
                ForEach(ClickPreset.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 145)

            Slider(value: Binding(
                get: { song.click.levelDB },
                set: { v in change { $0.levelDB = v } }
            ), in: -30...0)
            .frame(minWidth: 100, maxWidth: 150)

            Text("\(song.click.levelDB, specifier: "%.1f") dB")
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .frame(width: 58)

            Spacer(minLength: 4)

            Button("PREVIEW") { audio.previewClick(song: store.currentSong ?? song) }
                .buttonStyle(SmallButton(primary: true))
        }
        .padding(12)
        .background(Card(corner: 17))
    }

    private func change(_ body: (inout ClickSettings) -> Void) {
        store.mutateCurrent { body(&$0.click) }
        if let current = store.currentSong { audio.applyStemState(current) }
    }

    private func registerTap() {
        let now = Date.timeIntervalSinceReferenceDate
        tapTimes = (tapTimes + [now]).filter { now - $0 <= 3.0 }
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0 - $1 }
        let useful = intervals.filter { $0 > 0.20 && $0 < 2.0 }
        guard !useful.isEmpty else { return }
        let average = useful.reduce(0, +) / Double(useful.count)
        change {
            $0.tempoMode = .custom
            $0.customBPM = (60 / average).clamped(30...300)
        }
    }
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
    @EnvironmentObject var performance: AudioPerformanceState
    @State private var zoom: Double = 1.25
    @State private var newSectionName = "VERSE"
    @State private var syncMessage: String?
    @State private var analysisMessage: String?

    private var selected: SectionMarker? {
        guard let song = store.currentSong else { return nil }
        return song.sections.first(where: { $0.id == store.selectedSectionID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                PageHeading(title: "Arrange", subtitle: "Timeline-first editing · waveforms, tempo, sync and millisecond cut control.")
                Spacer()
                if let analysisMessage {
                    Text(analysisMessage)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 250, alignment: .trailing)
                }
                Button("ANALYZE COLOR") { analyzeColor() }
                    .buttonStyle(SmallButton(primary: false))
                    .disabled(audio.isPlaying)
                Button("AUTO SYNC") { runAutoSync() }
                    .buttonStyle(SmallButton(primary: false))
                    .disabled(audio.isPlaying)
                Button("IMPORT STEMS") { importStems() }
                    .buttonStyle(SmallButton(primary: true))
                    .disabled(audio.isPlaying)
                Button("+ SECTION @ PLAYHEAD") {
                    store.addSection(name: newSectionName, at: performance.currentTime)
                }
                .buttonStyle(SmallButton(primary: false))
            }

            if let syncMessage {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    Text(syncMessage)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if store.currentSong?.stems.contains(where: { $0.effectiveSourceOffset > 0.0001 }) == true {
                        Button("RESET SYNC") { resetSync() }
                            .buttonStyle(SmallButton(primary: false))
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 38)
                .background(Card(corner: 13))
            }

            if let song = store.currentSong {
                ArrangeTransport(song: song, zoom: $zoom, newSectionName: $newSectionName)

                HStack(alignment: .top, spacing: 10) {
                    LogicTimelineView(
                        song: song,
                        zoom: zoom,
                        selectedID: store.selectedSectionID,
                        playhead: performance.currentTime,
                        seek: { time in
                            audio.seek(song: song, to: time, smooth: false)
                        },
                        select: { id in
                            store.selectedSectionID = id
                        },
                        moveMarker: { id, time in
                            moveSection(id: id, to: time, song: song)
                        },
                        updateStem: { stem, edit in
                            update(stem: stem, edit)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let section = selected {
                        LogicSectionInspector(section: section)
                            .frame(width: 305)
                    }
                }
            } else {
                EmptyState(title: "No song", subtitle: "Create a song in SET, then import stems here.")
            }
        }
        .padding(4)
    }

    private func moveSection(id: UUID, to time: Double, song: SongProject) {
        guard var section = song.sections.first(where: { $0.id == id }) else { return }
        let delta = time - section.start
        section.start = max(0, time)
        section.loopStart = max(section.start, section.loopStart + delta)
        section.loopEnd = max(section.loopStart + 0.001, section.loopEnd + delta)
        store.updateSection(section)
    }

    private func update(stem: StemTrack, _ body: (inout StemTrack) -> Void) {
        store.mutateCurrent { song in
            guard let index = song.stems.firstIndex(where: { $0.id == stem.id }) else { return }
            body(&song.stems[index])
        }
        if let current = store.currentSong { audio.applyStemState(current) }
    }

    private func importStems() {
        guard let targetSong = store.currentSong, !audio.isPlaying else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        let fileNames = urls.map(\.lastPathComponent)
        let displayNames = StemNaming.uniqueDisplayNames(for: fileNames)
        let suggestedTitle = StemNaming.suggestedSongTitle(from: fileNames)
        let songID = targetSong.id
        analysisMessage = "Importing and analyzing \(urls.count) stem\(urls.count == 1 ? "" : "s")…"

        DispatchQueue.global(qos: .userInitiated).async {
            var built: [StemTrack] = []
            for (position, url) in urls.enumerated() where FileManager.default.fileExists(atPath: url.path) {
                let suggestion = StemNaming.suggestion(for: url.lastPathComponent)
                let stemID = UUID()

                do {
                    let managed = try MediaLibrary.copyIntoLibrary(source: url, songID: songID, stemID: stemID)
                    let inspected = try WaveformBuilder.inspect(url: managed)
                    built.append(
                        StemTrack(
                            id: stemID,
                            name: position < displayNames.count ? displayNames[position] : suggestion.displayName,
                            path: managed.path,
                            reference: suggestion.route == .reference,
                            route: suggestion.route,
                            waveform: inspected.waveform,
                            duration: inspected.duration,
                            originalName: url.deletingPathExtension().lastPathComponent,
                            visualEnvelope: inspected.visual
                        )
                    )
                } catch {
                    continue
                }
            }

            DispatchQueue.main.async {
                store.mutateSong(songID) { song in
                    song.stems.append(contentsOf: built)
                    if let suggestedTitle,
                       StemNaming.isGenericSongTitle(song.title) {
                        song.title = suggestedTitle
                    }
                }

                analysisMessage = built.isEmpty
                    ? "No stems were imported."
                    : "Imported \(built.count) · names and Living Color analysis ready."

                if store.currentSongID == songID, let current = store.currentSong {
                    do {
                        try audio.prepare(song: current)
                    } catch {
                        analysisMessage = "Imported, but audio prepare reported: \(error.localizedDescription)"
                    }
                    if built.count >= 2 {
                        runAutoSync()
                    }
                }
            }
        }
    }

    private func analyzeColor() {
        guard let song = store.currentSong, !audio.isPlaying else { return }
        let songID = song.id
        let stems = song.stems
        analysisMessage = "Analyzing musical energy offline…"

        DispatchQueue.global(qos: .utility).async {
            var updates: [UUID: (Double, [Float], [VisualAnalysisSample])] = [:]
            for stem in stems {
                let url = URL(fileURLWithPath: stem.path)
                guard FileManager.default.fileExists(atPath: url.path),
                      let inspected = try? WaveformBuilder.inspect(url: url) else { continue }
                updates[stem.id] = (inspected.duration, inspected.waveform, inspected.visual)
            }

            DispatchQueue.main.async {
                store.mutateSong(songID) { target in
                    for index in target.stems.indices {
                        guard let value = updates[target.stems[index].id] else { continue }
                        target.stems[index].duration = value.0
                        target.stems[index].waveform = value.1
                        target.stems[index].visualEnvelope = value.2
                    }
                }
                analysisMessage = "Living Color analysis updated for \(updates.count) stem\(updates.count == 1 ? "" : "s")."
                if let current = store.currentSong { audio.applyStemState(current) }
            }
        }
    }

    private func runAutoSync() {
        guard let song = store.currentSong, !audio.isPlaying else { return }
        let songID = song.id
        syncMessage = "Analyzing stem alignment offline…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = StemSyncAnalyzer.analyze(song: song)
            DispatchQueue.main.async {
                store.mutateSong(songID) { target in
                    for index in target.stems.indices {
                        let id = target.stems[index].id
                        if let offset = result.offsets[id] {
                            target.stems[index].sourceOffsetSeconds = offset
                        }
                        if let confidence = result.confidences[id] {
                            target.stems[index].syncConfidence = confidence
                        }
                    }
                }
                syncMessage = result.message
                if let current = store.currentSong { audio.applyStemState(current) }
            }
        }
    }

    private func resetSync() {
        store.mutateCurrent { song in
            for index in song.stems.indices {
                song.stems[index].sourceOffsetSeconds = nil
                song.stems[index].syncConfidence = nil
            }
        }
        syncMessage = "Automatic source trims reset."
        if let current = store.currentSong { audio.applyStemState(current) }
    }
}

struct ArrangeTransport: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @EnvironmentObject var performance: AudioPerformanceState
    let song: SongProject
    @Binding var zoom: Double
    @Binding var newSectionName: String
    @State private var tapTimes: [TimeInterval] = []

    var body: some View {
        HStack(spacing: 10) {
            Button {
                audio.togglePlay(song: song)
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 42, height: 36)
            }
            .buttonStyle(BigControl(primary: true))

            Button {
                audio.stop(immediate: true)
            } label: {
                Image(systemName: "stop.fill").frame(width: 36, height: 36)
            }
            .buttonStyle(BigControl(primary: false))

            VStack(alignment: .leading, spacing: 2) {
                LabelText("POSITION")
                Text(formatTime(performance.currentTime))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            .frame(width: 132, alignment: .leading)

            Divider().frame(height: 34).opacity(0.22)

            HStack(spacing: 5) {
                VStack(alignment: .leading, spacing: 2) {
                    LabelText("SONG TEMPO")
                    TextField(
                        "",
                        value: Binding(
                            get: { song.bpm },
                            set: { setBPM($0) }
                        ),
                        format: .number.precision(.fractionLength(1))
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 72)
                }
                VStack(spacing: 3) {
                    Button("+") { setBPM(song.bpm + 1) }
                    Button("−") { setBPM(song.bpm - 1) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .black))
                Button("TAP") { registerTap() }
                    .buttonStyle(SmallButton(primary: false))
            }

            VStack(alignment: .leading, spacing: 2) {
                LabelText("METER")
                Text(song.meterText)
                    .font(.system(size: 13, weight: .bold))
            }

            Divider().frame(height: 34).opacity(0.22)

            LabelText("ZOOM")
            Slider(value: $zoom, in: 1...10)
                .frame(width: 145)
            Button("FIT") { zoom = 1 }
                .buttonStyle(SmallButton(primary: false))

            Spacer()

            TextField("Section name", text: $newSectionName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(width: 138)

            Text("SPACE = PLAY / PAUSE")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
        .background(Card(corner: 16))
    }

    private func setBPM(_ value: Double) {
        let bpm = value.clamped(30...300)
        store.mutateCurrent { $0.bpm = bpm }
        if let current = store.currentSong { audio.applyStemState(current) }
    }

    private func registerTap() {
        let now = Date.timeIntervalSinceReferenceDate
        tapTimes = (tapTimes + [now]).filter { now - $0 <= 3.0 }
        guard tapTimes.count >= 2 else { return }
        var intervals: [Double] = []
        for index in 1..<tapTimes.count {
            let value = tapTimes[index] - tapTimes[index - 1]
            if value > 0.20 && value < 2.0 { intervals.append(value) }
        }
        guard !intervals.isEmpty else { return }
        setBPM(60 / (intervals.reduce(0, +) / Double(intervals.count)))
    }
}

struct LogicTimelineView: View {
    let song: SongProject
    let zoom: Double
    let selectedID: UUID?
    let playhead: Double
    let seek: (Double) -> Void
    let select: (UUID) -> Void
    let moveMarker: (UUID, Double) -> Void
    let updateStem: (StemTrack, (inout StemTrack) -> Void) -> Void

    private let headerWidth: CGFloat = 218
    private let rulerHeight: CGFloat = 38
    private let arrangementHeight: CGFloat = 52
    private let rowHeight: CGFloat = 78

    var body: some View {
        GeometryReader { geo in
            let available = max(520, geo.size.width - headerWidth)
            let timelineWidth = max(available, available * zoom)
            let totalWidth = headerWidth + timelineWidth
            let totalHeight = rulerHeight + arrangementHeight + CGFloat(max(1, song.stems.count)) * rowHeight

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            TimelineHeaderCell(title: "TRACKS", subtitle: "\(song.stems.count) stems")
                                .frame(width: headerWidth, height: rulerHeight)
                            TimelineRuler(song: song)
                                .frame(width: timelineWidth, height: rulerHeight)
                        }

                        HStack(spacing: 0) {
                            TimelineHeaderCell(title: "ARRANGEMENT", subtitle: "drag markers")
                                .frame(width: headerWidth, height: arrangementHeight)
                            ArrangementLane(
                                song: song,
                                selectedID: selectedID,
                                width: timelineWidth,
                                select: select,
                                moveMarker: moveMarker
                            )
                            .frame(width: timelineWidth, height: arrangementHeight)
                        }

                        ForEach(song.stems) { stem in
                            HStack(spacing: 0) {
                                LogicTrackHeader(stem: stem) { edit in
                                    updateStem(stem, edit)
                                }
                                .frame(width: headerWidth, height: rowHeight)

                                WaveLane(
                                    stem: stem,
                                    width: timelineWidth,
                                    duration: max(0.001, song.duration)
                                )
                                .frame(width: timelineWidth, height: rowHeight)
                            }
                        }
                    }
                    .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)

                    TimelineGrid(song: song)
                        .frame(width: timelineWidth, height: max(1, totalHeight - rulerHeight))
                        .offset(x: headerWidth, y: rulerHeight)
                        .allowsHitTesting(false)

                    let playheadX = headerWidth + timelineWidth * CGFloat(playhead / max(0.001, song.duration))
                    Rectangle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 1.5, height: totalHeight)
                        .offset(x: playheadX)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard value.location.x >= headerWidth else { return }
                            let local = max(0, min(timelineWidth, value.location.x - headerWidth))
                            seek(Double(local / timelineWidth) * song.duration)
                        }
                )
            }
            .background(RoundedRectangle(cornerRadius: 17).fill(Color.black.opacity(0.34)))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.10)))
            .clipShape(RoundedRectangle(cornerRadius: 17))
        }
    }
}

struct TimelineGrid: View {
    let song: SongProject

    var body: some View {
        Canvas { ctx, size in
            let beat = 60 / max(30, song.bpm)
            let totalBeats = max(1, Int(ceil(song.duration / beat)))

            for index in 0...totalBeats {
                let time = Double(index) * beat
                let x = size.width * CGFloat(time / max(0.001, song.duration))
                let isBar = index % max(1, song.meterTop) == 0

                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(
                    path,
                    with: .color(.white.opacity(isBar ? 0.085 : 0.028)),
                    lineWidth: isBar ? 1 : 0.7
                )
            }
        }
    }
}

struct TimelineHeaderCell: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10, weight: .black)).tracking(0.7)
            Text(subtitle).font(.system(size: 10.5, weight: .medium)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
    }
}

struct TimelineRuler: View {
    let song: SongProject

    var body: some View {
        Canvas { ctx, size in
            let secondsPerBeat = 60 / max(30, song.bpm)
            let secondsPerBar = secondsPerBeat * Double(max(1, song.meterTop))
            let bars = max(1, Int(ceil(song.duration / secondsPerBar)))

            for bar in 0...bars {
                let time = Double(bar) * secondsPerBar
                let x = size.width * CGFloat(time / max(0.001, song.duration))

                var line = Path()
                line.move(to: CGPoint(x: x, y: 18))
                line.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(line, with: .color(.white.opacity(0.22)), lineWidth: 1)

                ctx.draw(
                    Text("\(bar + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: x + 11, y: 10)
                )
            }
        }
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
    }
}

struct ArrangementLane: View {
    let song: SongProject
    let selectedID: UUID?
    let width: CGFloat
    let select: (UUID) -> Void
    let moveMarker: (UUID, Double) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.opacity(0.018)

            ForEach(Array(song.sections.enumerated()), id: \.element.id) { index, section in
                let nextStart = index + 1 < song.sections.count ? song.sections[index + 1].start : max(song.duration, section.end)
                let startX = width * CGFloat(section.start / max(0.001, song.duration))
                let endX = width * CGFloat(nextStart / max(0.001, song.duration))
                let blockWidth = max(42, endX - startX - 2)
                let selected = selectedID == section.id

                Text(section.name.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(width: blockWidth, height: 34, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Color.accentColor.opacity(0.64) : Color.white.opacity(0.075))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? Color.accentColor.opacity(0.92) : Color.white.opacity(0.09))
                    )
                    .offset(x: startX + 1, y: 9)
                    .contentShape(Rectangle())
                    .onTapGesture { select(section.id) }
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onEnded { value in
                                let x = max(0, min(width, startX + value.translation.width))
                                moveMarker(section.id, Double(x / width) * song.duration)
                                select(section.id)
                            }
                    )
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
    }
}

struct LogicTrackHeader: View {
    let stem: StemTrack
    let update: ((inout StemTrack) -> Void) -> Void

    private var routeLabel: String {
        switch stem.effectiveRoute {
        case .music: return "MUSIC"
        case .click: return "CLICK"
        case .reference: return "REFERENCE"
        }
    }

    private var routeColor: Color {
        switch stem.effectiveRoute {
        case .music: return .blue
        case .click: return .cyan
        case .reference: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(routeColor)
                .frame(width: 4)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(stem.name)
                    .font(.system(size: 11.5, weight: .bold))
                    .lineLimit(1)
                Text(routeLabel)
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(0.7)
                    .foregroundColor(routeColor)
            }

            Spacer(minLength: 5)

            HStack(spacing: 5) {
                Button("M") { update { $0.muted.toggle() } }
                    .buttonStyle(TrackToggleStyle(active: stem.muted, tint: .orange))
                Button("S") { update { $0.solo.toggle() } }
                    .buttonStyle(TrackToggleStyle(active: stem.solo, tint: .yellow))
            }
        }
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.035))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }
}

struct TrackToggleStyle: ButtonStyle {
    let active: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .black))
            .foregroundColor(active ? .black : .secondary)
            .frame(width: 28, height: 27)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? tint : Color.white.opacity(configuration.isPressed ? 0.11 : 0.055))
            )
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08)))
    }
}

struct WaveLane: View {
    let stem: StemTrack
    let width: CGFloat
    let duration: Double

    private var waveformColor: Color {
        switch stem.effectiveRoute {
        case .music: return .white
        case .click: return .cyan
        case .reference: return .orange
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let mid = size.height / 2

            var center = Path()
            center.move(to: CGPoint(x: 0, y: mid))
            center.addLine(to: CGPoint(x: size.width, y: mid))
            ctx.stroke(center, with: .color(.white.opacity(0.06)), lineWidth: 1)

            guard stem.waveform.count > 1 else { return }
            let count = stem.waveform.count
            var waveform = Path()

            let trimRatio = stem.duration > 0 ? (stem.effectiveSourceOffset / stem.duration).clamped(0...0.999) : 0
            let startIndex = min(count - 1, max(0, Int(Double(count - 1) * trimRatio)))
            let visibleCount = max(2, count - startIndex)

            for visibleIndex in 0..<visibleCount {
                let sourceIndex = min(count - 1, startIndex + visibleIndex)
                let x = CGFloat(visibleIndex) / CGFloat(visibleCount - 1) * size.width
                let amp = CGFloat(stem.waveform[sourceIndex]) * (size.height * 0.39)
                waveform.move(to: CGPoint(x: x, y: mid - amp))
                waveform.addLine(to: CGPoint(x: x, y: mid + amp))
            }

            ctx.stroke(
                waveform,
                with: .color(waveformColor.opacity(stem.muted ? 0.22 : 0.72)),
                lineWidth: 0.82
            )
        }
        .frame(width: width)
        .background(Color.white.opacity(0.012))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }
}

struct LogicSectionInspector: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var performance: AudioPerformanceState
    let section: SectionMarker

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                LabelText("SECTION INSPECTOR")
                Text(section.name.uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
            }

            Divider().opacity(0.22)

            Toggle(
                "Loopable",
                isOn: Binding(
                    get: { section.loopable },
                    set: { value in edit { $0.loopable = value } }
                )
            )

            InspectorTimeRow(title: "SECTION START", value: section.start) { value in
                edit { $0.start = value }
            } setToPlayhead: {
                edit { $0.start = performance.currentTime }
            }

            InspectorTimeRow(title: "LOOP IN", value: section.loopStart) { value in
                edit { $0.loopStart = value }
            } setToPlayhead: {
                edit { $0.loopStart = performance.currentTime }
            }

            InspectorTimeRow(title: "LOOP OUT", value: section.loopEnd) { value in
                edit { $0.loopEnd = value }
            } setToPlayhead: {
                edit { $0.loopEnd = performance.currentTime }
            }

            Divider().opacity(0.22)

            Button(section.verified ? "CUT VERIFIED ✓" : "VERIFY CUT") {
                edit { $0.verified = true }
            }
            .buttonStyle(SmallButton(primary: section.verified))

            Button("DELETE SECTION") {
                store.removeSection(section.id)
            }
            .buttonStyle(DangerButton())

            Spacer()
        }
        .padding(17)
        .background(Card(corner: 18))
    }

    private func edit(_ body: (inout SectionMarker) -> Void) {
        var updated = section
        body(&updated)
        store.updateSection(updated)
    }
}

struct InspectorTimeRow: View {
    let title: String
    let value: Double
    let set: (Double) -> Void
    let setToPlayhead: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            LabelText(title)
            TextField(
                "",
                value: Binding(get: { value }, set: { set(max(0, $0)) }),
                format: .number.precision(.fractionLength(3))
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))

            HStack(spacing: 5) {
                Button("−10 ms") { set(max(0, value - 0.010)) }
                    .buttonStyle(SmallButton(primary: false))
                Button("+10 ms") { set(value + 0.010) }
                    .buttonStyle(SmallButton(primary: false))
            }

            Button("SET TO PLAYHEAD") { setToPlayhead() }
                .buttonStyle(SmallButton(primary: false))
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
                                    Text(stem.effectiveRoute == .reference ? "REFERENCE · EXCLUDED" : (stem.effectiveRoute == .click ? "CLICK · EXCLUDED FROM MUSIC" : "LIVE STEM"))
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(stem.effectiveRoute == .reference ? .orange : (stem.effectiveRoute == .click ? .cyan : .secondary))
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
    @State private var preflightMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PageHeading(title: "System", subtitle: "CoreAudio fidelity, routing and stage appearance.")
                Spacer()
                Button("WHAT'S NEW…") { whatsNew = true }.buttonStyle(SmallButton(primary: false))
            }

            if let song = store.currentSong {
                let report = audio.cachedPreflight(song: song)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                LabelText("STRICT AUDIO PREFLIGHT")
                                Text(report.transparentReady ? "TRANSPARENT PATH READY" : (report.srcActive ? "SAMPLE-RATE CONVERSION ACTIVE" : "REVIEW AUDIO PATH"))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(report.transparentReady ? .green : .orange)
                            }
                            Spacer()
                            Image(systemName: report.transparentReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(report.transparentReady ? .green : .orange)
                        }

                        HStack(spacing: 8) {
                            PreflightValue(title: "SOURCE RATE", value: report.sourceRateText)
                            PreflightValue(title: "SOURCE DEPTH", value: report.sourceBitText)
                            PreflightValue(title: "CHANNELS", value: report.sourceChannelText)
                            PreflightValue(title: "FORMAT", value: report.sourceFormatText)
                        }

                        Divider().opacity(0.25)

                        if let device = report.device {
                            HStack(spacing: 8) {
                                PreflightValue(title: "OUTPUT DEVICE", value: device.name)
                                PreflightValue(title: "DEVICE RATE", value: formatSampleRate(device.sampleRate))
                                PreflightValue(title: "BUFFER", value: "\(device.bufferFrames) frames")
                                PreflightValue(title: "SRC", value: report.srcActive ? "ACTIVE" : "NONE", accent: report.srcActive ? .orange : .green)
                            }

                            if report.canMatchDevice, let target = report.recommendedProjectRate {
                                Button("MATCH DEVICE TO \(formatSampleRate(target))") {
                                    do {
                                        try audio.matchDeviceToProjectRate(song: song)
                                        preflightMessage = "Output device matched to \(formatSampleRate(target)). Recheck the preflight status above."
                                    } catch {
                                        preflightMessage = error.localizedDescription
                                    }
                                }.buttonStyle(SmallButton(primary: true))
                            }
                        }

                        if let error = report.error {
                            Text(error).font(.system(size: 11)).foregroundColor(.orange)
                        }
                        if let preflightMessage {
                            Text(preflightMessage).font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(3)
                        }

                        Text(report.allLossless
                             ? "All live stems are lossless source formats. STEM Live performs no lossy encode/decode stage."
                             : "One or more live stems are not identified as a lossless source format.")
                            .font(.system(size: 11))
                            .foregroundColor(report.allLossless ? .secondary : .orange)
                            .lineSpacing(3)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Card())

                    VStack(alignment: .leading, spacing: 14) {
                        LabelText("ROUTING")
                        Picker("Output", selection: Binding(get: { song.outputMode }, set: { mode in
                            guard !audio.isPlaying else {
                                preflightMessage = "Stop playback before changing the output mode. 0.6.4 intentionally blocks live graph reconstruction."
                                return
                            }

                            let previous = song.outputMode
                            store.mutateCurrent { $0.outputMode = mode }
                            guard let current = store.currentSong else { return }

                            do {
                                try audio.changeOutputMode(song: current)
                                audio.refreshPreflight(song: current)
                                preflightMessage = "Output changed to \(mode.rawValue). The audio graph was rebuilt while stopped."
                            } catch {
                                store.mutateCurrent { $0.outputMode = previous }
                                if let reverted = store.currentSong {
                                    try? audio.changeOutputMode(song: reverted)
                                }
                                preflightMessage = error.localizedDescription
                            }
                        })) {
                            ForEach(OutputMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(audio.isPlaying)

                        if song.outputMode == .split {
                            Divider().opacity(0.25)
                            LabelText("MONO DOWNMIX")
                            Picker("Downmix", selection: Binding(get: { song.effectiveMonoDownmixMode }, set: { mode in
                                let previous = song.monoDownmixMode
                                store.mutateCurrent { $0.monoDownmixMode = mode }
                                guard let current = store.currentSong else { return }
                                do {
                                    try audio.applyRouting(song: current)
                                    preflightMessage = "Mono downmix coefficients updated safely."
                                } catch {
                                    store.mutateCurrent { $0.monoDownmixMode = previous }
                                    if let reverted = store.currentSong { try? audio.applyRouting(song: reverted) }
                                    preflightMessage = error.localizedDescription
                                }
                            })) {
                                ForEach(MonoDownmixMode.allCases) { Text($0.rawValue).tag($0) }
                            }

                            Text("Safe Sum is the default: L and R feed an Apple AUMatrixMixer at -6.02 dB each, preserving headroom for correlated stereo material. Equal Power is louder but may clip on highly correlated mixes. Left/Right Only bypass stereo summing for phase-sensitive sources.")
                                .font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(4)
                        }

                        LabelText("ENGINE")
                        Text("AVAudioEngine / CoreAudio").font(.system(size: 18, weight: .bold))
                        Text(audio.engineStatus)
                            .foregroundColor(audio.engineStatus.contains("error") ? .orange : .green)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(18).frame(width: 410, alignment: .leading).background(Card())
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 14) {
                        LabelText("STAGE APPEARANCE")
                        Toggle("Living Color", isOn: Binding(get: { store.livingColorEnabled }, set: {
                            store.livingColorEnabled = $0; store.save()
                        })).toggleStyle(.switch)
                        SettingSlider(title: "INTENSITY", value: store.livingColorIntensity, range: 0.25...1.15, suffix: "") {
                            store.livingColorIntensity = $0; store.save()
                        }
                        Text("Music metrics update around 20 Hz. Core Animation performs the visual interpolation; the UI never determines audio timing.")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(4)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Card())

                    VStack(alignment: .leading, spacing: 10) {
                        LabelText("WHAT THE STATUS MEANS")
                        Text("TRANSPARENT PATH READY")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.green)
                        Text("Lossless source files are present and every live stem matches the hardware sample rate, so no sample-rate conversion is required.")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(4)
                        Text("SRC ACTIVE")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
                        Text("At least one live stem differs from the output device rate. Playback remains native Float32, but CoreAudio must resample that source.")
                            .font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(4)
                    }.padding(18).frame(width: 410, alignment: .leading).background(Card())
                }
            } else {
                EmptyState(title: "No song loaded", subtitle: "Create a song and import stems to run audio preflight.")
            }
            Spacer()
        }.padding(5)
    }
}

struct PreflightValue: View {
    let title: String
    let value: String
    var accent: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabelText(title)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06)))
    }
}

struct PageHeading: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 36, weight: .bold))
            Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
        }.padding(.horizontal, 5)
    }
}

struct Card: View {
    var corner: CGFloat = 21
    var body: some View {
        RoundedRectangle(cornerRadius: corner).fill(.regularMaterial.opacity(0.44))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.09)))
    }
}

struct LabelText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 10, weight: .black)).tracking(0.9).foregroundColor(.secondary) }
}

struct TabButton: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 10, weight: .black)).tracking(0.7)
            .foregroundColor(active ? .black : .secondary)
            .frame(minWidth: 61, minHeight: 37)
            .background(RoundedRectangle(cornerRadius: 11).fill(active ? Color.white : Color.clear))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct SmallButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 10, weight: .black)).tracking(0.25)
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
        configuration.label.font(.system(size: 10, weight: .black)).foregroundColor(.pink)
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
            HStack { LabelText(title); Spacer(); Text("\(value, specifier: "%.1f") \(suffix)").font(.system(size: 10.5, weight: .bold)).foregroundColor(.secondary) }
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
                    Text("What's New in STEM Live 0.6.5").font(.system(size: 23, weight: .bold))
                    Text("Playback Crash Fix").foregroundColor(.secondary)
                }
            }
            UpdateRow("01", "Play-button crash fixed", "The generated click is mono, but the previous click player could negotiate a stereo output format. AVAudioPlayerNode rejects a scheduled buffer whose channel count does not match its node format. 0.6.5 explicitly pins the click node to mono before any click buffer can be scheduled.")
            UpdateRow("02", "Click scheduling hardened", "Generated clicks are validated against the negotiated node format and scheduled on the player sample timeline. A mismatch disables the click instead of reaching an invalid playback call.")
            UpdateRow("03", "Transparent music path", "The live music path no longer contains the reverb unit. Stereo playback is Player → Music Mixer → Output Router; there is no lossy encoding stage.")
            UpdateRow("04", "Living Color off the render thread", "Stage color now follows the song's precomputed waveform envelope instead of installing a realtime tap in the live audio graph.")
            UpdateRow("05", "Persistent diagnostics", "STEM Live now writes its own flushed runtime audio breadcrumbs, including the exact operation reached before a termination, so a future OS-level abort is no longer invisible.")
            Spacer()
            HStack { Spacer(); Button("START TESTING") { dismiss() }.buttonStyle(SmallButton(primary: true)) }
        }.padding(24).background(Color.black.opacity(0.96))
    }
}

struct LegacyMigrationBanner: View {
    @ObservedObject var migration: LegacyMigrationManager

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.cyan.opacity(0.10)))
            VStack(alignment: .leading, spacing: 3) {
                Text("LEGACY ALPHA LIBRARY FOUND")
                    .font(.system(size: 10, weight: .black)).tracking(0.8)
                Text("Bring your existing songs, lyrics, sections and embedded stem audio into the native app.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Button("IMPORT") { migration.showMigration = true }
                .buttonStyle(SmallButton(primary: true))
            Button("LATER") { migration.state = .complete }
                .buttonStyle(SmallButton(primary: false))
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 17).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.cyan.opacity(0.20)))
    }
}

struct LegacyMigrationSheet: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var audio: AudioEngineController
    @ObservedObject var migration: LegacyMigrationManager

    private var working: Bool {
        migration.state == .preparing || migration.state == .exporting || migration.state == .importing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 15).fill(Color.cyan.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 22, weight: .bold)).foregroundColor(.cyan))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Migrate Legacy Alpha").font(.system(size: 23, weight: .bold))
                    Text("One-time bridge from the Chrome Alpha into native managed storage.")
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                MigrationStep(number: "1", title: "Read a safe copy", detail: "The migrator copies your old custom Chrome profile before opening it. The original Legacy Alpha library is not modified.")
                MigrationStep(number: "2", title: "Export embedded audio", detail: "Songs, lyrics, section cuts and the stem blobs stored inside IndexedDB are exported from the exact old app origin.")
                MigrationStep(number: "3", title: "Move into native storage", detail: "STEM Live Native copies those stems into its own media library and rebuilds native waveforms.")
            }

            if working {
                ProgressView().progressViewStyle(.linear)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(migration.message).font(.system(size: 12, weight: .bold))
                if !migration.detail.isEmpty {
                    Text(migration.detail).font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(3)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.035)))

            Spacer()

            HStack {
                if migration.state == .failed {
                    Button("RETRY") {
                        migration.resetForRetry()
                        migration.begin(store: store, audio: audio)
                    }.buttonStyle(SmallButton(primary: true))
                } else if migration.state == .complete {
                    Button("DONE") { migration.showMigration = false }
                        .buttonStyle(SmallButton(primary: true))
                } else if !working {
                    Button("START MIGRATION") {
                        migration.begin(store: store, audio: audio)
                    }.buttonStyle(SmallButton(primary: true))
                }
                Spacer()
                if !working {
                    Button("CLOSE") { migration.showMigration = false }
                        .buttonStyle(SmallButton(primary: false))
                }
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.96))
    }
}

struct MigrationStep: View {
    let number: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number).font(.system(size: 10, weight: .black)).foregroundColor(.black)
                .frame(width: 28, height: 28).background(Circle().fill(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .bold))
                Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(3)
            }
        }
    }
}

struct UpdateRow: View {
    let n: String, title: String, detail: String
    init(_ n: String, _ title: String, _ detail: String) { self.n=n; self.title=title; self.detail=detail }
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(n).font(.system(size: 10, weight: .black)).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .bold)); Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineSpacing(3) }
        }.padding(10).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
    }
}
