import Foundation
import AVFoundation
import AudioToolbox

struct AudioSourceDescriptor: Hashable {
    var sampleRate: Double
    var bitsPerChannel: Int
    var channels: Int
    var formatName: String
    var lossless: Bool
}

struct AudioPreflightReport {
    var sources: [AudioSourceDescriptor]
    var device: CoreAudioDeviceInfo?
    var engineSampleRate: Double
    var outputChannels: Int
    var error: String?

    var sourceRates: [Double] {
        Array(Set(sources.map { $0.sampleRate })).sorted()
    }

    var sourceBits: [Int] {
        Array(Set(sources.map { $0.bitsPerChannel })).sorted()
    }

    var sourceChannels: [Int] {
        Array(Set(sources.map { $0.channels })).sorted()
    }

    var sourceFormats: [String] {
        Array(Set(sources.map { $0.formatName })).sorted()
    }

    var uniformSourceRate: Double? {
        sourceRates.count == 1 ? sourceRates.first : nil
    }

    var allLossless: Bool {
        !sources.isEmpty && sources.allSatisfy(\.lossless)
    }

    var srcActive: Bool {
        guard let device else { return true }
        return sources.contains { abs($0.sampleRate - device.sampleRate) > 0.5 }
    }

    var transparentReady: Bool {
        error == nil && !sources.isEmpty && allLossless && !srcActive
    }

    var recommendedProjectRate: Double? {
        guard !sources.isEmpty else { return nil }
        let grouped = Dictionary(grouping: sources, by: { Int($0.sampleRate.rounded()) })
        guard let best = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return Double(best.key)
    }

    var canMatchDevice: Bool {
        guard let target = recommendedProjectRate, let device else { return false }
        return device.sampleRateSettable && device.supports(target) && abs(target - device.sampleRate) > 0.5
    }

    var sourceRateText: String {
        guard !sourceRates.isEmpty else { return "—" }
        return sourceRates.map(formatSampleRate).joined(separator: sourceRates.count > 1 ? " / " : "")
    }

    var sourceBitText: String {
        guard !sourceBits.isEmpty else { return "—" }
        return sourceBits.map { $0 > 0 ? "\($0)-bit" : "native" }.joined(separator: sourceBits.count > 1 ? " / " : "")
    }

    var sourceChannelText: String {
        guard !sourceChannels.isEmpty else { return "—" }
        return sourceChannels.map { "\($0) ch" }.joined(separator: sourceChannels.count > 1 ? " / " : "")
    }

    var sourceFormatText: String {
        sourceFormats.isEmpty ? "—" : sourceFormats.joined(separator: " / ")
    }
}

enum AudioPreflight {
    static func inspect(song: SongProject, engineSampleRate: Double, outputChannels: Int) -> AudioPreflightReport {
        let live = song.stems.filter { $0.effectiveRoute == .music }
        var descriptors: [AudioSourceDescriptor] = []
        var firstError: String?

        for stem in live {
            do {
                descriptors.append(try descriptor(url: URL(fileURLWithPath: stem.path)))
            } catch {
                if firstError == nil {
                    firstError = "\(stem.name): \(error.localizedDescription)"
                }
            }
        }

        var device: CoreAudioDeviceInfo?
        do {
            device = try CoreAudioDeviceManager.currentOutputInfo()
        } catch {
            if firstError == nil { firstError = error.localizedDescription }
        }

        return AudioPreflightReport(
            sources: descriptors,
            device: device,
            engineSampleRate: engineSampleRate,
            outputChannels: outputChannels,
            error: firstError
        )
    }

    private static func descriptor(url: URL) throws -> AudioSourceDescriptor {
        let file = try AVAudioFile(forReading: url)
        let asbd = file.fileFormat.streamDescription.pointee
        let formatID = asbd.mFormatID
        let lossless = formatID == kAudioFormatLinearPCM ||
            formatID == kAudioFormatAppleLossless ||
            formatID == kAudioFormatFLAC

        return AudioSourceDescriptor(
            sampleRate: file.fileFormat.sampleRate,
            bitsPerChannel: Int(asbd.mBitsPerChannel),
            channels: Int(file.fileFormat.channelCount),
            formatName: formatName(formatID),
            lossless: lossless
        )
    }

    private static func formatName(_ id: AudioFormatID) -> String {
        switch id {
        case kAudioFormatLinearPCM: return "PCM"
        case kAudioFormatAppleLossless: return "ALAC"
        case kAudioFormatFLAC: return "FLAC"
        case kAudioFormatMPEG4AAC: return "AAC"
        default:
            let chars: [UInt8] = [
                UInt8((id >> 24) & 0xff),
                UInt8((id >> 16) & 0xff),
                UInt8((id >> 8) & 0xff),
                UInt8(id & 0xff)
            ]
            let text = String(bytes: chars, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? "Other" : text
        }
    }
}
