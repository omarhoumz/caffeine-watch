// Renders Resources/AppIcon.icns: the menu bar mug, steaming, on a coffee-coloured tile.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(red: 0.55, green: 0.33, blue: 0.20, alpha: 1),
               ending: NSColor(red: 0.30, green: 0.17, blue: 0.10, alpha: 1))!.draw(in: tile, angle: -90)

    // Same geometry as MenuBarIcon (18pt grid), scaled up and centred.
    ctx.translateBy(x: 512 - 9 * 36, y: 512 - 9 * 36)
    ctx.scaleBy(x: 36, y: 36)
    NSColor.white.setStroke()
    NSColor.white.setFill()
    let body = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 1.5, width: 10, height: 9), xRadius: 2.2, yRadius: 2.2)
    body.lineWidth = 1.5
    body.stroke()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: 12.5, y: 8.5))
    handle.curve(to: NSPoint(x: 12.5, y: 3.5), controlPoint1: NSPoint(x: 17, y: 8.5), controlPoint2: NSPoint(x: 17, y: 3.5))
    handle.lineWidth = 1.5
    handle.lineCapStyle = .round
    handle.stroke()
    NSBezierPath(roundedRect: NSRect(x: 4, y: 3, width: 7, height: 5), xRadius: 1, yRadius: 1).fill()
    for x in [5.0, 9.0] {
        let steam = NSBezierPath()
        steam.move(to: NSPoint(x: x, y: 12))
        steam.curve(to: NSPoint(x: x, y: 17), controlPoint1: NSPoint(x: x + 2, y: 13.7), controlPoint2: NSPoint(x: x - 2, y: 15.3))
        steam.lineWidth = 1.3
        steam.lineCapStyle = .round
        steam.stroke()
    }
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
