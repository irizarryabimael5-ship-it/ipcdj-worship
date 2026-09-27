import Foundation
import AVFoundation

struct WaveformBuilder {
    static func inspect(url: URL) throws -> (duration: Double, waveform: [Float]) {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        let duration = rate > 0 ? Double(file.length) / rate : 0
        let bins = max(900, min(2400, Int(duration * 7)))
        return (duration, try buildPeaks(file: file, bins: bins))
    }

    private static func buildPeaks(file: AVAudioFile, bins: Int) throws -> [Float] {
        guard bins > 0, file.length > 0 else { return [] }
        let channels = Int(file.processingFormat.channelCount)
        let totalFrames = Int64(file.length)
        let framesPerBin = max<Int64>(1, totalFrames / Int64(bins))
        let capacity: AVAudioFrameCount = 16_384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else { return [] }
        var peaks = Array(repeating: Float(0), count: bins)
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
                    for c in 0..<max(1, channels) {
                        samplePeak = max(samplePeak, abs(data[c][i]))
                    }
                    let global = absoluteFrame + Int64(i)
                    let bin = min(bins - 1, Int(global / framesPerBin))
                    if samplePeak > peaks[bin] { peaks[bin] = samplePeak }
                }
            }
            absoluteFrame += Int64(count)
        }

        let maxPeak = peaks.max() ?? 1
        if maxPeak > 0.00001 {
            for i in peaks.indices { peaks[i] = min(1, peaks[i] / maxPeak) }
        }
        return peaks
    }
}
