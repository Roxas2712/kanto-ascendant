#!/usr/bin/env swift

import AppKit
import Foundation

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let source = root.appendingPathComponent(
    "assets/sources/gorochu/gorochu_sprite_reference.png")
private let raichuExpressionSource = root.appendingPathComponent(
    "assets/sources/raichu/raichu_expression_reference.png")
private let canvas = 56
private let dex = 1026

private struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
}

private struct Bounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

private struct Region {
    let box: Bounds
    let background: Set<Int>
}

private struct View {
    let side: String
    let variant: String
    let originX: Int
    let originY: Int
}

private let normalPalette = [
    RGBA(r: 0.16, g: 0.10, b: 0.10, a: 1),
    RGBA(r: 0.30, g: 0.18, b: 0.17, a: 1),
    RGBA(r: 0.90, g: 0.27, b: 0.14, a: 1),
    RGBA(r: 1.00, g: 0.67, b: 0.16, a: 1),
    RGBA(r: 1.00, g: 0.90, b: 0.72, a: 1),
]

private let shinyPalette = [
    RGBA(r: 0.08, g: 0.11, b: 0.15, a: 1),
    RGBA(r: 0.16, g: 0.20, b: 0.26, a: 1),
    RGBA(r: 0.39, g: 0.44, b: 0.50, a: 1),
    RGBA(r: 0.96, g: 0.61, b: 0.13, a: 1),
    RGBA(r: 1.00, g: 0.88, b: 0.68, a: 1),
]

private func bitmap(width: Int, height: Int) -> NSBitmapImageRep {
    guard let image = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaNonpremultiplied,
        bytesPerRow: width * 4,
        bitsPerPixel: 32
    ) else {
        fatalError("Could not allocate \(width)x\(height) bitmap")
    }
    image.size = NSSize(width: width, height: height)
    let transparent = NSColor(
        deviceRed: 0, green: 0, blue: 0, alpha: 0)
    for y in 0..<height {
        for x in 0..<width {
            image.setColor(transparent, atX: x, y: y)
        }
    }
    return image
}

private func rgba(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> RGBA {
    guard let color = image.colorAt(x: x, y: y)?
        .usingColorSpace(.deviceRGB) else {
        return RGBA(r: 0, g: 0, b: 0, a: 0)
    }
    return RGBA(
        r: color.redComponent,
        g: color.greenComponent,
        b: color.blueComponent,
        a: color.alphaComponent)
}

private func nearest(_ color: RGBA, palette: [RGBA]) -> RGBA {
    var best = palette[0]
    var bestDistance = CGFloat.greatestFiniteMagnitude
    for candidate in palette {
        let red = color.r - candidate.r
        let green = color.g - candidate.g
        let blue = color.b - candidate.b
        let distance = red * red * 0.30
            + green * green * 0.59
            + blue * blue * 0.11
        if distance < bestDistance {
            bestDistance = distance
            best = candidate
        }
    }
    return best
}

private func nearestIndex(_ color: RGBA, palette: [RGBA]) -> Int {
    var best = 0
    var bestDistance = CGFloat.greatestFiniteMagnitude
    for (index, candidate) in palette.enumerated() {
        let red = color.r - candidate.r
        let green = color.g - candidate.g
        let blue = color.b - candidate.b
        let distance = red * red * 0.30
            + green * green * 0.59
            + blue * blue * 0.11
        if distance < bestDistance {
            bestDistance = distance
            best = index
        }
    }
    return best
}

private func isGreenChroma(_ color: RGBA) -> Bool {
    // The supplied Raichu sheet uses a saturated green screen. JPEG-style
    // edge blending leaves darker green pixels that are not equal to the
    // original background color, so reject green-dominant spill as well as
    // the pure key. Raichu's intended palette has no green.
    let strongestOther = max(color.r, color.b)
    return color.a < 0.20
        || (color.g >= 0.05
            && color.g >= strongestOther * 1.08
            && color.g - color.r >= 0.025
            && color.g - color.b >= 0.025)
}

private func bounds(
    _ image: NSBitmapImageRep,
    originX: Int,
    originY: Int,
    width: Int,
    height: Int
) -> Bounds {
    var found = Bounds(
        minX: originX + width,
        minY: originY + height,
        maxX: originX - 1,
        maxY: originY - 1)
    for y in originY..<(originY + height) {
        for x in originX..<(originX + width) {
            if rgba(image, x, y).a >= 0.20 {
                found.minX = min(found.minX, x)
                found.minY = min(found.minY, y)
                found.maxX = max(found.maxX, x)
                found.maxY = max(found.maxY, y)
            }
        }
    }
    guard found.maxX >= found.minX, found.maxY >= found.minY else {
        fatalError("No visible sprite in quadrant \(originX),\(originY)")
    }
    return found
}

private func region(
    _ image: NSBitmapImageRep,
    originX: Int,
    originY: Int,
    width: Int,
    height: Int
) -> Region {
    func key(_ x: Int, _ y: Int) -> Int {
        y * image.pixelsWide + x
    }
    func isOutside(_ color: RGBA) -> Bool {
        let white = color.r >= 0.93
            && color.g >= 0.93 && color.b >= 0.93
        let magenta = color.r >= 0.78
            && color.g <= 0.30 && color.b >= 0.72
        return color.a < 0.20 || white || magenta
            || isGreenChroma(color)
    }

    var background = Set<Int>()
    var queue: [(Int, Int)] = []
    func seed(_ x: Int, _ y: Int) {
        let id = key(x, y)
        if !background.contains(id) && isOutside(rgba(image, x, y)) {
            background.insert(id)
            queue.append((x, y))
        }
    }
    for x in originX..<(originX + width) {
        seed(x, originY)
        seed(x, originY + height - 1)
    }
    for y in originY..<(originY + height) {
        seed(originX, y)
        seed(originX + width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let (x, y) = queue[cursor]
        cursor += 1
        for (nx, ny) in [(x - 1, y), (x + 1, y),
                         (x, y - 1), (x, y + 1)] {
            guard nx >= originX, nx < originX + width,
                  ny >= originY, ny < originY + height else { continue }
            let id = key(nx, ny)
            if !background.contains(id) && isOutside(rgba(image, nx, ny)) {
                background.insert(id)
                queue.append((nx, ny))
            }
        }
    }

    var found = Bounds(
        minX: originX + width,
        minY: originY + height,
        maxX: originX - 1,
        maxY: originY - 1)
    for y in originY..<(originY + height) {
        for x in originX..<(originX + width) {
            let color = rgba(image, x, y)
            if color.a >= 0.20 && !background.contains(key(x, y)) {
                found.minX = min(found.minX, x)
                found.minY = min(found.minY, y)
                found.maxX = max(found.maxX, x)
                found.maxY = max(found.maxY, y)
            }
        }
    }
    guard found.maxX >= found.minX, found.maxY >= found.minY else {
        fatalError("No foreground sprite in quadrant \(originX),\(originY)")
    }
    return Region(box: found, background: background)
}

private func fitted(
    _ source: NSBitmapImageRep,
    region: Region,
    palette: [RGBA]
) -> NSBitmapImageRep {
    let box = region.box
    let output = bitmap(width: canvas, height: canvas)
    let scale = min(
        CGFloat(canvas - 4) / CGFloat(box.width),
        CGFloat(canvas - 4) / CGFloat(box.height))
    let drawWidth = max(1, Int((CGFloat(box.width) * scale).rounded()))
    let drawHeight = max(1, Int((CGFloat(box.height) * scale).rounded()))
    let offsetX = (canvas - drawWidth) / 2
    let offsetY = 1

    for y in 0..<drawHeight {
        for x in 0..<drawWidth {
            let sourceX = min(
                box.maxX,
                box.minX + Int((CGFloat(x) + 0.5) / scale))
            let sourceY = min(
                box.maxY,
                box.minY + Int((CGFloat(y) + 0.5) / scale))
            let sampled = rgba(source, sourceX, sourceY)
            let sourceKey = sourceY * source.pixelsWide + sourceX
            guard sampled.a >= 0.20,
                  !region.background.contains(sourceKey) else { continue }
            let color = nearest(sampled, palette: palette)
            output.setColor(NSColor(
                deviceRed: color.r,
                green: color.g,
                blue: color.b,
                alpha: 1), atX: offsetX + x, y: offsetY + y)
        }
    }
    return output
}

private func correctedBattleFace(
    _ image: NSBitmapImageRep,
    palette: [RGBA]
) {
    // The source illustration has a good silhouette, but nearest-neighbour
    // reduction made its eyes and open mouth collapse into three oversized
    // square blocks. Rebuild only the 56 px front face with deliberate Gen-II
    // pixel clusters. The body sample keeps the same correction valid for the
    // normal and shiny palettes.
    let body = rgba(image, 20, 17)
    let bodyColor = NSColor(
        deviceRed: body.r, green: body.g, blue: body.b, alpha: 1)
    let darkest = palette[0]
    let darkColor = NSColor(
        deviceRed: darkest.r,
        green: darkest.g,
        blue: darkest.b,
        alpha: 1)
    let accent = palette[2]
    let accentColor = NSColor(
        deviceRed: accent.r,
        green: accent.g,
        blue: accent.b,
        alpha: 1)
    let cream = palette[4]
    let creamColor = NSColor(
        deviceRed: cream.r,
        green: cream.g,
        blue: cream.b,
        alpha: 1)

    // Remove the generated face without changing the head silhouette.
    for y in 18...29 {
        for x in 11...27 where rgba(image, x, y).a >= 0.20 {
            image.setColor(bodyColor, atX: x, y: y)
        }
    }

    func pixels(_ points: [(Int, Int)], _ color: NSColor) {
        for point in points {
            image.setColor(color, atX: point.0, y: point.1)
        }
    }

    // Inward-sloping brows and tiny triangular eyes. The single cream pixels
    // read as eye whites at native scale without becoming blank square eyes.
    pixels([
        (12, 20), (13, 20), (14, 21), (15, 21),
        (23, 21), (24, 21), (25, 20), (26, 20),
        (13, 22), (14, 22), (24, 22), (25, 22),
    ], darkColor)
    pixels([(13, 21), (25, 21)], creamColor)

    // Cheek sparks and a compact central nose.
    pixels([
        (11, 24), (12, 24), (12, 25),
        (26, 24), (27, 24), (26, 25),
    ], accentColor)
    pixels([(19, 23), (20, 23)], darkColor)

    // Small angular open grin with exactly two readable upper fangs.
    pixels([
        (16, 24), (23, 24),
        (16, 25), (17, 25), (18, 25), (19, 25),
        (20, 25), (21, 25), (22, 25), (23, 25),
        (17, 26), (18, 26), (19, 26), (20, 26),
        (21, 26), (22, 26),
        (18, 27), (19, 27), (20, 27), (21, 27),
    ], darkColor)
    pixels([(17, 25), (22, 25)], creamColor)
    pixels([(19, 26), (20, 26)], accentColor)
}

private func fittedPortrait(
    _ source: NSBitmapImageRep,
    box: Bounds,
    palette: [RGBA],
    sourcePalette: [RGBA]
) -> NSBitmapImageRep {
    let portraitCanvas = 40
    let output = bitmap(width: portraitCanvas, height: portraitCanvas)
    let scale = min(
        CGFloat(portraitCanvas - 2) / CGFloat(box.width),
        CGFloat(portraitCanvas - 2) / CGFloat(box.height))
    let drawWidth = max(1, Int((CGFloat(box.width) * scale).rounded()))
    let drawHeight = max(1, Int((CGFloat(box.height) * scale).rounded()))
    let offsetX = (portraitCanvas - drawWidth) / 2
    let offsetY = 1

    for y in 0..<drawHeight {
        for x in 0..<drawWidth {
            let sourceX = min(
                box.maxX,
                box.minX + Int((CGFloat(x) + 0.5) / scale))
            let sourceY = min(
                box.maxY,
                box.minY + Int((CGFloat(y) + 0.5) / scale))
            let sampled = rgba(source, sourceX, sourceY)
            guard sampled.a >= 0.20 else { continue }
            let index = nearestIndex(sampled, palette: sourcePalette)
            let color = palette[index]
            output.setColor(NSColor(
                deviceRed: color.r,
                green: color.g,
                blue: color.b,
                alpha: 1), atX: offsetX + x, y: offsetY + y)
        }
    }
    return output
}

private func raichuShiny(_ color: RGBA) -> RGBA {
    // The supplied normal portraits already carry clean, intentional
    // true-color art. Only the orange/red family changes for shiny Raichu;
    // outline, eyes, cream belly and brown ears stay readable and stable.
    if color.r > 0.70 && color.r > color.g * 1.45
        && color.g < 0.48 && color.b < 0.40 {
        return RGBA(r: 0.72, g: 0.52, b: 0.06, a: color.a)
    }
    if color.r > 0.78 && color.g > 0.30 && color.b < 0.28 {
        let light = max(0, min(1, (color.r + color.g) * 0.5))
        return light > 0.72
            ? RGBA(r: 0.78, g: 0.63, b: 0.08, a: color.a)
            : RGBA(r: 0.56, g: 0.43, b: 0.04, a: color.a)
    }
    return color
}

private func fittedTrueColorPortrait(
    _ source: NSBitmapImageRep,
    region: Region,
    shiny: Bool
) -> NSBitmapImageRep {
    let portraitCanvas = 40
    let box = region.box
    let output = bitmap(width: portraitCanvas, height: portraitCanvas)
    let scale = min(
        CGFloat(portraitCanvas - 2) / CGFloat(box.width),
        CGFloat(portraitCanvas - 2) / CGFloat(box.height))
    let drawWidth = max(1, Int((CGFloat(box.width) * scale).rounded()))
    let drawHeight = max(1, Int((CGFloat(box.height) * scale).rounded()))
    let offsetX = (portraitCanvas - drawWidth) / 2
    let offsetY = 1

    for y in 0..<drawHeight {
        for x in 0..<drawWidth {
            let sourceX = min(
                box.maxX,
                box.minX + Int((CGFloat(x) + 0.5) / scale))
            let sourceY = min(
                box.maxY,
                box.minY + Int((CGFloat(y) + 0.5) / scale))
            let sourceKey = sourceY * source.pixelsWide + sourceX
            let sampled = rgba(source, sourceX, sourceY)
            guard sampled.a >= 0.20,
                  !region.background.contains(sourceKey),
                  !isGreenChroma(sampled) else { continue }
            let color = shiny ? raichuShiny(sampled) : sampled
            output.setColor(NSColor(
                deviceRed: color.r,
                green: color.g,
                blue: color.b,
                alpha: color.a), atX: offsetX + x, y: offsetY + y)
        }
    }
    return output
}

private func copy(
    _ source: NSBitmapImageRep,
    dx: Int = 0,
    dy: Int = 0
) -> NSBitmapImageRep {
    let output = bitmap(width: source.pixelsWide, height: source.pixelsHigh)
    for y in 0..<source.pixelsHigh {
        for x in 0..<source.pixelsWide {
            let color = rgba(source, x, y)
            guard color.a >= 0.20 else { continue }
            let targetX = x + dx
            let targetY = y + dy
            guard targetX >= 0, targetX < output.pixelsWide,
                  targetY >= 0, targetY < output.pixelsHigh else { continue }
            output.setColor(NSColor(
                deviceRed: color.r,
                green: color.g,
                blue: color.b,
                alpha: color.a), atX: targetX, y: targetY)
        }
    }
    return output
}

private func withSparks(
    _ source: NSBitmapImageRep,
    shiny: Bool,
    phase: Int
) -> NSBitmapImageRep {
    let output = copy(source)
    let gold = shiny
        ? NSColor(deviceRed: 0.96, green: 0.61, blue: 0.13, alpha: 1)
        : NSColor(deviceRed: 1.00, green: 0.67, blue: 0.16, alpha: 1)
    let points = phase == 1
        ? [(7, 38), (8, 39), (46, 43), (47, 42)]
        : [(10, 47), (11, 46), (49, 31), (48, 32)]
    for (x, y) in points where x >= 0 && x < canvas && y >= 0 && y < canvas {
        if rgba(output, x, y).a < 0.20 {
            output.setColor(gold, atX: x, y: y)
        }
    }
    return output
}

private func save(_ image: NSBitmapImageRep, _ relative: String) {
    let url = root.appendingPathComponent(relative)
    try! FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    guard let data = image.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(relative)")
    }
    try! data.write(to: url)
}

private func scaledIcon(
    _ source: NSBitmapImageRep,
    maxSize: Int = 14
) -> NSBitmapImageRep {
    let box = bounds(
        source,
        originX: 0,
        originY: 0,
        width: source.pixelsWide,
        height: source.pixelsHigh)
    let output = bitmap(width: 16, height: 16)
    let scale = min(
        CGFloat(maxSize) / CGFloat(box.width),
        CGFloat(maxSize) / CGFloat(box.height))
    let drawWidth = max(1, Int((CGFloat(box.width) * scale).rounded()))
    let drawHeight = max(1, Int((CGFloat(box.height) * scale).rounded()))
    let offsetX = (16 - drawWidth) / 2
    let offsetY = 1
    for y in 0..<drawHeight {
        for x in 0..<drawWidth {
            let sourceX = min(
                box.maxX,
                box.minX + Int((CGFloat(x) + 0.5) / scale))
            let sourceY = min(
                box.maxY,
                box.minY + Int((CGFloat(y) + 0.5) / scale))
            guard let color = source.colorAt(x: sourceX, y: sourceY),
                  color.alphaComponent >= 0.20 else { continue }
            output.setColor(color, atX: offsetX + x, y: offsetY + y)
        }
    }
    return output
}

private func follower(
    front: NSBitmapImageRep,
    back: NSBitmapImageRep
) -> NSBitmapImageRep {
    let output = bitmap(width: 16, height: 96)
    let down = scaledIcon(front)
    let up = scaledIcon(back)
    let frames = [
        (down, 0), (up, 0), (down, 0),
        (down, 1), (up, 1), (down, -1),
    ]
    for (index, row) in frames.enumerated() {
        let frame = row.0
        for y in 0..<16 {
            for x in 0..<16 {
                guard let color = frame.colorAt(x: x, y: y),
                      color.alphaComponent >= 0.20 else { continue }
                let targetX = x + row.1
                guard targetX >= 0, targetX < 16 else { continue }
                output.setColor(color, atX: targetX, y: index * 16 + y)
            }
        }
    }
    return output
}

guard let data = try? Data(contentsOf: source),
      let input = NSBitmapImageRep(data: data) else {
    fatalError("Missing source \(source.path)")
}

private let halfWidth = input.pixelsWide / 2
private let halfHeight = input.pixelsHigh / 2
private let views = [
    View(side: "front", variant: "normal",
         originX: 0, originY: 0),
    View(side: "back", variant: "normal",
         originX: halfWidth, originY: 0),
    View(side: "front", variant: "shiny",
         originX: 0, originY: halfHeight),
    View(side: "back", variant: "shiny",
         originX: halfWidth, originY: halfHeight),
]

var rendered: [String: NSBitmapImageRep] = [:]
for view in views {
    let crop = region(
        input,
        originX: view.originX,
        originY: view.originY,
        width: halfWidth,
        height: halfHeight)
    let palette = view.variant == "shiny" ? shinyPalette : normalPalette
    let image = fitted(input, region: crop, palette: palette)
    if view.side == "front" {
        correctedBattleFace(image, palette: palette)
    }
    let key = "\(view.side)_\(view.variant)"
    rendered[key] = image

    let suffix = view.variant == "shiny" ? "_shiny" : ""
    save(image, "assets/crystal/gorochu_\(view.side)\(suffix).png")

    let animation = [
        image,
        withSparks(image, shiny: view.variant == "shiny", phase: 1),
        copy(image, dy: 1),
        image,
        withSparks(image, shiny: view.variant == "shiny", phase: 2),
        copy(image, dy: 1),
    ]
    for (index, frame) in animation.enumerated() {
        save(frame, String(format:
            "assets/crystal_animated/%@/%@/%d/%03d.png",
            view.side, view.variant, dex, index + 1))
    }
}

for variant in ["normal", "shiny"] {
    let sheet = follower(
        front: rendered["front_\(variant)"]!,
        back: rendered["back_\(variant)"]!)
    save(sheet,
         "assets/followers_runtime/\(variant)/follower_GOROCHU.png")
}

private let expressionSource = root.appendingPathComponent(
    "assets/sources/gorochu/gorochu_expression_reference.png")
guard let expressionData = try? Data(contentsOf: expressionSource),
      let expressionInput = NSBitmapImageRep(data: expressionData) else {
    fatalError("Missing source \(expressionSource.path)")
}

private let expressionNames = [
    "sleepy", "unwell", "upset", "wary",
    "content", "devoted", "excited",
]
private let expressionWidth = expressionInput.pixelsWide / 4
private let expressionHeight = expressionInput.pixelsHigh / 2

for (index, name) in expressionNames.enumerated() {
    let column = index % 4
    let visualRow = index / 4
    let originY = visualRow * expressionHeight
    let crop = bounds(
        expressionInput,
        originX: column * expressionWidth,
        originY: originY,
        width: expressionWidth,
        height: expressionHeight)

    for variant in ["normal", "shiny"] {
        let targetPalette = variant == "shiny"
            ? shinyPalette : normalPalette
        let portrait = fittedPortrait(
            expressionInput,
            box: crop,
            palette: targetPalette,
            sourcePalette: normalPalette)
        let frames = [
            portrait,
            copy(portrait, dy: 1),
            copy(portrait, dx: index % 2 == 0 ? 1 : -1),
        ]
        for (frameIndex, frame) in frames.enumerated() {
            save(frame, String(format:
                "assets/yellow_partner_gorochu_portraits/%@/%@/%03d.png",
                variant, name, frameIndex + 1))
        }
    }
}

guard let raichuExpressionData = try? Data(
          contentsOf: raichuExpressionSource),
      let raichuExpressionInput = NSBitmapImageRep(
          data: raichuExpressionData) else {
    fatalError("Missing source \(raichuExpressionSource.path)")
}

private let raichuExpressionWidth =
    raichuExpressionInput.pixelsWide / 4
private let raichuExpressionHeight =
    raichuExpressionInput.pixelsHigh / 2

for (index, name) in expressionNames.enumerated() {
    let column = index % 4
    let visualRow = index / 4
    let crop = region(
        raichuExpressionInput,
        originX: column * raichuExpressionWidth,
        originY: visualRow * raichuExpressionHeight,
        width: raichuExpressionWidth,
        height: raichuExpressionHeight)

    for variant in ["normal", "shiny"] {
        let portrait = fittedTrueColorPortrait(
            raichuExpressionInput,
            region: crop,
            shiny: variant == "shiny")
        let frames = [
            portrait,
            copy(portrait, dy: 1),
            copy(portrait, dx: index % 2 == 0 ? 1 : -1),
        ]
        for (frameIndex, frame) in frames.enumerated() {
            save(frame, String(format:
                "assets/yellow_partner_raichu_portraits/%@/%@/%03d.png",
                variant, name, frameIndex + 1))
        }
    }
}

print("""
Built Gorochu front/back, shiny, six-frame animation, followers and \
seven animated Gorochu/Raichu partner expressions.
""")
