import Foundation
import AVFoundation

struct WaveformBuilder {
    /// Offline import analysis only. Nothing here runs on the CoreAudio render thread.
    /// The 0.6.6 visual envelope stores broad-band RMS, three coarse spectral-energy
    /// bands and transient energy so Living Color can react to actual musical shape
    /// without installing an AVAudioEngine tap.
    static func inspect(url: URL) throws -> (duration: Double, waveform: [Float], visual: [VisualAnalysisSample]) {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        let duration = rate > 0 ? Double(file.length) / rate : 0
        let waveformBins = max(900, min(3600, Int(duration * 10)))
        let visualBins = max(600, min(12_000, Int(duration * 20)))
        let analysis = try buildAnalysis(file: file, waveformBins: waveformBins, visualBins: visualBins)
        return (duration, analysis.waveform, analysis.visual)
    }

    private static func buildAnalysis(
        file: AVAudioFile,
        waveformBins: Int,
        visualBins: Int
    ) throws -> (waveform: [Float], visual: [VisualAnalysisSample]) {
        guard waveformBins > 0, visualBins > 0, file.length > 0 else { return ([], []) }
        let channels = Int(file.processingFormat.channelCount)
        let sampleRate = max(1, file.processingFormat.sampleRate)
        let totalFrames = Int64(file.length)
        let waveformFramesPerBin = max<Int64>(1, totalFrames / Int64(waveformBins))
        let visualFramesPerBin = max<Int64>(1, totalFrames / Int64(visualBins))
        let capacity: AVAudioFrameCount = 16_384

        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            return ([], [])
        }

        var peaks = Array(repeating: Float(0), count: waveformBins)
        var rmsSum = Array(repeating: Double(0), count: visualBins)
        var bassSum = Array(repeating: Double(0), count: visualBins)
        var midSum = Array(repeating: Double(0), count: visualBins)
        var airSum = Array(repeating: Double(0), count: visualBins)
        var transientPeak = Array(repeating: Double(0), count: visualBins)
        var visualCounts = Array(repeating: Int(0), count: visualBins)

        // Lightweight one-pole crossovers. These are visualization-only analysis
        // filters and never touch the playback samples.
        let lowAlpha = 1 - exp(-2 * Double.pi * 180 / sampleRate)
        let midAlpha = 1 - exp(-2 * Double.pi * 2_600 / sampleRate)
        var low = 0.0
        var lowMid = 0.0
        var previousMagnitude = 0.0

        var absoluteFrame: Int64 = 0
        file.framePosition = 0

        while absoluteFrame < totalFrames {
            let remaining = totalFrames - absoluteFrame
            let toRead = AVAudioFrameCount(min(Int64(capacity), remaining))
            try file.read(into: buffer, frameCount: toRead)
            let count = Int(buffer.frameLength)
            guard count > 0 else { break }

            if let data = buffer.floatChannelData {
                for i in 0..<count {
                    var samplePeak: Float = 0
                    var mono = 0.0
                    for c in 0..<max(1, channels) {
                        let sample = data[c][i]
                        samplePeak = max(samplePeak, abs(sample))
                        mono += Double(sample)
                    }
                    mono /= Double(max(1, channels))

                    let global = absoluteFrame + Int64(i)
                    let waveformIndex = min(waveformBins - 1, Int(global / waveformFramesPerBin))
                    if samplePeak > peaks[waveformIndex] { peaks[waveformIndex] = samplePeak }

                    low += lowAlpha * (mono - low)
                    lowMid += midAlpha * (mono - lowMid)
                    let bass = low
                    let mid = lowMid - low
                    let air = mono - lowMid
                    let magnitude = abs(mono)
                    let transient = max(0, magnitude - previousMagnitude)
                    previousMagnitude = magnitude

                    let visualIndex = min(visualBins - 1, Int(global / visualFramesPerBin))
                    rmsSum[visualIndex] += mono * mono
                    bassSum[visualIndex] += bass * bass
                    midSum[visualIndex] += mid * mid
                    airSum[visualIndex] += air * air
                    transientPeak[visualIndex] = max(transientPeak[visualIndex], transient)
                    visualCounts[visualIndex] += 1
                }
            }
            absoluteFrame += Int64(count)
        }

        let maxPeak = peaks.max() ?? 1
        if maxPeak > 0.00001 {
            for i in peaks.indices { peaks[i] = min(1, peaks[i] / maxPeak) }
        }

        var level = Array(repeating: Double(0), count: visualBins)
        var bass = Array(repeating: Double(0), count: visualBins)
        var mid = Array(repeating: Double(0), count: visualBins)
        var air = Array(repeating: Double(0), count: visualBins)

        for i in 0..<visualBins {
            let count = Double(max(1, visualCounts[i]))
            level[i] = sqrt(rmsSum[i] / count)
            bass[i] = sqrt(bassSum[i] / count)
            mid[i] = sqrt(midSum[i] / count)
            air[i] = sqrt(airSum[i] / count)
        }

        normalize(&level)
        normalize(&bass)
        normalize(&mid)
        normalize(&air)
        normalize(&transientPeak)

        let visual = (0..<visualBins).map { i in
            VisualAnalysisSample(
                level: Float(level[i].clamped(0...1)),
                bass: Float(bass[i].clamped(0...1)),
                mid: Float(mid[i].clamped(0...1)),
                air: Float(air[i].clamped(0...1)),
                transient: Float(transientPeak[i].clamped(0...1))
            )
        }

        return (peaks, visual)
    }

    private static func normalize(_ values: inout [Double]) {
        guard let peak = values.max(), peak > 0.000_001 else { return }
        // A gentle root curve keeps low-energy musical passages visibly alive
        // without making silence glow.
        for i in values.indices {
            values[i] = pow((values[i] / peak).clamped(0...1), 0.72)
        }
    }
}
