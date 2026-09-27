import Foundation
import CoreAudio
import AudioToolbox

struct CoreAudioDeviceInfo: Equatable {
    var id: AudioObjectID
    var name: String
    var sampleRate: Double
    var bufferFrames: UInt32
    var availableSampleRates: [ClosedRange<Double>]
    var sampleRateSettable: Bool

    func supports(_ rate: Double) -> Bool {
        availableSampleRates.contains { $0.contains(rate) }
    }
}

enum CoreAudioDeviceError: LocalizedError {
    case noDefaultOutput
    case property(OSStatus, String)
    case unsupportedRate(Double)

    var errorDescription: String? {
        switch self {
        case .noDefaultOutput:
            return "No CoreAudio default output device is available."
        case let .property(status, label):
            return "\(label) failed (OSStatus \(status))."
        case let .unsupportedRate(rate):
            return "The output device does not advertise \(formatSampleRate(rate))."
        }
    }
}

enum CoreAudioDeviceManager {
    static func defaultOutputDeviceID() throws -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else {
            throw CoreAudioDeviceError.noDefaultOutput
        }
        return device
    }

    static func currentOutputInfo() throws -> CoreAudioDeviceInfo {
        let device = try defaultOutputDeviceID()
        let name = try stringProperty(
            device: device,
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal
        ) ?? "Default Output"

        let rate = try float64Property(
            device: device,
            selector: kAudioDevicePropertyNominalSampleRate,
            scope: kAudioObjectPropertyScopeGlobal
        )

        let frames = try uint32Property(
            device: device,
            selector: kAudioDevicePropertyBufferFrameSize,
            scope: kAudioDevicePropertyScopeOutput
        )

        var rateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(device, &rateAddress, &settable)

        return CoreAudioDeviceInfo(
            id: device,
            name: name,
            sampleRate: rate,
            bufferFrames: frames,
            availableSampleRates: availableRateRanges(device: device),
            sampleRateSettable: settableStatus == noErr && settable.boolValue
        )
    }

    static func setNominalSampleRate(_ target: Double) throws {
        let info = try currentOutputInfo()
        guard info.supports(target) else {
            throw CoreAudioDeviceError.unsupportedRate(target)
        }
        guard info.sampleRateSettable else {
            throw CoreAudioDeviceError.property(kAudioHardwareUnsupportedOperationError, "Changing device sample rate")
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate = Float64(target)
        let status = AudioObjectSetPropertyData(
            info.id,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float64>.size),
            &rate
        )
        guard status == noErr else {
            throw CoreAudioDeviceError.property(status, "Setting device sample rate")
        }

        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            let observed = try float64Property(
                device: info.id,
                selector: kAudioDevicePropertyNominalSampleRate,
                scope: kAudioObjectPropertyScopeGlobal
            )
            if abs(observed - target) < 0.5 { return }
            Thread.sleep(forTimeInterval: 0.04)
        }

        let observed = try float64Property(
            device: info.id,
            selector: kAudioDevicePropertyNominalSampleRate,
            scope: kAudioObjectPropertyScopeGlobal
        )
        guard abs(observed - target) < 0.5 else {
            throw CoreAudioDeviceError.property(kAudioHardwareUnspecifiedError, "Waiting for device sample rate")
        }
    }

    private static func stringProperty(
        device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { ptr in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else {
            throw CoreAudioDeviceError.property(status, "Reading device name")
        }
        return value.map { $0 as String }
    }

    private static func float64Property(
        device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = Float64(0)
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw CoreAudioDeviceError.property(status, "Reading CoreAudio value")
        }
        return value
    }

    private static func uint32Property(
        device: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw CoreAudioDeviceError.property(status, "Reading CoreAudio value")
        }
        return value
    }

    private static func availableRateRanges(device: AudioObjectID) -> [ClosedRange<Double>] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size >= UInt32(MemoryLayout<AudioValueRange>.size) else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioValueRange>.size
        var ranges = Array(repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: count)
        let status = ranges.withUnsafeMutableBytes { raw -> OSStatus in
            guard let baseAddress = raw.baseAddress else { return kAudio_ParamError }
            var mutableSize = size
            return AudioObjectGetPropertyData(device, &address, 0, nil, &mutableSize, baseAddress)
        }
        guard status == noErr else { return [] }
        return ranges.map { Double($0.mMinimum)...Double($0.mMaximum) }
    }
}
