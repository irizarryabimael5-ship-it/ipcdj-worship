import Foundation

struct StemSyncResult: Sendable {
    var offsets: [UUID: Double]
    var confidences: [UUID: Double]
    var referenceID: UUID?
    var message: String
}

enum StemSyncAnalyzer {
    /// Offline envelope correlation. This never time-stretches or resamples program
    /// audio; it only estimates a safe source trim for already-related stem files.
    static func analyze(song: SongProject, maximumShift: Double = 10) -> StemSyncResult {
        let candidates = song.stems.filter {
            $0.effectiveRoute != .click && $0.waveform.count >= 80 && $0.duration > 4
        }
        guard candidates.count >= 2 else {
            return StemSyncResult(
                offsets: [:],
                confidences: [:],
                referenceID: candidates.first?.id,
                message: "Auto Sync needs at least two analyzed audio stems."
            )
        }

        let reference = chooseReference(candidates)
        var rawLag: [UUID: Double] = [reference.id: 0]
        var confidence: [UUID: Double] = [reference.id: 1]

        for stem in candidates where stem.id != reference.id {
            let result = bestLag(reference: reference, target: stem, maximumShift: maximumShift)
            rawLag[stem.id] = result.lag
            confidence[stem.id] = result.confidence
        }

        // A source trim cannot be negative. Shift all estimates by the earliest lag
        // so the common overlapping musical origin becomes project time zero.
        let minimum = rawLag.values.min() ?? 0
        var offsets: [UUID: Double] = [:]
        for stem in candidates {
            let score = confidence[stem.id] ?? 0
            let proposed = max(0, (rawLag[stem.id] ?? 0) - minimum)
            // Low-confidence estimates are intentionally left at zero rather than
            // presenting a mathematically possible but musically unsafe correction.
            offsets[stem.id] = score >= 0.42 ? proposed : 0
        }

        let confident = confidence.values.filter { $0 >= 0.42 }.count
        let average = confidence.values.reduce(0, +) / Double(max(1, confidence.count))
        return StemSyncResult(
            offsets: offsets,
            confidences: confidence,
            referenceID: reference.id,
            message: "Aligned \(confident)/\(candidates.count) stems · average confidence \(Int((average * 100).rounded()))% · reference: \(reference.name)"
        )
    }

    private static func chooseReference(_ stems: [StemTrack]) -> StemTrack {
        if let explicit = stems.first(where: { $0.effectiveRoute == .reference }) {
            return explicit
        }
        return stems.max(by: { activityScore($0) < activityScore($1) }) ?? stems[0]
    }

    private static func activityScore(_ stem: StemTrack) -> Double {
        guard stem.waveform.count > 2 else { return 0 }
        var positiveDelta = 0.0
        var total = 0.0
        var previous = Double(stem.waveform[0])
        for value in stem.waveform.dropFirst() {
            let v = Double(value)
            positiveDelta += max(0, v - previous)
            total += v
            previous = v
        }
        return positiveDelta / Double(stem.waveform.count) + total / Double(stem.waveform.count) * 0.12
    }

    private static func bestLag(
        reference: StemTrack,
        target: StemTrack,
        maximumShift: Double
    ) -> (lag: Double, confidence: Double) {
        let step = 0.10
        let searchSteps = max(1, Int(maximumShift / step))
        var bestLag = 0.0
        var best = -Double.greatestFiniteMagnitude
        var second = -Double.greatestFiniteMagnitude

        for lagStep in -searchSteps...searchSteps {
            let lag = Double(lagStep) * step
            let score = correlation(reference: reference, target: target, lag: lag, step: step)
            if score > best {
                second = best
                best = score
                bestLag = lag
            } else if score > second {
                second = score
            }
        }

        let absolute = max(0, min(1, (best + 1) / 2))
        let separation = max(0, min(1, (best - second) * 8))
        let confidence = (absolute * 0.78 + separation * 0.22).clamped(0...1)
        return (bestLag, confidence)
    }

    /// Positive lag means the target's matching material occurs later than the
    /// reference, so the target needs that much additional source trim.
    private static func correlation(
        reference: StemTrack,
        target: StemTrack,
        lag: Double,
        step: Double
    ) -> Double {
        let start = max(0, -lag)
        let end = min(reference.duration, target.duration - lag)
        guard end - start >= 4 else { return -1 }

        var xs: [Double] = []
        var ys: [Double] = []
        xs.reserveCapacity(Int((end - start) / step))
        ys.reserveCapacity(xs.capacity)

        var time = start
        while time < end {
            xs.append(feature(reference, at: time))
            ys.append(feature(target, at: time + lag))
            time += step
        }
        guard xs.count >= 40 else { return -1 }

        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var numerator = 0.0
        var dx2 = 0.0
        var dy2 = 0.0
        for i in xs.indices {
            let dx = xs[i] - meanX
            let dy = ys[i] - meanY
            numerator += dx * dy
            dx2 += dx * dx
            dy2 += dy * dy
        }
        let denom = sqrt(dx2 * dy2)
        return denom > 0.000_001 ? numerator / denom : -1
    }

    private static func feature(_ stem: StemTrack, at time: Double) -> Double {
        guard !stem.waveform.isEmpty, stem.duration > 0 else { return 0 }
        let normalized = (time / stem.duration).clamped(0...1)
        let position = normalized * Double(stem.waveform.count - 1)
        let lower = max(0, min(stem.waveform.count - 1, Int(floor(position))))
        let upper = min(stem.waveform.count - 1, lower + 1)
        let blend = position - Double(lower)
        let a = Double(stem.waveform[lower])
        let b = Double(stem.waveform[upper])
        let amplitude = a + (b - a) * blend

        let previousIndex = max(0, lower - 1)
        let delta = max(0, amplitude - Double(stem.waveform[previousIndex]))
        return sqrt(max(0, amplitude)) * 0.72 + min(1, delta * 5) * 0.28
    }
}
