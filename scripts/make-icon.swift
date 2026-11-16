// Renders the Gõ Dấu app icon: a warm squircle with a cream keycap that carries "ấ".
// Usage: swift scripts/make-icon.swift <output.png> [size]
// scripts/make-icon.sh turns the 1024 px render into Apps/VietMac/AppIcon.icns.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png> [size]\n".data(using: .utf8)!)
    exit(2)
}
let size = arguments.count >= 3 ? CGFloat(Double(arguments[2]) ?? 1024) : 1024
let scale = size / 1024

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext
context.scaleBy(x: scale, y: scale)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// macOS icon grid: 824 pt body centered on a 1024 pt canvas, continuous-corner radius about 185.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Drop shadow under the body.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28).cgColor)
color(0xC2272D).setFill()
bodyPath.fill()
context.restoreGState()

// Warm red to orange gradient, lighter at the top.
NSGradient(colors: [color(0xF2683A), color(0xD8352F), color(0xB51F2E)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: bodyPath, angle: -90)

// Keycap: a raised cream key with a darker skirt below it.
let skirt = NSRect(x: 232, y: 214, width: 560, height: 560)
let skirtPath = NSBezierPath(roundedRect: skirt, xRadius: 120, yRadius: 120)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: color(0x5A0A12, 0.45).cgColor)
color(0xE9D9C2).setFill()
skirtPath.fill()
context.restoreGState()

let cap = NSRect(x: 252, y: 262, width: 520, height: 500)
let capPath = NSBezierPath(roundedRect: cap, xRadius: 104, yRadius: 104)
NSGradient(colors: [color(0xFFFBF3), color(0xF6EAD8)], atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(in: capPath, angle: -90)

// The glyph: "ấ", a vowel with both a circumflex and an acute tone mark.
let font: NSFont = {
    let base = NSFont.systemFont(ofSize: 330, weight: .bold)
    if let rounded = base.fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: rounded, size: 330) {
        return font
    }
    return base
}()
// Center the ink, marks included: CTLine image bounds cover the circumflex and the acute.
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "ấ", attributes: [
    .font: font, .foregroundColor: color(0xB51F2E)]))
let ink = CTLineGetImageBounds(line, context)
context.textPosition = CGPoint(x: cap.midX - ink.width / 2 - ink.minX,
                               y: cap.midY - ink.height / 2 - ink.minY)
CTLineDraw(line, context)

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: arguments[1]))
