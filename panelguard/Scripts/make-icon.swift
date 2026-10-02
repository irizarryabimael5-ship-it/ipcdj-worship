import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "PanelGuard-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
let bounds = NSRect(origin: .zero, size: size)
let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 74, dy: 74), xRadius: 210, yRadius: 210)
context.saveGState()
rounded.addClip()
let colors = [
    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.34, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.20, green: 0.36, blue: 0.74, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 160, y: 860), end: CGPoint(x: 850, y: 140), options: [])
context.restoreGState()

NSColor.white.withAlphaComponent(0.94).setStroke()
let displayRect = NSRect(x: 220, y: 310, width: 584, height: 390)
let display = NSBezierPath(roundedRect: displayRect, xRadius: 48, yRadius: 48)
display.lineWidth = 38
display.stroke()

let stand = NSBezierPath()
stand.move(to: NSPoint(x: 512, y: 310))
stand.line(to: NSPoint(x: 512, y: 230))
stand.lineWidth = 34
stand.lineCapStyle = .round
stand.stroke()
let foot = NSBezierPath()
foot.move(to: NSPoint(x: 390, y: 220))
foot.line(to: NSPoint(x: 634, y: 220))
foot.lineWidth = 34
foot.lineCapStyle = .round
foot.stroke()

let moonOuter = NSBezierPath(ovalIn: NSRect(x: 535, y: 415, width: 170, height: 170))
NSColor.white.withAlphaComponent(0.96).setFill()
moonOuter.fill()
let moonCut = NSBezierPath(ovalIn: NSRect(x: 588, y: 458, width: 150, height: 150))
NSColor(calibratedRed: 0.17, green: 0.30, blue: 0.61, alpha: 1).setFill()
moonCut.fill()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let data = rep.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: output))
