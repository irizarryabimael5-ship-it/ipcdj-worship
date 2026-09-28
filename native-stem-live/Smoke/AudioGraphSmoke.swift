import Foundation
import AVFoundation
import AudioToolbox

enum SmokeFailure: Error, CustomStringConvertible {
    case format
    case render(String)
    case matrix(OSStatus)

    var description: String {
        switch self {
        case .format: return "invalid audio format"
        case let .render(value): return value
        case let .matrix(status): return "matrix OSStatus \(status)"
        }
    }
}

enum SmokeDownmix {
    case stereo
    case safeSum
    case equalPower
    case leftOnly
    case rightOnly
}

struct RenderMetrics {
    var leftRMS: Double
    var rightRMS: Double
    var leftPeak: Double
    var rightPeak: Double
}

func makeTempWav(name: String, leftFrequency: Double, rightFrequency: Double, leftAmplitude: Double = 0.10, rightAmplitude: Double = 0.05) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(name)-\(UUID().uuidString).wav")
    let sampleRate = 48_000.0
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000) else {
        throw SmokeFailure.format
    }

    buffer.frameLength = 48_000
    guard let left = buffer.floatChannelData?[0],
          let right = buffer.floatChannelData?[1] else {
        throw SmokeFailure.format
    }

    for frame in 0..<Int(buffer.frameLength) {
        let t = Double(frame) / sampleRate
        left[frame] = Float(sin(2.0 * .pi * leftFrequency * t) * leftAmplitude)
        right[frame] = Float(sin(2.0 * .pi * rightFrequency * t) * rightAmplitude)
    }

    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    return url
}

func instantiateMatrix() throws -> AVAudioUnit {
    let desc = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MatrixMixer,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    let sem = DispatchSemaphore(value: 0)
    var unit: AVAudioUnit?
    var error: Error?
    AVAudioUnit.instantiate(with: desc, options: []) { value, err in
        unit = value
        error = err
        sem.signal()
    }
    sem.wait()
    if let error { throw error }
    guard let unit else { throw SmokeFailure.format }

    var inputs: UInt32 = 1
    var outputs: UInt32 = 1
    var status = AudioUnitSetProperty(
        unit.audioUnit,
        kAudioUnitProperty_ElementCount,
        kAudioUnitScope_Input,
        0,
        &inputs,
        UInt32(MemoryLayout<UInt32>.size)
    )
    guard status == noErr else { throw SmokeFailure.matrix(status) }

    status = AudioUnitSetProperty(
        unit.audioUnit,
        kAudioUnitProperty_ElementCount,
        kAudioUnitScope_Output,
        0,
        &outputs,
        UInt32(MemoryLayout<UInt32>.size)
    )
    guard status == noErr else { throw SmokeFailure.matrix(status) }
    return unit
}

func setMatrix(_ unit: AVAudioUnit, _ scope: AudioUnitScope, _ element: AudioUnitElement, _ value: Float) throws {
    let status = AudioUnitSetParameter(unit.audioUnit, kMatrixMixerParam_Volume, scope, element, value, 0)
    guard status == noErr else { throw SmokeFailure.matrix(status) }
}

func configureSplit(_ matrix: AVAudioUnit, mode: SmokeDownmix) throws {
    try setMatrix(matrix, kAudioUnitScope_Global, 0xFFFF_FFFF, 1)
    try setMatrix(matrix, kAudioUnitScope_Input, 0, 1)
    try setMatrix(matrix, kAudioUnitScope_Input, 1, 1)
    try setMatrix(matrix, kAudioUnitScope_Output, 0, 1)
    try setMatrix(matrix, kAudioUnitScope_Output, 1, 1)

    let lToL = AudioUnitElement((UInt32(0) << 16) | UInt32(0))
    let lToR = AudioUnitElement((UInt32(0) << 16) | UInt32(1))
    let rToL = AudioUnitElement((UInt32(1) << 16) | UInt32(0))
    let rToR = AudioUnitElement((UInt32(1) << 16) | UInt32(1))

    let left: Float
    let right: Float
    switch mode {
    case .safeSum:
        left = 0.5; right = 0.5
    case .equalPower:
        left = 0.70710678; right = 0.70710678
    case .leftOnly:
        left = 1; right = 0
    case .rightOnly:
        left = 0; right = 1
    case .stereo:
        left = 1; right = 1
    }

    try setMatrix(matrix, kAudioUnitScope_Global, lToL, left)
    try setMatrix(matrix, kAudioUnitScope_Global, rToL, right)
    try setMatrix(matrix, kAudioUnitScope_Global, lToR, 0)
    try setMatrix(matrix, kAudioUnitScope_Global, rToR, 0)
}

func makeClick(format: AVAudioFormat) throws -> AVAudioPCMBuffer {
    guard format.channelCount == 1,
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_440),
          let dst = buffer.floatChannelData?[0] else {
        throw SmokeFailure.format
    }
    buffer.frameLength = 1_440
    for i in 0..<Int(buffer.frameLength) {
        let t = Double(i) / format.sampleRate
        dst[i] = Float(sin(2 * .pi * 880 * t) * exp(-t * 65) * 0.4)
    }
    return buffer
}

func render(mode: SmokeDownmix, files: [URL], includeClick: Bool = false) throws -> RenderMetrics {
    let split = mode != .stereo
    let engine = AVAudioEngine()
    let musicMixer = AVAudioMixerNode()
    let router = AVAudioMixerNode()
    let clickMixer = AVAudioMixerNode()
    let clickNode = AVAudioPlayerNode()

    engine.attach(musicMixer)
    engine.attach(router)
    engine.attach(clickMixer)
    engine.attach(clickNode)

    guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
          let clickFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1) else {
        throw SmokeFailure.format
    }

    var matrix: AVAudioUnit?
    if split {
        let unit = try instantiateMatrix()
        matrix = unit
        engine.attach(unit)
        engine.connect(musicMixer, to: unit, format: format)
        engine.connect(unit, to: router, format: format)
    } else {
        // Must mirror the production 0.6.6 dry path: no always-inline effect.
        engine.connect(musicMixer, to: router, format: format)
    }
    engine.connect(router, to: engine.mainMixerNode, format: format)

    // Production invariant: generated click is explicitly mono before any buffer
    // can be scheduled.
    engine.connect(clickNode, to: clickMixer, format: clickFormat)
    engine.connect(clickMixer, to: engine.mainMixerNode, format: nil)
    clickMixer.pan = 1
    clickMixer.outputVolume = split && includeClick ? 0.35 : 0

    var players: [AVAudioPlayerNode] = []
    var audioFiles: [AVAudioFile] = []
    for url in files {
        let file = try AVAudioFile(forReading: url)
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: musicMixer, format: file.processingFormat)
        players.append(player)
        audioFiles.append(file)
    }

    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    engine.prepare()
    try engine.start()

    if let matrix {
        try configureSplit(matrix, mode: mode)
    }

    for (player, file) in zip(players, audioFiles) {
        player.scheduleSegment(
            file,
            startingFrame: 0,
            frameCount: AVAudioFrameCount(file.length),
            at: nil,
            completionHandler: nil
        )
        player.play()
    }

    if includeClick {
        let click = try makeClick(format: clickFormat)
        guard clickNode.outputFormat(forBus: 0).channelCount == click.format.channelCount,
              abs(clickNode.outputFormat(forBus: 0).sampleRate - click.format.sampleRate) < 0.5 else {
            throw SmokeFailure.render("generated mono click format mismatch")
        }
        clickNode.scheduleBuffer(click, at: nil, options: [], completionHandler: nil)
        clickNode.play()
    }

    guard let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512) else {
        throw SmokeFailure.format
    }

    var rendered: AVAudioFramePosition = 0
    let target: AVAudioFramePosition = 24_000
    var retries = 0
    var leftSquares = 0.0
    var rightSquares = 0.0
    var samples = 0
    var leftPeak = 0.0
    var rightPeak = 0.0

    while rendered < target {
        let frames = AVAudioFrameCount(min(512, target - rendered))
        let status = try engine.renderOffline(frames, to: output)
        switch status {
        case .success:
            guard let left = output.floatChannelData?[0],
                  let right = output.floatChannelData?[1] else {
                throw SmokeFailure.format
            }
            for i in 0..<Int(output.frameLength) {
                let l = Double(left[i])
                let r = Double(right[i])
                leftSquares += l * l
                rightSquares += r * r
                leftPeak = max(leftPeak, abs(l))
                rightPeak = max(rightPeak, abs(r))
            }
            samples += Int(output.frameLength)
            rendered += AVAudioFramePosition(output.frameLength)
            retries = 0
        case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
            retries += 1
            if retries > 100 { throw SmokeFailure.render("offline render stalled") }
        case .error:
            throw SmokeFailure.render("offline render returned error")
        @unknown default:
            throw SmokeFailure.render("unknown render status")
        }
    }

    for player in players { player.stop() }
    clickNode.stop()
    engine.stop()
    engine.disableManualRenderingMode()

    guard samples > 0 else { throw SmokeFailure.render("no rendered samples") }
    return RenderMetrics(
        leftRMS: sqrt(leftSquares / Double(samples)),
        rightRMS: sqrt(rightSquares / Double(samples)),
        leftPeak: leftPeak,
        rightPeak: rightPeak
    )
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SmokeFailure.render(message) }
}

do {
    let files = [
        try makeTempWav(name: "smoke-a", leftFrequency: 220, rightFrequency: 330),
        try makeTempWav(name: "smoke-b", leftFrequency: 440, rightFrequency: 550, leftAmplitude: 0.05, rightAmplitude: 0.025),
        try makeTempWav(name: "smoke-c", leftFrequency: 660, rightFrequency: 770, leftAmplitude: 0.025, rightAmplitude: 0.0125)
    ]
    defer { for url in files { try? FileManager.default.removeItem(at: url) } }

    let direct = try render(mode: .stereo, files: files)
    try require(direct.leftRMS > 0.01 && direct.rightRMS > 0.005, "DIRECT-STEREO lost a program channel")
    print("PASS DIRECT-STEREO · L \(direct.leftRMS) · R \(direct.rightRMS)")

    let safe = try render(mode: .safeSum, files: files)
    try require(safe.leftRMS > 0.005, "SAFE-SUM produced no program LEFT")
    try require(safe.rightPeak < 0.000_5, "SAFE-SUM leaked program audio to RIGHT: \(safe.rightPeak)")
    print("PASS SAFE-SUM · program LEFT only")

    let leftOnly = try render(mode: .leftOnly, files: files)
    let rightOnly = try render(mode: .rightOnly, files: files)
    try require(leftOnly.leftRMS > rightOnly.leftRMS * 1.45, "LEFT/RIGHT-only matrix coefficients do not reflect asymmetric source")
    try require(leftOnly.rightPeak < 0.000_5 && rightOnly.rightPeak < 0.000_5, "program leaked to RIGHT in split mode")
    print("PASS LEFT/RIGHT-ONLY · matrix isolation verified")

    let equal = try render(mode: .equalPower, files: files)
    try require(equal.leftRMS > safe.leftRMS * 1.30, "EQUAL-POWER is not measurably above SAFE-SUM")
    try require(equal.rightPeak < 0.000_5, "EQUAL-POWER leaked program to RIGHT")
    print("PASS EQUAL-POWER · coefficient behavior verified")

    let splitClick = try render(mode: .safeSum, files: files, includeClick: true)
    try require(splitClick.rightPeak > 0.01, "generated click did not reach RIGHT")
    try require(splitClick.leftRMS > 0.005, "program music disappeared when click was active")
    print("PASS SPLIT CLICK · mono click scheduled and routed RIGHT")

    print("STEM LIVE AUDIO SMOKE TEST PASSED")
} catch {
    fputs("STEM LIVE AUDIO SMOKE TEST FAILED: \(error)\n", stderr)
    exit(1)
}
