import Foundation

struct VisualMetrics: Equatable {
    var level: Double = 0
    var bass: Double = 0
    var mid: Double = 0
    var air: Double = 0
    var transient: Double = 0
}

enum WorkspacePage: String, CaseIterable, Identifiable, Codable {
    case live = "LIVE"
    case set = "SET"
    case arrange = "ARRANGE"
    case mix = "MIX"
    case click = "CLICK"
    case system = "SYSTEM"
    var id: String { rawValue }
}

enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case stereo = "Stereo Music"
    case split = "Music L / Click R"
    var id: String { rawValue }
}

enum MonoDownmixMode: String, Codable, CaseIterable, Identifiable {
    case safeSum = "Safe Sum · L+R -6 dB"
    case equalPower = "Equal Power · L+R -3 dB"
    case leftOnly = "Left Only"
    case rightOnly = "Right Only"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .safeSum: return "SAFE SUM"
        case .equalPower: return "EQUAL POWER"
        case .leftOnly: return "LEFT ONLY"
        case .rightOnly: return "RIGHT ONLY"
        }
    }
}

enum ClickPreset: String, Codable, CaseIterable, Identifiable {
    case softWood = "Soft Wood"
    case warmPulse = "Warm Pulse"
    case studioBlock = "Studio Block"
    case deepTick = "Deep Tick"
    var id: String { rawValue }
}

struct StemTrack: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var path: String
    var volume: Double = 1.0
    var muted: Bool = false
    var solo: Bool = false
    var reference: Bool = false
    var waveform: [Float] = []
    var duration: Double = 0
}

struct SectionMarker: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var start: Double
    var end: Double
    var loopStart: Double
    var loopEnd: Double
    var loopable: Bool = true
    var lyrics: String = ""
    var verified: Bool = false
}

struct ClickSettings: Codable, Hashable {
    var enabled: Bool = true
    var preset: ClickPreset = .softWood
    var levelDB: Double = -12
    var accentDB: Double = 3
    var eighths: Bool = false
    var sixteenths: Bool = false
    var offsetMS: Double = 0
}

struct SongProject: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var bpm: Double = 120
    var meterTop: Int = 4
    var meterBottom: Int = 4
    var outputMode: OutputMode = .stereo
    var monoDownmixMode: MonoDownmixMode? = nil
    var stems: [StemTrack] = []
    var sections: [SectionMarker] = []
    var click = ClickSettings()
    var createdAt = Date()

    var duration: Double {
        stems.filter { !$0.reference }.map(\.duration).max() ?? 0
    }

    var meterText: String { "\(meterTop)/\(meterBottom)" }
    var effectiveMonoDownmixMode: MonoDownmixMode { monoDownmixMode ?? .safeSum }
}

extension Double {
    func clamped(_ range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "00:00.000" }
    let s = max(0, seconds)
    let minutes = Int(s / 60)
    let secs = Int(s) % 60
    let ms = Int((s - floor(s)) * 1000)
    return String(format: "%02d:%02d.%03d", minutes, secs, ms)
}

func formatSampleRate(_ rate: Double) -> String {
    guard rate > 0 else { return "—" }
    if abs(rate.rounded() - rate) < 0.01 {
        return String(format: "%,.0f Hz", rate)
    }
    return String(format: "%,.1f Hz", rate)
}
