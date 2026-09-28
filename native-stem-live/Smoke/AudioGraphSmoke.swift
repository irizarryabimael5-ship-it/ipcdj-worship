import Foundation
import AVFoundation
import AudioToolbox

enum SmokeFailure: Error {
    case format
    case render(String)
    case matrix(OSStatus)
}

func makeTempWav(name: String, frequency: Double) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(name)-\(UUID().uuidString).wav")
    let sampleRate = 48_000.0
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000) else {
        throw SmokeFailure.format
    }

    buffer.frameLength = 48_000
    for ch in 0..<2 {
        guard let data = buffer.floatChannelData?[ch] else { throw SmokeFailure.format }
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / sampleRate
            data[frame] = Float(sin(2.0 * .pi * frequency * t) * 0.12)
        }
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

func configureSplit(_ matrix: AVAudioUnit) throws {
    try setMatrix(matrix, kAudioUnitScope_Global, 0xFFFF_FFFF, 1)
    try setMatrix(matrix, kAudioUnitScope_Input, 0, 1)
    try setMatrix(matrix, kAudioUnitScope_Input, 1, 1)
    try setMatrix(matrix, kAudioUnitScope_Output, 0, 1)
    try setMatrix(matrix, kAudioUnitScope_Output, 1, 1)

    let lToL = AudioUnitElement((UInt32(0) << 16) | UInt32(0))
    let lToR = AudioUnitElement((UInt32(0) << 16) | UInt32(1))
    let rToL = AudioUnitElement((UInt32(1) << 16) | UInt32(0))
    let rToR = AudioUnitElement((UInt32(1) << 16) | UInt32(1))

    try setMatrix(matrix, kAudioUnitScope_Global, lToL, 0.5)
    try setMatrix(matrix, kAudioUnitScope_Global, rToL, 0.5)
    try setMatrix(matrix, kAudioUnitScope_Global, lToR, 0)
    try setMatrix(matrix, kAudioUnitScope_Global, rToR, 0)
}

func render(mode: String, split: Bool, files: [URL]) throws {
    let engine = AVAudioEngine()
    let mixer = AVAudioMixerNode()
    let reverb = AVAudioUnitReverb()
    let router = AVAudioMixerNode()
    let clickMixer = AVAudioMixerNode()
    let clickNode = AVAudioPlayerNode()
    engine.attach(mixer)
    engine.attach(reverb)
    engine.attach(router)
    engine.attach(clickMixer)
    engine.attach(clickNode)

    let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    engine.connect(mixer, to: reverb, format: format)

    var matrix: AVAudioUnit?
    if split {
        let m = try instantiateMatrix()
        matrix = m
        engine.attach(m)
        engine.connect(reverb, to: m, format: format)
        engine.connect(m, to: router, format: format)
    } else {
        engine.connect(reverb, to: router, format: format)
    }

    engine.connect(router, to: engine.mainMixerNode, format: format)

    guard let clickFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1) else {
        throw SmokeFailure.format
    }
    engine.connect(clickNode, to: clickMixer, format: clickFormat)
    engine.connect(clickMixer, to: engine.mainMixerNode, format: nil)
    clickMixer.pan = 1
    clickMixer.outputVolume = split ? 0.35 : 0

    var players: [AVAudioPlayerNode] = []
    var audioFiles: [AVAudioFile] = []
    for url in files {
        let f = try AVAudioFile(forReading: url)
        let p = AVAudioPlayerNode()
        engine.attach(p)
        engine.connect(p, to: mixer, format: f.processingFormat)
        players.append(p)
        audioFiles.append(f)
    }

    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
    engine.prepare()
    try engine.start()

    if let matrix { try configureSplit(matrix) }

    for (p, f) in zip(players, audioFiles) {
        p.scheduleSegment(
            f,
            startingFrame: 0,
            frameCount: AVAudioFrameCount(f.length),
            at: nil,
            completionHandler: nil
        )
        p.play()
    }

    if split {
        guard let click = AVAudioPCMBuffer(pcmFormat: clickFormat, frameCapacity: 480) else {
            throw SmokeFailure.format
        }
        click.frameLength = 480
        guard let dst = click.floatChannelData?[0] else { throw SmokeFailure.format }
        for i in 0..<Int(click.frameLength) {
            let t = Double(i) / 48_000.0
            dst[i] = Float(sin(2 * .pi * 880 * t) * exp(-t * 65) * 0.4)
        }

        guard clickNode.outputFormat(forBus: 0).channelCount == click.format.channelCount else {
            throw SmokeFailure.render("split click channel mismatch")
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
    while rendered < target {
        let frames = AVAudioFrameCount(min(512, target - rendered))
        let status = try engine.renderOffline(frames, to: output)
        switch status {
        case .success:
            rendered += AVAudioFramePosition(output.frameLength)
            retries = 0
        case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
            retries += 1
            if retries > 100 { throw SmokeFailure.render("\(mode): render stalled") }
        case .error:
            throw SmokeFailure.render("\(mode): offline render returned error")
        @unknown default:
            throw SmokeFailure.render("\(mode): unknown render status")
        }
    }

    for p in players { p.stop() }
    engine.stop()
    engine.disableManualRenderingMode()
    print("PASS \(mode): rendered \(rendered) frames from \(players.count) synchronized stems")
}

do {
    let files = [
        try makeTempWav(name: "smoke-a", frequency: 220),
        try makeTempWav(name: "smoke-b", frequency: 330),
        try makeTempWav(name: "smoke-c", frequency: 440)
    ]
    defer { for url in files { try? FileManager.default.removeItem(at: url) } }

    try render(mode: "DIRECT-STEREO", split: false, files: files)
    try render(mode: "SPLIT-MATRIX", split: true, files: files)
    print("STEM LIVE AUDIO SMOKE TEST PASSED")
} catch {
    fputs("STEM LIVE AUDIO SMOKE TEST FAILED: \(error)\n", stderr)
    exit(1)
}
