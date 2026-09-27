import Foundation
import AVFoundation
import Accelerate
import AudioToolbox
import Darwin

enum STEMLiveAudioError: LocalizedError {
    case outputUnavailable
    case invalidStereoFormat
    case splitRequiresStereoOutput(Int)

    var errorDescription: String? {
        switch self {
        case .outputUnavailable:
            return "The selected CoreAudio output is not currently available."
        case .invalidStereoFormat:
            return "STEM Live could not create the required stereo processing format."
        case let .splitRequiresStereoOutput(channels):
            return "Music L / Click R requires at least 2 output channels. The current device reports \(channels)."
        }
    }
}

final class AudioEngineController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var visual = VisualMetrics()
    @Published private(set) var engineStatus = "Audio idle"
    @Published private(set) var preflightGeneration = 0
    @Published private(set) var latestPreflight: AudioPreflightReport?
    @Published private(set) var loopEnabled = false

    private var engine = AVAudioEngine()
    private var musicMixer = AVAudioMixerNode()
    private var reverb = AVAudioUnitReverb()
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

    private var visualLow: Float = 0
    private var visualPrev: Float = 0
    private var visualLastPublish: CFAbsoluteTime = 0
    private var visualPeak: Double = 0.08
    private var visualSmooth = VisualMetrics()

    private let graphLock = NSRecursiveLock()
    private var gainRampTimer: DispatchSourceTimer?
    private var gainRampGeneration = 0
    private var fadeStopWorkItem: DispatchWorkItem?
    private var configObserver: NSObjectProtocol?
    private var recoveryWorkItem: DispatchWorkItem?
    private var isRecoveringConfiguration = false
    private var preparedStemSignature = ""
    private var loopSectionID: UUID?
    private var loopJumpPending = false
    private var loopingActive = false
    private var transportRunning = false
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
        reverb = AVAudioUnitReverb()
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

        engine.attach(musicMixer)
        engine.attach(reverb)
        engine.attach(musicRouter)
        engine.attach(clickMixer)
        engine.attach(clickNode)

        let matrix = try instantiateMatrixMixer()
        monoMatrix = matrix
        engine.attach(matrix)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 0

        // One stable 2-in / 2-out music topology is used for BOTH stereo and split routing.
        // Output mode changes only alter matrix coefficients; the live graph is never torn down.
        engine.connect(musicMixer, to: reverb, format: stereo)
        engine.connect(reverb, to: matrix, format: stereo)
        engine.connect(matrix, to: musicRouter, format: stereo)
        engine.connect(musicRouter, to: engine.mainMixerNode, format: nil)
        musicRouter.pan = 0

        engine.connect(clickNode, to: clickMixer, format: nil)
        engine.connect(clickMixer, to: engine.mainMixerNode, format: nil)
        clickMixer.pan = 1

        for stem in song.stems where stem.effectiveRoute == .music {
            let url = URL(fileURLWithPath: stem.path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: musicMixer, format: file.processingFormat)
            player.volume = stem.muted ? 0 : Float(stem.volume.clamped(0...1.5))
            players[stem.id] = player
            files[stem.id] = file
        }

        musicMixer.outputVolume = 1
        musicRouter.outputVolume = 1
        installVisualTap()
        rebuildClickBuffers(song: song)
        engine.prepare()
        try engine.start()

        preparedStemSignature = stemSignature(song)
        try applyRoutingLocked(song)

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

        let graphChanged = activeSong?.id != song.id || preparedStemSignature != stemSignature(song)
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

    func applyRouting(song: SongProject) throws {
        graphLock.lock()
        defer { graphLock.unlock() }
        activeSong = song
        try applyRoutingLocked(song)
        let mode = song.outputMode == .split ? "Music L / Click R" : "Stereo Music"
        publishStatus("CoreAudio · \(Int(hardwareSampleRate / 1000)) kHz · \(mode)")
    }

    private func applyRoutingLocked(_ song: SongProject) throws {
        if song.outputMode == .split, outputChannelCount < 2 {
            throw STEMLiveAudioError.splitRequiresStereoOutput(outputChannelCount)
        }

        try configureMatrixMixer(mode: song.outputMode == .split ? song.effectiveMonoDownmixMode : nil)
        clickMixer.pan = 1
        clickMixer.outputVolume = song.outputMode == .split && song.click.enabled
            ? dbToLinear(song.click.levelDB)
            : 0
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
            try applyRoutingLocked(song)
        } catch {
            publishStatus("Routing check · \(error.localizedDescription)")
        }
    }

    func play(song: SongProject, from offset: Double? = nil) {
        graphLock.lock()
        defer { graphLock.unlock() }
        fadeStopWorkItem?.cancel()
        fadeStopWorkItem = nil
        do {
            reloadIfNeeded(song: song)
            if !engine.isRunning { try engine.start() }
        } catch {
            DispatchQueue.main.async { self.engineStatus = "Audio error · \(error.localizedDescription)" }
            return
        }
        let start = max(0, min(offset ?? pausedPosition, song.duration > 0 ? song.duration : Double.greatestFiniteMagnitude))
        scheduleAll(song: song, offset: start)
    }

    private func scheduleAll(song: SongProject, offset: Double) {
        graphLock.lock()
        defer { graphLock.unlock() }
        for player in players.values { player.stop() }
        clickNode.stop()
        musicMixer.outputVolume = 1
        reverb.wetDryMix = 0

        let startHost = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.11)
        let when = AVAudioTime(hostTime: startHost)
        var scheduled = 0
        for stem in song.stems where stem.effectiveRoute == .music {
            guard let player = players[stem.id], let file = files[stem.id] else { continue }
            let rate = file.processingFormat.sampleRate
            let frame = AVAudioFramePosition(offset * rate)
            guard frame < file.length else { continue }
            let remaining = file.length - frame
            let count = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))
            player.scheduleSegment(file, startingFrame: frame, frameCount: count, at: when, completionHandler: nil)
            player.play(at: when)
            scheduled += 1
        }
        guard scheduled > 0 else { return }

        anchorHost = startHost
        anchorOffset = offset
        pausedPosition = offset
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
    }

    func pause() {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard transportRunning else { return }
        let t = transportPosition()
        pausedPosition = t
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
        isPlaying ? pause() : resume(song: song)
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
                self.scheduleAll(song: song, offset: target)
                self.rampMusic(to: 1, duration: 0.085, completion: nil)
            }
        } else {
            scheduleAll(song: song, offset: target)
        }
    }

    func fadeOut(seconds: Double = 6.0) {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard transportRunning else { return }

        fadeStopWorkItem?.cancel()
        fadeStopWorkItem = nil
        reverb.wetDryMix = 12

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
            if immediate { self.visual = VisualMetrics() }
        }
        if immediate {
            musicMixer.outputVolume = 1
            reverb.wetDryMix = 0
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
                    self.seek(song: song, to: loopTarget, smooth: false)
                }
                return
            }

            DispatchQueue.main.async {
                if self.isPlaying {
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
        guard transportRunning, let song = activeSong, song.outputMode == .split, song.click.enabled,
              let normal = normalClickBuffer, let accent = accentClickBuffer, let sub = subdivisionClickBuffer else { return }
        let bpm = max(30, song.bpm)
        let quarter = 60.0 / bpm
        let div = song.click.sixteenths ? 4 : (song.click.eighths ? 2 : 1)
        let step = quarter / Double(div)
        let offset = song.click.offsetMS / 1000
        let nowHost = mach_absolute_time()
        let horizonHost = nowHost + AVAudioTime.hostTime(forSeconds: 0.9)
        let signature = "\(anchorHost)-\(div)-\(offset)-\(song.bpm)"
        if signature != lastClickSignature {
            lastClickSignature = signature
            let nowPos = max(0, transportPosition() - offset)
            nextClickIndex = max(0, Int(ceil(nowPos / step)))
        }

        var guardCount = 0
        while guardCount < 32 {
            let beatTime = Double(nextClickIndex) * step + offset
            let delta = beatTime - anchorOffset
            let host = anchorHost + AVAudioTime.hostTime(forSeconds: delta)
            if host > horizonHost { break }
            if host > nowHost + AVAudioTime.hostTime(forSeconds: 0.012) {
                let isQuarter = nextClickIndex % div == 0
                let quarterIndex = nextClickIndex / div
                let isAccent = isQuarter && quarterIndex % max(1, song.meterTop) == 0
                let buffer = isAccent ? accent : (isQuarter ? normal : sub)
                clickNode.scheduleBuffer(buffer, at: AVAudioTime(hostTime: host), options: [], completionHandler: nil)
                if !clickNode.isPlaying { clickNode.play() }
            }
            nextClickIndex += 1
            guardCount += 1
        }
    }

    private func rebuildClickBuffers(song: SongProject) {
        let sr = hardwareSampleRate
        normalClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: false, subdivision: false, accentDB: song.click.accentDB)
        accentClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: true, subdivision: false, accentDB: song.click.accentDB)
        subdivisionClickBuffer = makeClickBuffer(sampleRate: sr, preset: song.click.preset, accent: false, subdivision: true, accentDB: song.click.accentDB)
        clickMixer.outputVolume = song.outputMode == .split && song.click.enabled ? dbToLinear(song.click.levelDB) : 0
    }

    private func makeClickBuffer(sampleRate: Double, preset: ClickPreset, accent: Bool, subdivision: Bool, accentDB: Double) -> AVAudioPCMBuffer? {
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
            dst[i] = Float((fundamental + harmonic) * env * (subdivision ? 0.38 : 0.62) * accentGain)
        }
        return buffer
    }

    private func installVisualTap() {
        reverb.removeTap(onBus: 0)
        reverb.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.consumeVisualBuffer(buffer)
        }
    }

    private func consumeVisualBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let ptr = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 8 else { return }

        var sum: Double = 0
        var lowSum: Double = 0
        var highSum: Double = 0
        var fluxSum: Double = 0
        var low = visualLow
        var prev = visualPrev
        let alpha: Float = 0.055

        var i = 0
        while i < n {
            let x = ptr[i]
            low += alpha * (x - low)
            let high = x - prev
            let flux = max(0, abs(x) - abs(prev))
            sum += Double(x * x)
            lowSum += Double(low * low)
            highSum += Double(high * high)
            fluxSum += Double(flux)
            prev = x
            i += 2
        }
        visualLow = low
        visualPrev = prev
        let count = Double(max(1, n / 2))
        let rms = sqrt(sum / count)
        let lowRMS = sqrt(lowSum / count)
        let highRMS = sqrt(highSum / count)
        visualPeak = max(rms, visualPeak * 0.996)
        let level = (rms / max(0.04, visualPeak * 0.94)).clamped(0...1)
        let bass = (lowRMS / max(0.0001, rms)).clamped(0...1)
        let air = (highRMS / max(0.0001, rms * 1.7)).clamped(0...1)
        let mid = max(0, 1 - bass * 0.72 - air * 0.52).clamped(0...1)
        let transient = (fluxSum / count * 18).clamped(0...1)

        let now = CFAbsoluteTimeGetCurrent()
        guard now - visualLastPublish >= 0.05 else { return }
        visualLastPublish = now
        let raw = VisualMetrics(level: level, bass: bass, mid: mid, air: air, transient: transient)
        func approach(_ current: Double, _ target: Double, attack: Double, release: Double) -> Double {
            let tau = target > current ? attack : release
            let dt = 0.05
            let a = 1 - exp(-dt / max(0.001, tau))
            return current + (target - current) * a
        }
        visualSmooth.level = approach(visualSmooth.level, raw.level, attack: 0.28, release: 1.90)
        visualSmooth.bass = approach(visualSmooth.bass, raw.bass, attack: 0.34, release: 1.15)
        visualSmooth.mid = approach(visualSmooth.mid, raw.mid, attack: 0.34, release: 1.15)
        visualSmooth.air = approach(visualSmooth.air, raw.air, attack: 0.30, release: 1.00)
        visualSmooth.transient = approach(visualSmooth.transient, raw.transient, attack: 0.16, release: 0.72)
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
        return result
    }

    private func configureMatrixMixer(mode: MonoDownmixMode?) throws {
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

        if let mode {
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

            // Split mode: program music is summed explicitly into LEFT only.
            try set(kAudioUnitScope_Global, lToL, left)
            try set(kAudioUnitScope_Global, rToL, right)
            try set(kAudioUnitScope_Global, lToR, 0)
            try set(kAudioUnitScope_Global, rToR, 0)
        } else {
            // Stereo mode: mathematically transparent 1:1 passthrough.
            try set(kAudioUnitScope_Global, lToL, 1)
            try set(kAudioUnitScope_Global, lToR, 0)
            try set(kAudioUnitScope_Global, rToL, 0)
            try set(kAudioUnitScope_Global, rToR, 1)
        }
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
    }

    private func dbToLinear(_ db: Double) -> Float {
        Float(pow(10, db / 20))
    }
}
