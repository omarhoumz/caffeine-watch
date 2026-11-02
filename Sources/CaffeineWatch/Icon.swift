import AppKit

/// Template menu bar icon: a mug that is steaming (caffeinate), full (another app), or empty (idle),
/// optionally followed by text. The text is drawn into the image because a MenuBarExtra label
/// shows only its image when given an image and a text.
enum MenuBarIcon {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    static func image(for state: WakeState, text: String? = nil) -> NSImage {
        let label = text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black]) }
        let textWidth = label.map { ceil($0.size().width) + 3 } ?? 0
        let size = NSSize(width: 18 + textWidth, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            if let label {
                label.draw(at: NSPoint(x: 21, y: (18 - label.size().height) / 2))
            }
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let body = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 1.5, width: 10, height: 9), xRadius: 2.2, yRadius: 2.2)
            body.lineWidth = 1.5
            body.stroke()

            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: 12.5, y: 8.5))
            handle.curve(to: NSPoint(x: 12.5, y: 3.5), controlPoint1: NSPoint(x: 17, y: 8.5), controlPoint2: NSPoint(x: 17, y: 3.5))
            handle.lineWidth = 1.5
            handle.lineCapStyle = .round
            handle.stroke()

            if state != .idle {
                NSBezierPath(roundedRect: NSRect(x: 4, y: 3, width: 7, height: 5), xRadius: 1, yRadius: 1).fill()
            }

            if state == .caffeinate {
                for x in [5.0, 9.0] {
                    let steam = NSBezierPath()
                    steam.move(to: NSPoint(x: x, y: 12))
                    steam.curve(to: NSPoint(x: x, y: 17), controlPoint1: NSPoint(x: x + 2, y: 13.7), controlPoint2: NSPoint(x: x - 2, y: 15.3))
                    steam.lineWidth = 1.3
                    steam.lineCapStyle = .round
                    steam.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
