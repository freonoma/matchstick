import AppKit

// Draws the app icon and writes it as an .icns file: `make icon`.
//
// The match comes from MatchIcon, the same code that draws the menu bar icon,
// so the two always show the same match.

/// Colors as 0xRRGGBB. Gradients run from top to bottom.
enum Palette {
    static let plate = [color(0x34343A), color(0x17171A)]
    static let match = [color(0xF2E9DC)]
    static let flame = [color(0xFFD60A), color(0xFF6A1A)]
}

/// Measurements for a 1024 x 1024 icon, following the usual macOS shape: a
/// rounded square that leaves a margin for its shadow.
enum Layout {
    static let canvas: CGFloat = 1024
    static let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let plateRadius: CGFloat = 185.4
    /// The square the 18 x 18 point match drawing is scaled up into.
    static let glyphSide: CGFloat = 600
}

func color(_ rgb: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    // A gradient needs two stops, so a single color is used twice.
    let stops = colors.count > 1 ? colors : colors + colors
    return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops as CFArray,
                      locations: nil)!
}

func makeBitmap(side: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

/// The match as it would sit on an icon of this size, drawn in black.
func matchShape(isLit: Bool, side: Int, in glyph: CGRect) -> NSBitmapImageRep {
    let bitmap = makeBitmap(side: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    MatchIcon(isLit: isLit).image.draw(in: glyph)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

/// Fills `shape` with a gradient that runs over the rows from `top` down to
/// `bottom`, leaving out wherever `hole` has ink.
func colored(_ shape: NSBitmapImageRep, minus hole: NSBitmapImageRep? = nil,
             with colors: [CGColor], from top: CGFloat, to bottom: CGFloat) -> CGImage {
    let bitmap = makeBitmap(side: shape.pixelsWide)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    let bounds = CGRect(x: 0, y: 0, width: shape.pixelsWide, height: shape.pixelsHigh)

    context.draw(shape.cgImage!, in: bounds)
    if let hole {
        // Subtract the hole's ink pixel by pixel. Erasing it with a blend mode
        // multiplies instead, which leaves a thin line of this color along
        // every soft edge the two shapes share.
        let ink = bitmap.bitmapData!, holeInk = hole.bitmapData!
        for alpha in stride(from: 3, to: bitmap.bytesPerRow * bitmap.pixelsHigh, by: 4) {
            ink[alpha] -= min(ink[alpha], holeInk[alpha])
        }
    }
    context.setBlendMode(.sourceIn)
    context.drawLinearGradient(gradient(colors), start: CGPoint(x: 0, y: top),
                               end: CGPoint(x: 0, y: bottom),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    return bitmap.cgImage!
}

func drawIcon(side: Int) -> NSBitmapImageRep {
    let bitmap = makeBitmap(side: side)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    // Everything below is measured for the 1024 point canvas.
    let scale = CGFloat(side) / Layout.canvas
    let toPixels = CGAffineTransform(scaleX: scale, y: scale)

    let plateRect = Layout.plate.applying(toPixels)
    let radius = Layout.plateRadius * scale
    let plate = CGPath(roundedRect: plateRect, cornerWidth: radius, cornerHeight: radius,
                       transform: nil)

    // A soft shadow under the plate, then the plate itself.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 20 * scale,
                      color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(plate)
    context.setFillColor(Palette.plate[0])
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(plate)
    context.clip()
    context.drawLinearGradient(gradient(Palette.plate), start: CGPoint(x: 0, y: plateRect.maxY),
                               end: CGPoint(x: 0, y: plateRect.minY), options: [])
    context.restoreGState()

    // The lit match has the unlit match inside it, in the same place. Taking
    // the unlit one out of it leaves just the flame.
    // On whole pixels, or the small sizes come out blurred and off center.
    let glyphSide = Layout.glyphSide * scale
    let glyph = CGRect(x: bounds.midX - glyphSide / 2, y: bounds.midY - glyphSide / 2,
                       width: glyphSide, height: glyphSide).integral
    let lit = matchShape(isLit: true, side: side, in: glyph)
    let unlit = matchShape(isLit: false, side: side, in: glyph)

    context.draw(colored(unlit, with: Palette.match, from: glyph.maxY, to: glyph.minY), in: bounds)
    // The flame fills the top 60 percent of the drawing.
    context.draw(colored(lit, minus: unlit, with: Palette.flame,
                         from: glyph.maxY, to: glyph.maxY - glyph.height * 0.6), in: bounds)
    return bitmap
}

// An .icns file is built from a folder of PNGs with these exact names.
let sizes: [(name: String, pixels: Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
]

guard CommandLine.arguments.count == 2 else {
    print("usage: appicon <output.icns>")
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Matchstick.iconset")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in sizes {
    let png = drawIcon(side: size.pixels).representation(using: .png, properties: [:])!
    try png.write(to: iconset.appendingPathComponent("icon_\(size.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", output.path, iconset.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
