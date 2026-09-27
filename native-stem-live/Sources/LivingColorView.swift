import SwiftUI
import AppKit
import QuartzCore

struct LivingColorView: NSViewRepresentable {
    var metrics: VisualMetrics
    var enabled: Bool
    var intensity: Double

    func makeNSView(context: Context) -> LivingColorNSView {
        let v = LivingColorNSView()
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ nsView: LivingColorNSView, context: Context) {
        nsView.apply(metrics: metrics, enabled: enabled, intensity: intensity)
    }
}

final class LivingColorNSView: NSView {
    private let base = CALayer()
    private let glowA = CAGradientLayer()
    private let glowB = CAGradientLayer()
    private let veil = CAGradientLayer()
    private var smoothed = VisualMetrics()
    private var lastTime = CACurrentMediaTime()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor(calibratedWhite: 0.018, alpha: 1).cgColor
        layer?.masksToBounds = true

        base.backgroundColor = NSColor(calibratedWhite: 0.018, alpha: 1).cgColor
        layer?.addSublayer(base)

        configure(glowA)
        configure(glowB)
        glowA.type = .radial
        glowB.type = .radial
        glowA.startPoint = CGPoint(x: 0.18, y: 0.18)
        glowA.endPoint = CGPoint(x: 0.95, y: 0.95)
        glowB.startPoint = CGPoint(x: 0.82, y: 0.80)
        glowB.endPoint = CGPoint(x: 0.06, y: 0.05)
        layer?.addSublayer(glowA)
        layer?.addSublayer(glowB)

        veil.colors = [
            NSColor(calibratedWhite: 0.01, alpha: 0.12).cgColor,
            NSColor(calibratedWhite: 0.005, alpha: 0.44).cgColor
        ]
        veil.startPoint = CGPoint(x: 0.5, y: 1)
        veil.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(veil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func configure(_ g: CAGradientLayer) {
        g.locations = [0, 0.45, 1]
        g.opacity = 0
        g.masksToBounds = false
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        glowA.frame = bounds.insetBy(dx: -bounds.width * 0.20, dy: -bounds.height * 0.20)
        glowB.frame = bounds.insetBy(dx: -bounds.width * 0.18, dy: -bounds.height * 0.18)
        veil.frame = bounds
        CATransaction.commit()
    }

    func apply(metrics: VisualMetrics, enabled: Bool, intensity: Double) {
        let now = CACurrentMediaTime()
        let dt = min(0.15, max(0.01, now - lastTime))
        lastTime = now
        let target = enabled ? metrics : VisualMetrics()

        smoothed.level = smooth(smoothed.level, target.level, dt: dt, attack: 0.60, release: 2.20)
        smoothed.bass = smooth(smoothed.bass, target.bass * smoothed.level, dt: dt, attack: 0.52, release: 1.30)
        smoothed.mid = smooth(smoothed.mid, target.mid * smoothed.level, dt: dt, attack: 0.54, release: 1.35)
        smoothed.air = smooth(smoothed.air, target.air * smoothed.level, dt: dt, attack: 0.48, release: 1.20)
        smoothed.transient = smooth(smoothed.transient, target.transient * smoothed.level, dt: dt, attack: 0.28, release: 0.85)

        let alive = min(1, smoothed.level * max(0, intensity))
        let palette = colors(for: smoothed)
        let primary = palette.0
        let secondary = palette.1
        let accent = palette.2

        CATransaction.begin()
        CATransaction.setAnimationDuration(alive > Double(glowA.opacity) ? 0.62 : 1.35)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        glowA.colors = [
            primary.withAlphaComponent(0.78).cgColor,
            secondary.withAlphaComponent(0.24).cgColor,
            NSColor.clear.cgColor
        ]
        glowB.colors = [
            accent.withAlphaComponent(0.52).cgColor,
            secondary.withAlphaComponent(0.13).cgColor,
            NSColor.clear.cgColor
        ]
        glowA.opacity = Float(alive * 0.70)
        glowB.opacity = Float(alive * (0.20 + smoothed.air * 0.25 + smoothed.transient * 0.10))

        let move = CGFloat(alive)
        glowA.position = CGPoint(
            x: bounds.midX + CGFloat(smoothed.mid - smoothed.air) * 12 * move,
            y: bounds.midY + CGFloat(smoothed.bass - 0.5) * 9 * move
        )
        glowB.position = CGPoint(
            x: bounds.midX + CGFloat(smoothed.air - smoothed.bass) * 15 * move,
            y: bounds.midY + CGFloat(smoothed.transient - 0.25) * 10 * move
        )
        veil.opacity = Float(0.78 - alive * 0.16)
        CATransaction.commit()
    }

    private func smooth(_ current: Double, _ target: Double, dt: Double, attack: Double, release: Double) -> Double {
        let tau = target > current ? attack : release
        let a = 1 - exp(-dt / max(0.001, tau))
        return current + (target - current) * a
    }

    private func colors(for m: VisualMetrics) -> (NSColor, NSColor, NSColor) {
        let blue = NSColor(calibratedRed: 0.04, green: 0.49, blue: 1.0, alpha: 1)
        let indigo = NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.93, alpha: 1)
        let purple = NSColor(calibratedRed: 0.69, green: 0.32, blue: 0.95, alpha: 1)
        let cyan = NSColor(calibratedRed: 0.16, green: 0.78, blue: 0.98, alpha: 1)
        let pink = NSColor(calibratedRed: 1.0, green: 0.26, blue: 0.52, alpha: 1)
        let orange = NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.06, alpha: 1)

        let primary = blend(blue, indigo, amount: min(0.58, m.mid * 0.50 + m.bass * 0.12))
        let secondary = blend(indigo, purple, amount: min(0.55, m.mid * 0.42 + (1 - m.air) * 0.14))
        let bright = blend(cyan, m.transient > 0.42 ? pink : orange, amount: min(0.34, m.transient * 0.32))
        return (primary, secondary, bright)
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
