import SwiftUI
import AppKit
import QuartzCore

/// GPU-backed stage ambience. Audio timing never depends on this view.
/// The view is deliberately non-interactive so it can never intercept live controls.
struct LivingColorView: NSViewRepresentable {
    var metrics: VisualMetrics
    var enabled: Bool
    var intensity: Double
    var palette: LivingColorPalette = .aurora
    var motion: Double = 0.72
    var playing: Bool

    func makeNSView(context: Context) -> LivingColorNSView {
        LivingColorNSView(frame: .zero)
    }

    func updateNSView(_ nsView: LivingColorNSView, context: Context) {
        nsView.apply(metrics: metrics, enabled: enabled, intensity: intensity, palette: palette, motion: motion, playing: playing)
    }
}

final class LivingColorNSView: NSView {
    private let base = CALayer()
    private let ambient = CAGradientLayer()
    private let bassGlow = CAGradientLayer()
    private let airGlow = CAGradientLayer()
    private let transientGlow = CAGradientLayer()
    private let veil = CAGradientLayer()

    private var smoothed = VisualMetrics()
    private var lastTime = CACurrentMediaTime()
    private var wasPlaying = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func commonInit() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor(calibratedWhite: 0.007, alpha: 1).cgColor
        layer?.masksToBounds = true

        base.backgroundColor = NSColor(calibratedWhite: 0.007, alpha: 1).cgColor
        layer?.addSublayer(base)

        [ambient, bassGlow, airGlow, transientGlow].forEach {
            configure($0)
            $0.compositingFilter = "screenBlendMode"
            layer?.addSublayer($0)
        }

        ambient.type = .radial
        ambient.startPoint = CGPoint(x: 0.50, y: 0.48)
        ambient.endPoint = CGPoint(x: 1.0, y: 1.0)

        bassGlow.type = .radial
        bassGlow.startPoint = CGPoint(x: 0.12, y: 0.22)
        bassGlow.endPoint = CGPoint(x: 0.88, y: 0.96)

        airGlow.type = .radial
        airGlow.startPoint = CGPoint(x: 0.88, y: 0.74)
        airGlow.endPoint = CGPoint(x: 0.08, y: 0.10)

        transientGlow.type = .radial
        transientGlow.startPoint = CGPoint(x: 0.56, y: 0.14)
        transientGlow.endPoint = CGPoint(x: 0.50, y: 0.92)

        veil.colors = [
            NSColor(calibratedWhite: 0.00, alpha: 0.04).cgColor,
            NSColor(calibratedWhite: 0.00, alpha: 0.36).cgColor,
            NSColor(calibratedWhite: 0.00, alpha: 0.62).cgColor
        ]
        veil.locations = [0, 0.62, 1]
        veil.startPoint = CGPoint(x: 0.5, y: 1)
        veil.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(veil)
    }

    private func configure(_ gradient: CAGradientLayer) {
        gradient.locations = [0, 0.44, 1]
        gradient.opacity = 0
        gradient.masksToBounds = false
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        ambient.frame = bounds.insetBy(dx: -bounds.width * 0.12, dy: -bounds.height * 0.12)
        bassGlow.frame = bounds.insetBy(dx: -bounds.width * 0.24, dy: -bounds.height * 0.24)
        airGlow.frame = bounds.insetBy(dx: -bounds.width * 0.22, dy: -bounds.height * 0.22)
        transientGlow.frame = bounds.insetBy(dx: -bounds.width * 0.18, dy: -bounds.height * 0.18)
        veil.frame = bounds
        CATransaction.commit()
    }

    func apply(metrics: VisualMetrics, enabled: Bool, intensity: Double, palette: LivingColorPalette, motion: Double, playing: Bool) {
        let enabledPlaying = enabled && playing
        let now = CACurrentMediaTime()
        let dt = min(0.15, max(0.01, now - lastTime))
        lastTime = now

        let target = enabledPlaying ? metrics : VisualMetrics()
        smoothed.level = smooth(smoothed.level, target.level, dt: dt, attack: 0.22, release: 1.25)
        smoothed.bass = smooth(smoothed.bass, target.bass, dt: dt, attack: 0.30, release: 0.90)
        smoothed.mid = smooth(smoothed.mid, target.mid, dt: dt, attack: 0.28, release: 0.88)
        smoothed.air = smooth(smoothed.air, target.air, dt: dt, attack: 0.24, release: 0.82)
        smoothed.transient = smooth(smoothed.transient, target.transient, dt: dt, attack: 0.10, release: 0.46)

        let strength = max(0.25, min(1.15, intensity))
        // Quiet music should still feel alive; silence/stopped transport should not.
        let alive = enabledPlaying
            ? min(1, (0.17 + pow(smoothed.level, 0.72) * 0.83) * strength)
            : 0

        let colors = colors(for: smoothed, palette: palette)
        let primary = colors.0
        let secondary = colors.1
        let accent = colors.2
        let bright = colors.3

        CATransaction.begin()
        if !enabledPlaying && wasPlaying {
            CATransaction.setAnimationDuration(2.6)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else if enabledPlaying && !wasPlaying {
            CATransaction.setAnimationDuration(0.58)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setAnimationDuration(0.16)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        }

        ambient.colors = [
            primary.withAlphaComponent(0.72).cgColor,
            secondary.withAlphaComponent(0.23).cgColor,
            NSColor.clear.cgColor
        ]
        bassGlow.colors = [
            secondary.withAlphaComponent(0.78).cgColor,
            accent.withAlphaComponent(0.22).cgColor,
            NSColor.clear.cgColor
        ]
        airGlow.colors = [
            bright.withAlphaComponent(0.66).cgColor,
            primary.withAlphaComponent(0.16).cgColor,
            NSColor.clear.cgColor
        ]
        transientGlow.colors = [
            accent.withAlphaComponent(0.82).cgColor,
            bright.withAlphaComponent(0.13).cgColor,
            NSColor.clear.cgColor
        ]

        ambient.opacity = Float(alive * 0.52)
        bassGlow.opacity = Float(alive * (0.24 + smoothed.bass * 0.38))
        airGlow.opacity = Float(alive * (0.18 + smoothed.air * 0.36))
        transientGlow.opacity = Float(alive * smoothed.transient * 0.34)

        let motionAmount = CGFloat(alive * max(0, min(1.25, motion)))
        ambient.position = CGPoint(
            x: bounds.midX + CGFloat(smoothed.mid - 0.45) * 18 * motionAmount,
            y: bounds.midY + CGFloat(smoothed.level - 0.45) * 12 * motionAmount
        )
        bassGlow.position = CGPoint(
            x: bounds.midX - bounds.width * 0.18 + CGFloat(smoothed.bass - 0.45) * 24 * motionAmount,
            y: bounds.midY - bounds.height * 0.09 + CGFloat(smoothed.level - 0.40) * 16 * motionAmount
        )
        airGlow.position = CGPoint(
            x: bounds.midX + bounds.width * 0.18 + CGFloat(smoothed.air - 0.40) * 24 * motionAmount,
            y: bounds.midY + bounds.height * 0.10 + CGFloat(smoothed.air - 0.35) * 15 * motionAmount
        )
        transientGlow.position = CGPoint(
            x: bounds.midX + CGFloat(smoothed.transient - 0.25) * 16 * motionAmount,
            y: bounds.midY + bounds.height * 0.20
        )

        // Let performance color reach the material layer without sacrificing text contrast.
        veil.opacity = Float(enabledPlaying ? max(0.48, 0.74 - alive * 0.23) : 0.78)
        CATransaction.commit()

        wasPlaying = enabledPlaying
    }

    private func smooth(_ current: Double, _ target: Double, dt: Double, attack: Double, release: Double) -> Double {
        let tau = target > current ? attack : release
        let a = 1 - exp(-dt / max(0.001, tau))
        return current + (target - current) * a
    }

    /// Palette selection changes hue language only; musical energy remains driven
    /// by the same cached analysis envelope.
    private func colors(for m: VisualMetrics, palette: LivingColorPalette) -> (NSColor, NSColor, NSColor, NSColor) {
        let blue = NSColor(calibratedRed: 0.04, green: 0.48, blue: 1.00, alpha: 1)
        let indigo = NSColor(calibratedRed: 0.34, green: 0.32, blue: 0.96, alpha: 1)
        let purple = NSColor(calibratedRed: 0.69, green: 0.30, blue: 0.96, alpha: 1)
        let cyan = NSColor(calibratedRed: 0.12, green: 0.79, blue: 0.98, alpha: 1)
        let pink = NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.51, alpha: 1)
        let orange = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.08, alpha: 1)
        let gold = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.18, alpha: 1)
        let teal = NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.70, alpha: 1)

        let base: (NSColor, NSColor, NSColor, NSColor)
        switch palette {
        case .aurora:
            base = (blue, indigo, purple, cyan)
        case .ocean:
            base = (blue, cyan, teal, NSColor(calibratedRed: 0.38, green: 0.90, blue: 1.00, alpha: 1))
        case .violet:
            base = (indigo, purple, pink, cyan)
        case .warmStage:
            base = (indigo, purple, orange, gold)
        }

        let primary = blend(base.0, base.1, amount: min(0.64, m.mid * 0.58 + m.level * 0.10))
        let secondary = blend(base.1, base.2, amount: min(0.72, m.mid * 0.54 + m.bass * 0.20))
        let transientTarget = palette == .warmStage ? gold : pink
        let accent = blend(base.2, m.transient > 0.36 ? transientTarget : orange, amount: min(0.46, m.transient * 0.42 + m.bass * 0.12))
        let bright = blend(base.0, base.3, amount: min(0.82, 0.32 + m.air * 0.56))
        return (primary, secondary, accent, bright)
    }

    private func blend(_ a: NSColor, _ b: NSColor, amount: Double) -> NSColor {
        let t = CGFloat(max(0, min(1, amount)))
        let aa = a.usingColorSpace(.deviceRGB) ?? a
        let bb = b.usingColorSpace(.deviceRGB) ?? b
        return NSColor(
            calibratedRed: aa.redComponent + (bb.redComponent - aa.redComponent) * t,
            green: aa.greenComponent + (bb.greenComponent - aa.greenComponent) * t,
            blue: aa.blueComponent + (bb.blueComponent - aa.blueComponent) * t,
            alpha: 1
        )
    }
}
