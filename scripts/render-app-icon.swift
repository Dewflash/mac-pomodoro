#!/usr/bin/env swift
import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Pomodewro.iconset")
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func oval(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: width, height: height))
}

func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

func drawIcon(pixelSize: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "PomodewroIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "PomodewroIcon", code: 2)
    }
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixelSize) / 1024, y: CGFloat(pixelSize) / 1024)
    context.cgContext.setAllowsAntialiasing(true)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    let base = roundedRect(x: 66, y: 66, width: 892, height: 892, radius: 218)
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.38)
    shadow.shadowBlurRadius = 46
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    NSGradient(colors: [color(0x172032), color(0x090d16), color(0x211428)])?.draw(in: base, angle: 132)

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    roundedRect(x: 104, y: 104, width: 816, height: 816, radius: 186).lineWidth = 7
    color(0x4ee8dc, alpha: 0.34).setStroke()
    roundedRect(x: 104, y: 104, width: 816, height: 816, radius: 186).stroke()

    let ring = oval(x: 214, y: 170, width: 596, height: 596)
    color(0x4ee8dc, alpha: 0.22).setStroke()
    ring.lineWidth = 38
    ring.stroke()

    let tomato = oval(x: 294, y: 232, width: 436, height: 424)
    let tomatoShadow = NSShadow()
    tomatoShadow.shadowColor = color(0x4ee8dc, alpha: 0.24)
    tomatoShadow.shadowBlurRadius = 54
    tomatoShadow.shadowOffset = NSSize(width: 0, height: -12)
    tomatoShadow.set()
    NSGradient(colors: [color(0x65fff1), color(0x37d5ca), color(0x14a9a4)])?.draw(in: tomato, angle: 110)

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    color(0xffffff, alpha: 0.3).setFill()
    oval(x: 384, y: 490, width: 112, height: 84).fill()

    color(0x061017, alpha: 0.58).setStroke()
    let hand = NSBezierPath()
    hand.lineWidth = 34
    hand.lineCapStyle = .round
    hand.move(to: NSPoint(x: 512, y: 438))
    hand.line(to: NSPoint(x: 512, y: 545))
    hand.line(to: NSPoint(x: 590, y: 502))
    hand.stroke()

    color(0x061017, alpha: 0.82).setFill()
    oval(x: 484, y: 410, width: 56, height: 56).fill()

    color(0x85fff6).setFill()
    let leafLeft = NSBezierPath()
    leafLeft.move(to: NSPoint(x: 494, y: 638))
    leafLeft.curve(to: NSPoint(x: 374, y: 766), controlPoint1: NSPoint(x: 466, y: 744), controlPoint2: NSPoint(x: 408, y: 780))
    leafLeft.curve(to: NSPoint(x: 504, y: 660), controlPoint1: NSPoint(x: 386, y: 686), controlPoint2: NSPoint(x: 440, y: 646))
    leafLeft.fill()

    let leafRight = NSBezierPath()
    leafRight.move(to: NSPoint(x: 524, y: 642))
    leafRight.curve(to: NSPoint(x: 684, y: 778), controlPoint1: NSPoint(x: 540, y: 750), controlPoint2: NSPoint(x: 620, y: 798))
    leafRight.curve(to: NSPoint(x: 530, y: 662), controlPoint1: NSPoint(x: 652, y: 696), controlPoint2: NSPoint(x: 590, y: 648))
    leafRight.fill()

    let stem = NSBezierPath()
    stem.lineWidth = 32
    stem.lineCapStyle = .round
    stem.move(to: NSPoint(x: 512, y: 642))
    stem.curve(to: NSPoint(x: 540, y: 786), controlPoint1: NSPoint(x: 512, y: 700), controlPoint2: NSPoint(x: 534, y: 736))
    stem.stroke()

    color(0xffffff, alpha: 0.82).setStroke()
    let tick = NSBezierPath()
    tick.lineWidth = 34
    tick.lineCapStyle = .round
    tick.move(to: NSPoint(x: 728, y: 642))
    tick.line(to: NSPoint(x: 766, y: 700))
    tick.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PomodewroIcon", code: 3)
    }
    try data.write(to: url)
}

let icons: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in icons {
    try drawIcon(pixelSize: size, to: outputURL.appendingPathComponent(filename))
}
