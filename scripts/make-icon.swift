import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for baseSize in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = baseSize * scale
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
    NSBezierPath(
      roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204
    ).fill()
    NSColor(calibratedWhite: 0.97, alpha: 1).setStroke()
    let corners: [[NSPoint]] = [
      [NSPoint(x: 416, y: 746), NSPoint(x: 278, y: 746), NSPoint(x: 278, y: 608)],
      [NSPoint(x: 608, y: 746), NSPoint(x: 746, y: 746), NSPoint(x: 746, y: 608)],
      [NSPoint(x: 278, y: 416), NSPoint(x: 278, y: 278), NSPoint(x: 416, y: 278)],
      [NSPoint(x: 746, y: 416), NSPoint(x: 746, y: 278), NSPoint(x: 608, y: 278)],
    ]
    for points in corners {
      let path = NSBezierPath()
      path.lineWidth = 49
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      path.move(to: points[0])
      path.line(to: points[1])
      path.line(to: points[2])
      path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let file = outputDirectory.appendingPathComponent("icon_\(baseSize)x\(baseSize)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: file)
  }
}
