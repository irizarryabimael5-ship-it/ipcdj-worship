import Foundation
import AVFoundation
import Accelerate
import AudioToolbox
import Darwin

enum STEMLiveAudioError: LocalizedError {
    case outputUnavailable
    case invalidStereoFormat
    case splitRequiresStereoOutput(Int)
    case routingChangeWhilePlaying
    case invalidStemFormat(String)
    case invalidClickFormat
    case noPlayableStems

    var errorDescription: String? {
        switch self {
        case .outputUnavailable:
            return "The selected CoreAudio output is not currently available."
        case .invalidStereoFormat:
            return "STEM Live could not create the required stereo processing format."
        case let .splitRequiresStereoOutput(channels):
            return "Music L / Click R requires at least 2 output channels. The current device reports \(channels)."
        case .routingChangeWhilePlaying:
            return "Stop playback before changing Stereo Music / Music L / Click R. This stability gate prevents live graph reconstruction."
        case let .invalidStemFormat(name):
            return "\(name) has an invalid audio format and was not connected."
        case .invalidClickFormat:
            return "The generated click could not create a stable mono CoreAudio format."
        case .noPlayableStems:
            return "No valid live stem could be scheduled for playback."
        }
    }
}

final class AudioPerformanceState: ObservableObject {
    @Published fileprivate(set) var currentTime: Double = 0
    @Published fileprivate(set) var visual = VisualMetrics()
}

final class AudioEngineController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var engineStatus = "Audio idle"
    @Published private(set) var preflightGeneration = 0
    @Published private(set) var latestPreflight: AudioPreflightReport?
    @Published private(set) var loopEnabled = false

    // High-frequency transport/visual state is intentionally isolated from the
    // controller's slower configuration state. This prevents a 30 Hz playhead
    // from invalidating every view that only needs routing/status information.
    let performance = AudioPerformanceState()
    var currentTime: Double {
        get { performance.currentTime }
        set { performance.currentTime = newValue }
    }
    var visual: VisualMetrics {
        get { performance.visual }
        set { performance.visual = newValue }
    }

    private var engine = AVAudioEngine()
    private var musicMixer = AVAudioMixerNode()
    private var musicRouter = AVAudioMixerNode()
    private var clickMixer = AVAudioMixerNode()
    private var clickNode = AVAudioPlayerNode()
    private var monoMatrix: AVAudioUnit?

    private var players: [UUID: AVAudioPlayerNode] = [:]
    private var files: [UUID: AVAudioFile] = [:]
    private var activeSong: SongProject?

    private var anchorHost: UInt64 = 0
    private var anchorOffset: Double = 0
    private var transportTimer: DispatchSourceTimer?
    private var clickTimer: DispatchSourceTimer?
    private var nextClickIndex: Int = 0
    private var lastClickSignature = ""

    private var normalClickBuffer: AVAudioPCMBuffer?
    private var accentClickBuffer: AVAudioPCMBuffer?
    private var subdivisionClickBuffer: AVAudioPCMBuffer?

    private var visualSmooth = VisualMetrics()
    private var lastVisualLevel: Double = 0

    private let graphLock = NSRecursiveLock()
    private var gainRampTimer: DispatchSourceTimer?
    private var gainRampGeneration = 0
    private var fadeStopWorkItem: DispatchWorkItem?
    private var configObserver: NSObjectProtocol?
    private var recoveryWorkItem: DispatchWorkItem?
    private var isRecoveringConfiguration = false
    private var preparedStemSignature = ""
    private var preparedOutputMode: OutputMode?
    private var loopSectionID: UUID?
    private var loopJumpPending = false
    private var loopingActive = false
    private var transportRunning = false
    private var transportGeneration = 0
    private var pausedPosition: Double = 0

    init() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.scheduleConfigurationRecovery()
        }
    }

    deinit {
        recoveryWorkItem?.cancel()
        fadeStopWorkItem?.cancel()
        gainRampGeneration &+= 1
        gainRampTimer?.cancel()
        transportTimer?.cancel()
        clickTimer?.cancel()
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        engine.stop()
    }

    var hardwareSampleRate: Double {
        let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
        return sr > 0 ? sr : (try? CoreAudioDeviceManager.currentOutputInfo().sampleRate) ?? 48_000
    }

    var outputChannelCount: Int {
        Int(engine.outputNode.outputFormat(forBus: 0).channelCount)
    }

    func preflight(song: SongProject) -> AudioPreflightReport {
        AudioPreflight.inspect(
            song: song,
            engineSampleRate: hardwareSampleRate,
            outputChannels: outputChannelCount
        )
    }

    func cachedPreflight(song: SongProject) -> AudioPreflightReport {
        if let latestPreflight { return latestPreflight }
        let report = preflight(song: song)
        DispatchQueue.main.async { [weak self] in
            self?.latestPreflight = report
            self?.preflightGeneration &+= 1
        }
        return report
    }

    func refreshPreflight(song: SongProject) {
        let report = preflight(song: song)
        DispatchQueue.main.async { [weak self] in
            self?.latestPreflight = report
            self?.preflightGeneration &+= 1
        }
    }

    func matchDeviceToProjectRate(song: SongProject) throws {
        graphLock.lock()
        defer { graphLock.unlock() }
        recoveryWorkItem?.cancel()
        isRecoveringConfiguration = true
        defer { isRecoveringConfiguration = false }
        let report = preflight(song: song)
        guard let target = report.recommendedProjectRate else { return }
        stop(immediate: true)
        teardownEngine()
        engineStatus = "Matching device to \(formatSampleRate(target))…"
        try CoreAudioDeviceManager.setNominalSampleRate(target)
        try prepare(song: song)
    }

    func prepare(song: SongProject) throws {
        graphLock.lock()
        defer { graphLock.unlock() }

        stop(immediate: true)
        teardownEngine()
        activeSong = song

        engine = AVAudioEngine()
        musicMixer = AVAudioMixerNode()
        musicRouter = AVAudioMixerNode()
        clickMixer = AVAudioMixerNode()
        clickNode = AVAudioPlayerNode()
        monoMatrix = nil
        players = [:]
        files = [:]

        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sr = outputFormat.sampleRate
        let outputChannels = Int(outputFormat.channelCount)
        guard sr > 0, outputChannels > 0 else {
            throw STEMLiveAudioError.outputUnavailable
        }
        guard let stereo = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2) else {
            throw STEMLiveAudioError.invalidStereoFormat
        }
        if song.outputMode == .split, outputChannels < 2 {
            throw STEMLiveAudioError.splitRequiresStereoOutput(outputChannels)
        }

        engine.attach(musicMixer)
        engine.attach(musicRouter)
        engine.attach(clickMixer)
        engine.attach(clickNode)

        if song.outputMode == .split {
            let matrix = try instantiateMatrixMixer()
            monoMatrix = matrix
            engine.attach(matrix)
            engine.connect(musicMixer, to: matrix, format: stereo)
            engine.connect(matrix, to: musicRouter, format: stereo)
        } else {
            // Transparent stereo path: no effect unit, no matrix, no lossy stage.
            engine.connect(musicMixer, to: musicRouter, format: stereo)
        }

        engine.connect(musicRouter, to: engine.mainMixerNode, format: nil)
        musicRouter.pan = 0

        // IMPORTANT: generated click buffers are mono. AVAudioPlayerNode requires
        // a scheduled buffer's channel count to match the node's output format.
        // Leaving this connection as nil allowed CoreAudio to negotiate stereo,
        // then the first mono click scheduled at Play could terminate the process.
        guard let clickFormat = AVAudioFormat(
            standardFormatWithSampleRate: sr,
            channels: 1
        ) else {
            throw STEMLiveAudioError.invalidClickFormat
        }
        engine.connect(clickNode, to: clickMixer, format: clickFormat)
        engine.connect(clickMixer, to: engine.mainMixerNode, format: nil)
        clickMixer.pan = 1

        for stem in song.stems where stem.effectiveRoute == .music {
            let url = URL(fileURLWithPath: stem.path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw STEMLiveAudioError.invalidStemFormat(stem.name)
            }

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: musicMixer, format: format)
            player.volume = stem.muted ? 0 : Float(stem.volume.clamped(0...1.5))
            players[stem.id] = player
            files[stem.id] = file
        }

        musicMixer.outputVolume = 1
        musicRouter.outputVolume = 1
        let negotiatedClickFormat = clickNode.outputFormat(forBus: 0)
        guard negotiatedClickFormat.channelCount == 1,
              abs(negotiatedClickFormat.sampleRate - sr) < 0.5 else {
            throw STEMLiveAudioError.invalidClickFormat
        }

        rebuildClickBuffers(song: song)
        engine.prepare()
        try engine.start()

        preparedStemSignature = stemSignature(song)
        preparedOutputMode = song.outputMode

        if song.outputMode == .split {
            try configureMatrixMixer(mode: song.effectiveMonoDownmixMode)
        }
        clickMixer.outputVolume = song.outputMode == .split && song.click.enabled
            ? dbToLinear(song.click.levelDB)
            : 0

        let report = preflight(song: song)
        let srcText = report.srcActive ? "SRC active" : "no SRC"
        publishStatus("CoreAudio · \(Int(sr / 1000)) kHz · \(srcText)")
        DispatchQueue.main.async { [weak self] in
            self?.latestPreflight = report
            self?.preflightGeneration &+= 1
        }
    }

    func reloadIfNeeded(song: SongProject) {
        graphLock.lock()
        defer { graphLock.unlock() }

        let graphChanged =
            activeSong?.id != song.id ||
            preparedStemSignature != stemSignature(song) ||
            preparedOutputMode != song.outputMode

        if graphChanged {
            do {
                try prepare(song: song)
            } catch {
                publishStatus("Audio error · \(error.localizedDescription)")
            }
            return
        }

        activeSong = song
        applyStemState(song)
        rebuildClickBuffers(song: song)
    }

    func changeOutputMode(song: SongProject) throws {
        graphLock.lock()
        defer { graphLock.unlock() }

        guard !transportRunning else {
            throw STEMLiveAudioError.routingChangeWhilePlaying
        }

        try prepare(song: song)
        let mode = song.outputMode == .split ? "Music L / Click R" : "Stereo Music"
        publishStatus("CoreAudio · \(Int(hardwareSampleRate / 1000)) kHz · \(mode)")
    }

    func applyRouting(song: SongProject) throws {
        graphLock.lock()
        defer { graphLock.unlock() }

        guard preparedOutputMode == song.outputMode else {
            throw STEMLiveAudioError.routingChangeWhilePlaying
        }
        activeSong = song

        if song.outputMode == .split {
            try configureMatrixMixer(mode: song.effectiveMonoDownmixMode)
        }

        clickMixer.pan = 1
        clickMixer.outputVolume = song.outputMode == .split && song.click.enabled
            ? dbToLinear(song.click.levelDB)
            : 0

        if transportRunning {
            if song.outputMode == .split && song.click.enabled {
                if clickTimer == nil { startClickScheduler() }
            } else {
                stopClickScheduler()
            }
        }
    }

    func applyStemState(_ song: SongProject) {
        graphLock.lock()
        defer { graphLock.unlock() }

        activeSong = song
        let anySolo = song.stems.contains(where: { $0.solo && $0.effectiveRoute == .music })
        for stem in song.stems where stem.effectiveRoute == .music {
            guard let player = players[stem.id] else { continue }
            let audible = !stem.muted && (!anySolo || stem.solo)
            player.volume = audible ? Float(stem.volume.clamped(0...1.5)) : 0
        }
        rebuildClickBuffers(song: song)
        do {
            try applyRouting(song: song)
        } catch {
            publishStatus("Routing check · \(error.localizedDescription)")
        }
    }

    func play(song: SongProject, from offset: Double? = nil) {
        graphLock.lock()
        defer { graphLock.unlock() }

        RuntimeDiagnostics.mark("PLAY requested · \(song.title) · mode=\(song.outputMode.rawValue)")
        fadeStopWorkItem?.cancel()
        fadeStopWorkItem = nil

        do {
            reloadIfNeeded(song: song)
            if !engine.isRunning {
                RuntimeDiagnostics.mark("PLAY engine.start begin")
                try engine.start()
                RuntimeDiagnostics.mark("PLAY engine.start success")
            }

            let start = max(
                0,
                min(
                    offset ?? pausedPosition,
                    song.duration > 0 ? song.duration : Double.greatestFiniteMagnitude
                )
            )
            try scheduleAll(song: song, offset: start)
        } catch {
            RuntimeDiagnostics.mark("PLAY blocked · \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.engineStatus = "Audio error · \(error.localizedDescription)"
                self.isPlaying = false
            }
        }
    }

    private func scheduleAll(song: SongProject, offset: Double) throws {
        graphLock.lock()
        defer { graphLock.unlock() }
        for player in players.values { player.stop() }
        clickNode.stop()
        musicMixer.outputVolume = 1

        let startHost = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.14)
        let when = AVAudioTime(hostTime: startHost)
        var scheduled = 0

        for stem in song.stems where stem.effectiveRoute == .music {
            guard let player = players[stem.id], let file = files[stem.id] else { continue }
            let rate = file.processingFormat.sampleRate
            guard rate > 0 else { continue }

            let sourceTime = offset + stem.effectiveSourceOffset
            let frame = AVAudioFramePosition((sourceTime * rate).rounded(.down))
            guard frame >= 0, frame < file.length else { continue }

            let remaining = file.length - frame
            guard remaining > 0 else { continue }
            let count = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))
            guard count > 0 else { continue }

            // Queue each file segment at player sample-time zero, then start every
            // player against the same future host clock. This avoids mixing host
            // and player timeline semantics inside scheduleSegment.
            player.scheduleSegment(
                file,
                startingFrame: frame,
                frameCount: count,
                at: nil,
                completionHandler: nil
            )
            scheduled += 1
        }

        guard scheduled > 0 else {
            throw STEMLiveAudioError.noPlayableStems
        }

        RuntimeDiagnostics.mark("PLAY scheduled \(scheduled) music stems")
        for stem in song.stems where stem.effectiveRoute == .music {
            guard let player = players[stem.id], files[stem.id] != nil else { continue }
            player.play(at: when)
        }
        RuntimeDiagnostics.mark("PLAY music players started")
        anchorHost = startHost
        anchorOffset = offset
        pausedPosition = offset
        transportGeneration &+= 1
        transportRunning = true
        loopJumpPending = false
        nextClickIndex = 0
        lastClickSignature = ""
        DispatchQueue.main.async {
            self.currentTime = offset
            self.isPlaying = true
        }
        startTransportTimer()
        startClickScheduler()
        RuntimeDiagnostics.mark("PLAY transport live")
    }

    func pause() {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard transportRunning else { return }
        let t = transportPosition()
        pausedPosition = t
        transportGeneration &+= 1
        transportRunning = false
        cancelGainRamp(resetGain: true)
        for player in players.values { player.pause() }
        clickNode.pause()
        DispatchQueue.main.async {
            self.currentTime = t
            self.isPlaying = false
        }
        stopClickScheduler()
    }

    func resume(song: SongProject) {
        play(song: song, from: pausedPosition)
    }

    func togglePlay(song: SongProject) {
        graphLock.lock()
        let running = transportRunning
        graphLock.unlock()
        running ? pause() : resume(song: song)
    }

    func seek(song: SongProject, to time: Double, smooth: Bool = true) {
        graphLock.lock()
        defer { graphLock.unlock() }
        let target = max(0, min(time, song.duration))
        if !transportRunning {
            pausedPosition = target
            DispatchQueue.main.async { self.currentTime = target }
            return
        }
        if smooth {
            rampMusic(to: 0, duration: 0.055) { [weak self] in
                guard let self else { return }
                do {
                    try self.scheduleAll(song: song, offset: target)
                    self.rampMusic(to: 1, duration: 0.085, completion: nil)
                } catch {
                    self.publishStatus("Seek error · \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try scheduleAll(song: song, offset: target)
            } catch {
                publishStatus("Seek error · \(error.localizedDescription)")
            }
        }
    }

    func fadeOut(seconds: Double = 6.0) {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard transportRunning else { return }

        fadeStopWorkItem?.cancel()
        fadeStopWorkItem = nil

        rampMusic(to: 0, duration: max(1.0, seconds)) { [weak self] in
            guard let self else { return }
            let tail = DispatchWorkItem { [weak self] in
                self?.stop(immediate: true)
            }
            self.graphLock.lock()
            self.fadeStopWorkItem = tail
            self.graphLock.unlock()
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.2, execute: tail)
        }
    }

    func stop(immediate: Bool = false) {
        graphLock.lock()
        defer { graphLock.unlock() }
        let t = immediate ? 0 : transportPosition()
        pausedPosition = t
        transportGeneration &+= 1
        transportRunning = false
        fadeStopWorkItem?.cancel()
        fadeStopWorkItem = nil
        cancelGainRamp(resetGain: immediate)
        for player in players.values { player.stop() }
        clickNode.stop()
        stopClickScheduler()
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = immediate ? 0 : t
            if immediate {
                self.visual = VisualMetrics()
                self.visualSmooth = VisualMetrics()
                self.lastVisualLevel = 0
            }
        }
        if immediate {
            musicMixer.outputVolume = 1
        }
    }

    func setLoopEnabled(_ enabled: Bool) {
        graphLock.lock()
        loopingActive = enabled
        graphLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.loopEnabled = enabled }
    }

    func jumpToSection(_ section: SectionMarker, song: SongProject) {
        graphLock.lock()
        loopSectionID = section.id
        graphLock.unlock()
        seek(song: song, to: section.start, smooth: true)
    }

    func previewClick(song: SongProject) {
        graphLock.lock()
        defer { graphLock.unlock() }
        reloadIfNeeded(song: song)
        guard let buf = accentClickBuffer else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                publishStatus("Click preview error · \(error.localizedDescription)")
                return
            }
        }
        clickMixer.outputVolume = dbToLinear(song.click.levelDB)
        clickNode.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        clickNode.play()
    }

    private func transportPosition() -> Double {
        guard transportRunning, anchorHost > 0 else { return pausedPosition }
        let now = mach_absolute_time()
        guard now >= anchorHost else { return anchorOffset }
        let elapsed = AVAudioTime.seconds(forHostTime: now - anchorHost)
        return anchorOffset + elapsed
    }

    private func startTransportTimer() {
        if transportTimer != nil { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            self.graphLock.lock()
            guard self.transportRunning else {
                self.graphLock.unlock()
                return
            }

            let t = self.transportPosition()
            let song = self.activeSong
            let duration = song?.duration ?? 0
            if let song {
                self.updateVisualFromWaveforms(song: song, time: t)
            }
            let generation = self.transportGeneration
            var loopTarget: Double?

            if self.loopingActive, let song {
                let loopSection = self.loopSectionID.flatMap { id in
                    song.sections.first(where: { $0.id == id })
                } ?? song.sections.last(where: { $0.start <= t })

                if let section = loopSection,
                   section.loopable,
                   section.loopEnd > section.loopStart + 0.001,
                   t >= section.loopEnd - 0.010,
                   !self.loopJumpPending {
                    self.loopJumpPending = true
                    loopTarget = section.loopStart
                }
            }
            self.graphLock.unlock()

            if let loopTarget, let song {
                DispatchQueue.main.async {
                    self.graphLock.lock()
                    let valid = self.transportRunning && self.transportGeneration == generation
                    self.graphLock.unlock()
                    if valid {
                        self.seek(song: song, to: loopTarget, smooth: false)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.graphLock.lock()
                let stillRunning = self.transportRunning && self.transportGeneration == generation
                self.graphLock.unlock()
                if stillRunning {
                    self.currentTime = min(t, duration > 0 ? duration : t)
                    if duration > 0, t >= duration {
                        self.stop(immediate: true)
                    }
                }
            }
        }
        transportTimer = timer
        timer.resume()
    }

    private func startClickScheduler() {
        stopClickScheduler()
        guard let song = activeSong, song.outputMode == .split, song.click.enabled else { return }
        RuntimeDiagnostics.mark("CLICK scheduler start · mono=\(clickNode.outputFormat(forBus: 0).channelCount)ch @ \(clickNode.outputFormat(forBus: 0).sampleRate)")
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(80), leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in self?.scheduleClicksAhead() }
        clickTimer = timer
        timer.resume()
    }

    private func stopClickScheduler() {
        clickTimer?.cancel()
        clickTimer = nil
    }

    private func scheduleClicksAhead() {
        graphLock.lock()
        defer { graphLock.unlock() }

        guard transportRunning,
              let song = activeSong,
              song.outputMode == .split,
              song.click.enabled,
              let normal = normalClickBuffer,
              let accent = accentClickBuffer,
              let sub = subdivisionClickBuffer else { return }

        let output = clickNode.outputFormat(forBus: 0)
        guard output.channelCount == 1,
              output.sampleRate > 0,
              normal.format.channelCount == output.channelCount,
              accent.format.channelCount == output.channelCount,
              sub.format.channelCount == output.channelCount,
              abs(normal.format.sampleRate - output.sampleRate) < 0.5,
              abs(accent.format.sampleRate - output.sampleRate) < 0.5,
              abs(sub.format.sampleRate - output.sampleRate) < 0.5 else {
            publishStatus("Click disabled · CoreAudio click format mismatch")
            stopClickScheduler()
            return
        }

        guard let nodeTime = clickNode.lastRenderTime else { return }

        let bpm = song.click.effectiveBPM(songBPM: song.bpm)
        let quarter = 60.0 / bpm
        let division = song.click.division.stepsPerQuarter
        let step = quarter / Double(division)
        let offset = song.click.offsetMS / 1000
        let swing = song.click.effectiveSwingPercent / 100
        let nowPosition = transportPosition()
        let horizon = nowPosition + 0.70
        let signature = "\(transportGeneration)-\(division)-\(offset)-\(bpm)-\(swing)-\(song.click.effectiveAccentEnabled)"

        if signature != lastClickSignature {
            lastClickSignature = signature
            nextClickIndex = max(0, Int(ceil((nowPosition - offset) / step)))
        }

        let sampleRate = output.sampleRate
        var guardCount = 0
        var scheduledAny = false
        while guardCount < 32 {
            let baseBeatTime = Double(nextClickIndex) * step + offset
            let isOffSubdivision = division > 1 && nextClickIndex % division != 0 && nextClickIndex % 2 == 1
            let swingDelay = isOffSubdivision ? step * swing : 0
            let beatTime = baseBeatTime + swingDelay
            if beatTime > horizon { break }

            let delta = beatTime - nowPosition
            if delta > 0.020 {
                let targetSample = nodeTime.sampleTime + AVAudioFramePosition((delta * sampleRate).rounded())
                let isQuarter = nextClickIndex % division == 0
                let quarterIndex = nextClickIndex / division
                let isAccent = song.click.effectiveAccentEnabled && isQuarter && quarterIndex % max(1, song.meterTop) == 0
                let buffer = isAccent ? accent : (isQuarter ? normal : sub)
                clickNode.scheduleBuffer(
                    buffer,
                    at: AVAudioTime(sampleTime: targetSample, atRate: sampleRate),
                    options: [],
                    completionHandler: nil
                )
                scheduledAny = true
            }

            nextClickIndex += 1
            guardCount += 1
        }

        if scheduledAny && !clickNode.isPlaying {
            clickNode.play()
        }
    }

    private func rebuildClickBuffers(song: SongProject) {
        let nodeFormat = clickNode.outputFormat(forBus: 0)
        let sr = nodeFormat.sampleRate > 0 ? nodeFormat.sampleRate : hardwareSampleRate
        guard nodeFormat.channelCount == 1, sr > 0 else {
            normalClickBuffer = nil
            accentClickBuffer = nil
            subdivisionClickBuffer = nil
            clickMixer.outputVolume = 0
            publishStatus("Click unavailable · mono node format was not negotiated")
            return
        }

        normalClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: false, subdivision: false, accentDB: song.click.accentDB, subdivisionDB: song.click.effectiveSubdivisionLevelDB)
        accentClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: true, subdivision: false, accentDB: song.click.accentDB, subdivisionDB: song.click.effectiveSubdivisionLevelDB)
        subdivisionClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: false, subdivision: true, accentDB: song.click.accentDB, subdivisionDB: song.click.effectiveSubdivisionLevelDB)
        clickMixer.outputVolume = song.outputMode == .split && song.click.enabled ? dbToLinear(song.click.levelDB) : 0
    }

    private func makeClickBuffer(sampleRate: Double, preset: ClickPreset, accent: Bool, subdivision: Bool, accentDB: Double, subdivisionDB: Double) -> AVAudioPCMBuffer? {
        let spec: (freq: Double, accent: Double, duration: Double, harmonic: Double)
        switch preset {
        case .softWood: spec = (720, 920, 0.050, 0.16)
        case .warmPulse: spec = (390, 510, 0.072, 0.08)
        case .studioBlock: spec = (820, 1040, 0.042, 0.20)
        case .deepTick: spec = (290, 390, 0.078, 0.06)
        }
        let freq = (accent ? spec.accent : spec.freq) * (subdivision ? 0.82 : 1.0)
        let dur = spec.duration * (subdivision ? 0.72 : 1.0)
        let accentGain = accent ? min(2.2, pow(10, accentDB / 20)) : 1
        let subdivisionGain = subdivision ? min(1.0, pow(10, subdivisionDB / 20)) : 1
        let frames = AVAudioFrameCount(max(64, Int(sampleRate * dur)))
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let dst = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env = exp(-t * (subdivision ? 78 : 58))
            let fundamental = sin(2 * .pi * freq * t)
            let harmonic = sin(2 * .pi * freq * 1.52 * t) * spec.harmonic
            dst[i] = Float((fundamental + harmonic) * env * (subdivision ? 0.62 : 0.62) * accentGain * subdivisionGain)
        }
        return buffer
    }

    private func updateVisualFromWaveforms(song: SongProject, time: Double) {
        let anySolo = song.stems.contains { $0.effectiveRoute == .music && $0.solo }
        let live = song.stems.filter { stem in
            stem.effectiveRoute == .music &&
            !stem.muted &&
            (!anySolo || stem.solo) &&
            (!stem.waveform.isEmpty || !(stem.visualEnvelope ?? []).isEmpty)
        }
        guard !live.isEmpty, song.duration > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.visual = VisualMetrics()
            }
            return
        }

        var levelPeak = 0.0
        var levelAverage = 0.0
        var bass = 0.0
        var mid = 0.0
        var air = 0.0
        var transient = 0.0
        var contributors = 0

        for stem in live {
            let sourceTime = time + stem.effectiveSourceOffset
            guard sourceTime >= 0, sourceTime <= stem.duration else { continue }
            let normalized = (sourceTime / max(0.001, stem.duration)).clamped(0...1)

            if let envelope = stem.visualEnvelope, !envelope.isEmpty {
                let index = min(envelope.count - 1, max(0, Int(normalized * Double(envelope.count - 1))))
                let sample = envelope[index].metrics
                levelPeak = max(levelPeak, sample.level)
                levelAverage += sample.level
                bass += sample.bass
                mid += sample.mid
                air += sample.air
                transient = max(transient, sample.transient)
            } else if !stem.waveform.isEmpty {
                let index = min(stem.waveform.count - 1, max(0, Int(normalized * Double(stem.waveform.count - 1))))
                let value = Double(stem.waveform[index]).clamped(0...1)
                levelPeak = max(levelPeak, value)
                levelAverage += value
                bass += pow(value, 1.15)
                mid += value
                let delta = max(0, value - lastVisualLevel)
                air += min(1, 0.12 + delta * 3.1)
                transient = max(transient, min(1, delta * 4.8))
            }
            contributors += 1
        }

        guard contributors > 0 else { return }
        let count = Double(contributors)
        let level = (levelPeak * 0.62 + (levelAverage / count) * 0.38).clamped(0...1)
        lastVisualLevel = level

        func approach(_ current: Double, _ target: Double, attack: Double, release: Double) -> Double {
            let tau = target > current ? attack : release
            let dt = 1.0 / 30.0
            let a = 1 - exp(-dt / max(0.001, tau))
            return current + (target - current) * a
        }

        let raw = VisualMetrics(
            level: level,
            bass: (bass / count).clamped(0...1),
            mid: (mid / count).clamped(0...1),
            air: (air / count).clamped(0...1),
            transient: transient.clamped(0...1)
        )

        visualSmooth.level = approach(visualSmooth.level, raw.level, attack: 0.14, release: 1.25)
        visualSmooth.bass = approach(visualSmooth.bass, raw.bass, attack: 0.20, release: 0.94)
        visualSmooth.mid = approach(visualSmooth.mid, raw.mid, attack: 0.18, release: 0.86)
        visualSmooth.air = approach(visualSmooth.air, raw.air, attack: 0.14, release: 0.72)
        visualSmooth.transient = approach(visualSmooth.transient, raw.transient, attack: 0.075, release: 0.40)

        let metrics = visualSmooth
        DispatchQueue.main.async { [weak self] in
            self?.visual = metrics
        }
    }

    private func cancelGainRamp(resetGain: Bool) {
        gainRampGeneration &+= 1
        gainRampTimer?.cancel()
        gainRampTimer = nil
        if resetGain { musicMixer.outputVolume = 1 }
    }

    private func rampMusic(to target: Float, duration: Double, completion: (() -> Void)?) {
        cancelGainRamp(resetGain: false)

        let safeDuration = max(0.01, duration)
        let mixer = musicMixer
        let start = mixer.outputVolume
        let steps = max(2, Int(safeDuration * 90))
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        gainRampTimer = timer
        gainRampGeneration &+= 1
        let generation = gainRampGeneration
        var index = 0

        timer.schedule(deadline: .now(), repeating: safeDuration / Double(steps), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else {
                timer.cancel()
                return
            }

            self.graphLock.lock()
            let valid = self.gainRampGeneration == generation
            self.graphLock.unlock()
            guard valid else {
                timer.cancel()
                return
            }

            index += 1
            let x = min(1, Double(index) / Double(steps))
            let eased = 0.5 - 0.5 * cos(.pi * x)
            mixer.outputVolume = start + (target - start) * Float(eased)

            if index >= steps {
                timer.cancel()
                self.graphLock.lock()
                let stillCurrent = self.gainRampGeneration == generation
                if stillCurrent { self.gainRampTimer = nil }
                self.graphLock.unlock()

                if stillCurrent { completion?() }
            }
        }
        timer.resume()
    }

    private func instantiateMatrixMixer() throws -> AVAudioUnit {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Mixer,
            componentSubType: kAudioUnitSubType_MatrixMixer,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        let semaphore = DispatchSemaphore(value: 0)
        var result: AVAudioUnit?
        var capturedError: Error?
        AVAudioUnit.instantiate(with: description, options: []) { unit, error in
            result = unit
            capturedError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let capturedError { throw capturedError }
        guard let result else {
            throw NSError(domain: "STEMLive.Audio", code: -20, userInfo: [NSLocalizedDescriptionKey: "AUMatrixMixer could not be instantiated."])
        }

        var inputElementCount: UInt32 = 1
        var outputElementCount: UInt32 = 1
        let inputStatus = AudioUnitSetProperty(
            result.audioUnit,
            kAudioUnitProperty_ElementCount,
            kAudioUnitScope_Input,
            0,
            &inputElementCount,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard inputStatus == noErr else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(inputStatus),
                userInfo: [NSLocalizedDescriptionKey: "AUMatrixMixer input topology configuration failed (\(inputStatus))."]
            )
        }

        let outputStatus = AudioUnitSetProperty(
            result.audioUnit,
            kAudioUnitProperty_ElementCount,
            kAudioUnitScope_Output,
            0,
            &outputElementCount,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard outputStatus == noErr else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(outputStatus),
                userInfo: [NSLocalizedDescriptionKey: "AUMatrixMixer output topology configuration failed (\(outputStatus))."]
            )
        }

        return result
    }

    private func configureMatrixMixer(mode: MonoDownmixMode) throws {
        guard let matrix = monoMatrix else { return }
        let unit = matrix.audioUnit

        func set(_ scope: AudioUnitScope, _ element: AudioUnitElement, _ value: Float) throws {
            let status = AudioUnitSetParameter(unit, kMatrixMixerParam_Volume, scope, element, value, 0)
            guard status == noErr else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "AUMatrixMixer parameter configuration failed (\(status))."]
                )
            }
        }

        // Global, per-input and per-output gain are held at unity. The four
        // crosspoints below do all channel routing and mono summing.
        try set(kAudioUnitScope_Global, 0xFFFF_FFFF, 1)
        try set(kAudioUnitScope_Input, 0, 1)
        try set(kAudioUnitScope_Input, 1, 1)
        try set(kAudioUnitScope_Output, 0, 1)
        try set(kAudioUnitScope_Output, 1, 1)

        let lToL = AudioUnitElement((UInt32(0) << 16) | UInt32(0))
        let lToR = AudioUnitElement((UInt32(0) << 16) | UInt32(1))
        let rToL = AudioUnitElement((UInt32(1) << 16) | UInt32(0))
        let rToR = AudioUnitElement((UInt32(1) << 16) | UInt32(1))

        let left: Float
        let right: Float
        switch mode {
        case .safeSum:
            left = 0.5
            right = 0.5
        case .equalPower:
            left = 0.70710678
            right = 0.70710678
        case .leftOnly:
            left = 1
            right = 0
        case .rightOnly:
            left = 0
            right = 1
        }

        // Split mode only: program music is summed explicitly into LEFT.
        try set(kAudioUnitScope_Global, lToL, left)
        try set(kAudioUnitScope_Global, rToL, right)
        try set(kAudioUnitScope_Global, lToR, 0)
        try set(kAudioUnitScope_Global, rToR, 0)
    }

    private func stemSignature(_ song: SongProject) -> String {
        song.stems
            .map { "\($0.id.uuidString)|\($0.path)|\($0.effectiveRoute.rawValue)" }
            .joined(separator: "¦")
    }

    private func publishStatus(_ value: String) {
        DispatchQueue.main.async { [weak self] in
            self?.engineStatus = value
        }
    }

    private func scheduleConfigurationRecovery() {
        graphLock.lock()
        if isRecoveringConfiguration {
            graphLock.unlock()
            return
        }
        let song = activeSong
        let wasPlaying = transportRunning
        let resumeTime = transportPosition()
        graphLock.unlock()

        guard let song else { return }
        recoveryWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recoverConfiguration(song: song, wasPlaying: wasPlaying, resumeTime: resumeTime)
        }
        recoveryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: item)
    }

    private func recoverConfiguration(song: SongProject, wasPlaying: Bool, resumeTime: Double) {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard !isRecoveringConfiguration else { return }
        guard activeSong?.id == song.id else { return }
        isRecoveringConfiguration = true
        defer { isRecoveringConfiguration = false }

        publishStatus("CoreAudio · recovering output…")
        do {
            try prepare(song: song)
            if wasPlaying {
                play(song: song, from: min(resumeTime, song.duration))
            }
        } catch {
            publishStatus("Audio recovery error · \(error.localizedDescription)")
        }
    }

    private func teardownEngine() {
        fadeStopWorkItem?.cancel(); fadeStopWorkItem = nil
        gainRampGeneration &+= 1
        gainRampTimer?.cancel(); gainRampTimer = nil
        transportTimer?.cancel(); transportTimer = nil
        clickTimer?.cancel(); clickTimer = nil
        if engine.isRunning { engine.stop() }
        for player in players.values { player.stop() }
        players.removeAll(); files.removeAll()
        monoMatrix = nil
        preparedOutputMode = nil
    }

    private func dbToLinear(_ db: Double) -> Float {
        Float(pow(10, db / 20))
    }
}
