//
//  IconGenerator.swift
//  Needle Works
//
//  Copyright 2026 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.

// Makes the app icon: a letter satin-stitched on cloth in a wooden
// embroidery hoop, drawn with Needle Works' own Realistic thread and fabric.
// It is built together with NeedleWorksKit's sources; see make-icon.sh.
//
// usage: IconGenerator <font.ttf> <output .iconset directory> [seed]
//
// The same font and seed always give the same icon.

import AppKit
import CoreText

// MARK: - Settings

/// The letter, and its thread and fabric colors (sRGB, 0–255)
let letter = "N"
let threadColor = (r: 16, g: 30, b: 78)
let fabricColor = (r: 245, g: 242, b: 235)

/// The letter's largest size, in design units (0.1 mm)
let letterSize = CGSize(width: 600, height: 460)

/// Satin stitches are about this far apart, in design units
let stitchSpacing = 1.9

/// The 1024-pixel canvas: the rounded square macOS icons sit in, the hoop,
/// and how many pixels a design unit covers
let canvas: CGFloat = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileCorner: CGFloat = 185
let hoopCenter = CGPoint(x: 512, y: 528)
let hoopOuterRadius: CGFloat = 352
let hoopInnerRadius: CGFloat = 302
let pixelsPerUnit: CGFloat = 0.78

// MARK: - Repeatable randomness

/// SplitMix64, so the same seed always gives the same icon
struct SeededRandom: RandomNumberGenerator {
	var state: UInt64

	mutating func next() -> UInt64 {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		return z ^ (z >> 31)
	}
}

/// Every random choice comes from here; main seeds it
var random = SeededRandom(state: 1)

// MARK: - Satin stitches for a glyph

/// The glyph's outline, `size` at most, centered on the origin, y down
func glyphPath(fontURL: URL, character: String, size: CGSize) -> CGPath {
	guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
		  let descriptor = descriptors.first else {
		fatalError("Can't read the font at \(fontURL.path)")
	}
	let font = CTFontCreateWithFontDescriptor(descriptor, 1000, nil)
	var characters = Array(character.utf16), glyphs = [CGGlyph](repeating: 0, count: characters.count)
	CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
	guard let raw = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
		fatalError("The font has no outline for \(character)")
	}
	let bounds = raw.boundingBoxOfPath
	let scale = min(size.width / bounds.width, size.height / bounds.height)
	var transform = CGAffineTransform(scaleX: scale, y: -scale).translatedBy(x: -bounds.midX, y: -bounds.midY)
	return raw.copy(using: &transform)!
}

/// Satin stitches filling `path`, each crossing the stroke from edge to edge
/// at right angles to it, turning with its curves as a digitizer's would.
///
/// The outline is rasterized at one cell per design unit. An exact distance
/// transform finds the middle of each stroke, and the smoothed structure
/// tensor of its gradient gives the direction across it. Stitches are seeded
/// along the stroke middles. Where strokes join, and in serifs, that direction
/// can run along a stroke instead, making a stitch far longer than the stroke
/// is wide. Those seeds are stitched instead along the shortest line across
/// the letter through them, as a digitizer stitches a serif across its short
/// side, and any part of the letter still bare gets stitches of its own the
/// same way, so there are no gaps.
func satinStitches(for path: CGPath) -> [(CGPoint, CGPoint)] {
	let pad = 4
	let bounds = path.boundingBoxOfPath
	let W = Int(bounds.width.rounded(.up)) + pad * 2, H = Int(bounds.height.rounded(.up)) + pad * 2
	let origin = CGPoint(x: bounds.minX - CGFloat(pad), y: bounds.minY - CGFloat(pad))

	/* The letter as a mask, memory rows top down, as y runs down */
	let maskContext = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
								space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
	maskContext.translateBy(x: 0, y: CGFloat(H))
	maskContext.scaleBy(x: 1, y: -1)
	maskContext.translateBy(x: -origin.x, y: -origin.y)
	maskContext.addPath(path)
	maskContext.setFillColor(gray: 1, alpha: 1)
	maskContext.fillPath()
	let mask = maskContext.data!.assumingMemoryBound(to: UInt8.self)
	func inside(_ x: Int, _ y: Int) -> Bool {
		x >= 0 && y >= 0 && x < W && y < H && mask[y * W + x] > 127
	}

	/* Exact Euclidean distance to the outside (Felzenszwalb and Huttenlocher) */
	let infinity = 1e12
	var f = [Double](repeating: 0, count: W * H)
	for y in 0..<H {
		for x in 0..<W {
			f[y * W + x] = inside(x, y) ? infinity : 0
		}
	}
	func distance1D(_ g: [Double]) -> [Double] {
		let n = g.count
		var d = [Double](repeating: 0, count: n), v = [Int](repeating: 0, count: n), z = [Double](repeating: 0, count: n + 1)
		var k = 0
		z[0] = -infinity
		z[1] = infinity
		func s(_ q: Int, _ p: Int) -> Double {
			((g[q] + Double(q * q)) - (g[p] + Double(p * p))) / Double(2 * q - 2 * p)
		}
		for q in 1..<n {
			var t = s(q, v[k])
			while t <= z[k] {
				k -= 1
				t = s(q, v[k])
			}
			k += 1
			v[k] = q
			z[k] = t
			z[k + 1] = infinity
		}
		k = 0
		for q in 0..<n {
			while z[k + 1] < Double(q) {
				k += 1
			}
			d[q] = Double((q - v[k]) * (q - v[k])) + g[v[k]]
		}
		return d
	}
	for x in 0..<W {
		let column = distance1D((0..<H).map { f[$0 * W + x] })
		for y in 0..<H {
			f[y * W + x] = column[y]
		}
	}
	for y in 0..<H {
		let row = distance1D(Array(f[(y * W)..<(y * W + W)]))
		for x in 0..<W {
			f[y * W + x] = row[x]
		}
	}
	let d = f.map { $0.squareRoot() }
	func D(_ x: Double, _ y: Double) -> Double {
		let xi = Int(x.rounded(.down)), yi = Int(y.rounded(.down))
		guard xi >= 0, yi >= 0, xi < W - 1, yi < H - 1 else {
			return 0
		}
		let fx = x - Double(xi), fy = y - Double(yi)
		return d[yi * W + xi] * (1 - fx) * (1 - fy) + d[yi * W + xi + 1] * fx * (1 - fy) +
			d[(yi + 1) * W + xi] * (1 - fx) * fy + d[(yi + 1) * W + xi + 1] * fx * fy
	}

	/* The direction across the stroke: the main axis of the smoothed
	 * structure tensor of the distance's gradient */
	var jxx = [Double](repeating: 0, count: W * H), jxy = jxx, jyy = jxx
	for y in 1..<(H - 1) {
		for x in 1..<(W - 1) {
			let gx = (d[y * W + x + 1] - d[y * W + x - 1]) / 2, gy = (d[(y + 1) * W + x] - d[(y - 1) * W + x]) / 2
			jxx[y * W + x] = gx * gx
			jxy[y * W + x] = gx * gy
			jyy[y * W + x] = gy * gy
		}
	}
	func blur(_ a: [Double], _ r: Int) -> [Double] {
		var tmp = a, out = a
		for y in 0..<H {
			var sum = 0.0
			for x in -r..<(W + r) {
				if x + r < W, x + r >= 0 { sum += a[y * W + x + r] }
				if x - r - 1 >= 0, x - r - 1 < W { sum -= a[y * W + x - r - 1] }
				if x >= 0, x < W { tmp[y * W + x] = sum }
			}
		}
		for x in 0..<W {
			var sum = 0.0
			for y in -r..<(H + r) {
				if y + r < H, y + r >= 0 { sum += tmp[(y + r) * W + x] }
				if y - r - 1 >= 0, y - r - 1 < H { sum -= tmp[(y - r - 1) * W + x] }
				if y >= 0, y < H { out[y * W + x] = sum }
			}
		}
		return out
	}
	jxx = blur(jxx, 10)
	jxy = blur(jxy, 10)
	jyy = blur(jyy, 10)
	func tensorAcross(_ x: Int, _ y: Int) -> Double {
		let i = y * W + x
		return 0.5 * atan2(2 * jxy[i], jxx[i] - jyy[i])
	}

	/* A stitch through a point at an angle, from edge to edge */
	func stitch(_ x: Double, _ y: Double, angle: Double) -> (CGPoint, CGPoint, Double) {
		let ex = cos(angle), ey = sin(angle)
		func edge(_ s: Double) -> CGPoint {
			var px = x, py = y
			while inside(Int(px + s * ex * 0.5), Int(py + s * ey * 0.5)) {
				px += s * ex * 0.5
				py += s * ey * 0.5
			}
			return CGPoint(x: px, y: py)
		}
		let a = edge(1), b = edge(-1)
		return (a, b, Double(hypot(a.x - b.x, a.y - b.y)))
	}

	/* A stitch that crosses the stroke is about as long as the stroke is wide,
	 * twice the distance to its edge */
	func crosses(_ length: Double, at x: Int, _ y: Int, leeway: Double) -> Bool {
		length > 1.5 && length < leeway * 2.6 * d[y * W + x] + 3
	}

	/* Seeds along the middle of each stroke, about a stitch apart */
	var ridge: [(Int, Int)] = []
	for y in 1..<(H - 1) {
		for x in 1..<(W - 1) where inside(x, y) {
			let dv = d[y * W + x]
			if dv < 1.2 {
				continue
			}
			let angle = tensorAcross(x, y), ex = cos(angle), ey = sin(angle)
			if dv >= D(Double(x) + ex, Double(y) + ey) - 0.02 && dv >= D(Double(x) - ex, Double(y) - ey) - 0.02 {
				ridge.append((x, y))
			}
		}
	}
	ridge.shuffle(using: &random)
	let cellSize = 2.0
	var seedGrid: [Int: [(Double, Double)]] = [:], seeds: [(Int, Int)] = []
	func key(_ x: Double, _ y: Double) -> Int {
		Int(x / cellSize) * 100_003 + Int(y / cellSize)
	}
	for (x, y) in ridge {
		let px = Double(x), py = Double(y)
		var free = true
		for dx in -1...1 {
			for dy in -1...1 {
				for (qx, qy) in seedGrid[key(px + Double(dx) * cellSize, py + Double(dy) * cellSize)] ?? [] where hypot(qx - px, qy - py) < stitchSpacing {
					free = false
				}
			}
		}
		if free {
			seeds.append((x, y))
			seedGrid[key(px, py), default: []].append((px, py))
		}
	}

	/* Stitch each seed across its stroke */
	struct Placed {
		var x: Double, y: Double, angle: Double, a: CGPoint, b: CGPoint
		var fill = false
	}
	var placed: [Placed] = [], retry: [(Int, Int)] = []
	for (x, y) in seeds {
		let angle = tensorAcross(x, y)
		let (a, b, length) = stitch(Double(x) + 0.5, Double(y) + 0.5, angle: angle)
		if crosses(length, at: x, y, leeway: 1) {
			placed.append(Placed(x: Double(x), y: Double(y), angle: angle, a: a, b: b))
		} else {
			retry.append((x, y))
		}
	}

	/* The direction of the stitches near a point, averaging angles that
	 * point either way */
	func neighbourAngle(_ x: Double, _ y: Double, radius: Double) -> Double? {
		var c = 0.0, s = 0.0
		for p in placed {
			let r = hypot(p.x - x, p.y - y)
			if r < radius {
				let w = 1 - r / radius
				c += w * cos(2 * p.angle)
				s += w * sin(2 * p.angle)
			}
		}
		return c == 0 && s == 0 ? nil : 0.5 * atan2(s, c)
	}

	/* A short stitch through a point, trying every 5 degrees. Shorter is
	 * better, but so is turning less from the stitches around it. */
	func shortStitch(_ x: Int, _ y: Int) -> Placed? {
		let around = neighbourAngle(Double(x), Double(y), radius: 10)
		var best: Placed?, bestScore = Double.infinity
		for step in 0..<36 {
			let angle = Double(step) * .pi / 36
			let (a, b, length) = stitch(Double(x) + 0.5, Double(y) + 0.5, angle: angle)
			guard length > 1.5 else {
				continue
			}
			let turn = around.map { sin(angle - $0) } ?? 0
			let score = length * (1 + 0.8 * turn * turn)
			if score < bestScore {
				best = Placed(x: Double(x), y: Double(y), angle: angle, a: a, b: b, fill: true)
				bestScore = score
			}
		}
		return best
	}

	/* Seeds whose stitch ran along the stroke */
	for (x, y) in retry {
		if let p = shortStitch(x, y) {
			placed.append(p)
		}
	}

	/* Fill any part of the letter still bare */
	let coverage = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
							 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
	coverage.translateBy(x: 0, y: CGFloat(H))
	coverage.scaleBy(x: 1, y: -1)
	coverage.setStrokeColor(gray: 1, alpha: 1)
	coverage.setLineWidth(3.2)
	coverage.setLineCap(.round)
	func cover(_ p: Placed) {
		coverage.move(to: p.a)
		coverage.addLine(to: p.b)
		coverage.strokePath()
	}
	placed.forEach(cover)
	let covered = coverage.data!.assumingMemoryBound(to: UInt8.self)
	for _ in 0..<3 {
		var bare: [(Int, Int)] = []
		for y in 0..<H {
			for x in 0..<W where inside(x, y) && d[y * W + x] >= 1.5 && covered[y * W + x] < 128 {
				bare.append((x, y))
			}
		}
		if bare.isEmpty {
			break
		}
		bare.shuffle(using: &random)
		for (x, y) in bare where covered[y * W + x] < 128 {
			if let p = shortStitch(x, y) {
				placed.append(p)
				cover(p)
			}
		}
	}

	/* Sew the filling first, like underlay, so the satin lies over it; each
	 * from the top of the letter down, with the needle going back and forth
	 * across the stroke */
	placed.sort { ($0.fill ? 0 : 1, $0.a.y + $0.b.y, $0.a.x + $0.b.x) < ($1.fill ? 0 : 1, $1.a.y + $1.b.y, $1.a.x + $1.b.x) }
	var flip = false
	return placed.map { p in
		func toDesign(_ q: CGPoint) -> CGPoint {
			CGPoint(x: q.x + origin.x + CGFloat.random(in: -0.3...0.3, using: &random),
					y: q.y + origin.y + CGFloat.random(in: -0.3...0.3, using: &random))
		}
		flip.toggle()
		return flip ? (toDesign(p.a), toDesign(p.b)) : (toDesign(p.b), toDesign(p.a))
	}
}

// MARK: - Drawing

func srgb(_ c: (r: Int, g: Int, b: Int), _ k: CGFloat = 1) -> CGColor {
	CGColor(srgbRed: CGFloat(c.r) / 255 * k, green: CGFloat(c.g) / 255 * k, blue: CGFloat(c.b) / 255 * k, alpha: 1)
}

/// Draws a CGImage into `rect` of a context whose y runs down
func drawUpright(_ image: CGImage, in rect: CGRect, context: CGContext) {
	context.saveGState()
	context.translateBy(x: 0, y: rect.minY + rect.maxY)
	context.scaleBy(x: 1, y: -1)
	context.draw(image, in: rect)
	context.restoreGState()
}

/// The fabric, in design units around `center`, filling `rect` (pixels)
func drawFabric(_ color: NSColor, in rect: CGRect, context: CGContext) {
	context.saveGState()
	context.translateBy(x: hoopCenter.x, y: hoopCenter.y)
	context.scaleBy(x: pixelsPerUnit, y: pixelsPerUnit)
	let designRect = rect.offsetBy(dx: -hoopCenter.x, dy: -hoopCenter.y).applying(CGAffineTransform(scaleX: 1 / pixelsPerUnit, y: 1 / pixelsPerUnit))
	FabricTexture.shared.draw(color, in: designRect, context: context)
	context.restoreGState()
}

/// The icon at 1024 pixels: cloth in a rounded square, held in a wooden hoop,
/// with the letter stitched in the middle
func drawIcon(stitches: [(CGPoint, CGPoint)]) -> CGImage {
	let size = Int(canvas)
	let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
							space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.translateBy(x: 0, y: canvas)
	context.scaleBy(x: 1, y: -1)
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	let fabric = NSColor(cgColor: srgb(fabricColor))!

	/* The cloth around the hoop, looser and a little darker, in the rounded
	 * square with a soft shadow */
	let tileShape = CGPath(roundedRect: tile, cornerWidth: tileCorner, cornerHeight: tileCorner, transform: nil)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
	context.addPath(tileShape)
	context.setFillColor(srgb(fabricColor, 0.9))
	context.fillPath()
	context.restoreGState()
	context.saveGState()
	context.addPath(tileShape)
	context.clip()
	drawFabric(NSColor(cgColor: srgb(fabricColor, 0.93))!, in: tile, context: context)
	let vignette = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.16)] as CFArray, locations: [0.55, 1])!
	context.drawRadialGradient(vignette, startCenter: hoopCenter, startRadius: 0, endCenter: hoopCenter, endRadius: tile.width * 0.72, options: [.drawsAfterEndLocation])
	context.restoreGState()

	/* The taut cloth inside the hoop, and the stitches */
	let inner = CGRect(x: hoopCenter.x - hoopInnerRadius, y: hoopCenter.y - hoopInnerRadius, width: 2 * hoopInnerRadius, height: 2 * hoopInnerRadius)
	context.saveGState()
	context.addEllipse(in: inner)
	context.clip()
	drawFabric(fabric, in: inner, context: context)
	var kitStitches = [Stitch(start: .zero, end: .zero, type: .normal)]
	kitStitches += stitches.map { Stitch(start: $0.0, end: $0.1, type: .normal) }
	let block = StitchBlock(stitches: kitStitches, color: NSColor(cgColor: srgb(threadColor))!)
	let designRect = CGRect(x: -hoopInnerRadius / pixelsPerUnit, y: -hoopInnerRadius / pixelsPerUnit,
							width: 2 * hoopInnerRadius / pixelsPerUnit, height: 2 * hoopInnerRadius / pixelsPerUnit)
	guard let renderer = RealisticRenderer.shared,
		  let thread = renderer.image(of: [block], showJumpStitches: false, rect: designRect,
									  pixelsWide: Int(inner.width), pixelsHigh: Int(inner.height)) else {
		fatalError("Can't draw Realistic thread on this Mac")
	}
	drawUpright(thread, in: inner, context: context)

	/* The hoop's shadow on the cloth */
	let shade = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.22)] as CFArray, locations: [0.8, 1])!
	context.drawRadialGradient(shade, startCenter: hoopCenter, startRadius: 0, endCenter: hoopCenter, endRadius: hoopInnerRadius, options: [])
	context.restoreGState()

	/* The wooden hoop */
	let ring = CGMutablePath()
	ring.addEllipse(in: CGRect(x: hoopCenter.x - hoopOuterRadius, y: hoopCenter.y - hoopOuterRadius, width: 2 * hoopOuterRadius, height: 2 * hoopOuterRadius))
	ring.addEllipse(in: inner)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: 8), blur: 18, color: CGColor(gray: 0, alpha: 0.4))
	context.addPath(ring)
	context.setFillColor(CGColor(srgbRed: 0.78, green: 0.6, blue: 0.4, alpha: 1))
	context.fillPath(using: .evenOdd)
	context.restoreGState()
	context.saveGState()
	context.addPath(ring)
	context.clip(using: .evenOdd)
	let wood = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 0.9, green: 0.74, blue: 0.52, alpha: 1),
													   CGColor(srgbRed: 0.72, green: 0.52, blue: 0.32, alpha: 1),
													   CGColor(srgbRed: 0.58, green: 0.4, blue: 0.24, alpha: 1)] as CFArray, locations: [0, 0.6, 1])!
	context.drawLinearGradient(wood, start: CGPoint(x: hoopCenter.x - hoopOuterRadius, y: hoopCenter.y - hoopOuterRadius),
							   end: CGPoint(x: hoopCenter.x + hoopOuterRadius, y: hoopCenter.y + hoopOuterRadius), options: [])
	/* Grain: faint rings at random shades */
	for i in 0..<40 {
		let r = hoopInnerRadius + CGFloat(i) * (hoopOuterRadius - hoopInnerRadius) / 40
		context.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.3, blue: 0.16, alpha: CGFloat.random(in: 0.03...0.12, using: &random)))
		context.setLineWidth(1)
		context.addEllipse(in: CGRect(x: hoopCenter.x - r, y: hoopCenter.y - r, width: 2 * r, height: 2 * r))
		context.strokePath()
	}
	/* Rounded edges: light on the inside top, shadow on the outside bottom */
	let bevel = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0.18), CGColor(gray: 1, alpha: 0), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.18)] as CFArray, locations: [0, 0.35, 0.65, 1])!
	context.drawRadialGradient(bevel, startCenter: hoopCenter, startRadius: hoopInnerRadius, endCenter: hoopCenter, endRadius: hoopOuterRadius, options: [])
	context.restoreGState()

	drawTensionScrew(context: context, ring: ring)

	return context.makeImage()!
}

/// The tension screw at the top of the hoop. The outer ring is split there,
/// with a brass lug on each side of the split, and a screw through both that's
/// tightened with a knurled thumb nut.
func drawTensionScrew(context: CGContext, ring: CGPath) {
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	let x = hoopCenter.x, top = hoopCenter.y - hoopOuterRadius
	let gap: CGFloat = 12, lugWidth: CGFloat = 30, lugHeight: CGFloat = 52
	let screwY = top - 6, screwThickness: CGFloat = 9

	/* Brass, lit from above */
	func brass(_ rect: CGRect, corner: CGFloat, shadow: Bool = true) {
		let shape = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
		if shadow {
			context.saveGState()
			context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6, color: CGColor(gray: 0, alpha: 0.45))
			context.addPath(shape)
			context.setFillColor(CGColor(srgbRed: 0.7, green: 0.53, blue: 0.2, alpha: 1))
			context.fillPath()
			context.restoreGState()
		}
		context.saveGState()
		context.addPath(shape)
		context.clip()
		let gradient = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 1.0, green: 0.92, blue: 0.62, alpha: 1),
															   CGColor(srgbRed: 0.82, green: 0.64, blue: 0.27, alpha: 1),
															   CGColor(srgbRed: 0.5, green: 0.36, blue: 0.12, alpha: 1)] as CFArray, locations: [0, 0.45, 1])!
		context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
		context.restoreGState()
	}

	/* The split, where the inner ring shows, set back in shadow */
	context.saveGState()
	context.addPath(ring)
	context.clip(using: .evenOdd)
	context.setFillColor(CGColor(srgbRed: 0.42, green: 0.28, blue: 0.15, alpha: 1))
	context.fill(CGRect(x: x - gap / 2, y: top - 2, width: gap, height: hoopOuterRadius - hoopInnerRadius + 4))
	context.restoreGState()

	/* The screw, through both lugs, with its head on the left and the thumb
	 * nut on the right */
	let left = x - gap / 2 - lugWidth, right = x + gap / 2 + lugWidth
	brass(CGRect(x: left - 6, y: screwY - screwThickness / 2, width: right - left + 22, height: screwThickness), corner: screwThickness / 2)
	brass(CGRect(x: left, y: top - lugHeight + 22, width: lugWidth, height: lugHeight), corner: 6)
	brass(CGRect(x: x + gap / 2, y: top - lugHeight + 22, width: lugWidth, height: lugHeight), corner: 6)
	brass(CGRect(x: left - 9, y: screwY - 9, width: 9, height: 18), corner: 3)

	let nut = CGRect(x: right + 8, y: screwY - 24, width: 16, height: 48)
	brass(nut, corner: 4)
	context.saveGState()
	context.clip(to: nut)
	context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.24, blue: 0.08, alpha: 0.55))
	context.setLineWidth(1.2)
	var knurl = nut.minY + 3
	while knurl < nut.maxY {
		context.move(to: CGPoint(x: nut.minX, y: knurl))
		context.addLine(to: CGPoint(x: nut.maxX, y: knurl))
		knurl += 4
	}
	context.strokePath()
	context.restoreGState()
}

/// The image scaled to `pixels` square
func scaled(_ image: CGImage, to pixels: Int) -> CGImage {
	let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
							space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.interpolationQuality = .high
	context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
	return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
	guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
		fatalError("Can't write \(url.path)")
	}
	CGImageDestinationAddImage(destination, image, nil)
	CGImageDestinationFinalize(destination)
}

// MARK: - Main

@main
struct IconGenerator {
	static func main() throws {
		let arguments = CommandLine.arguments
		guard arguments.count >= 3 else {
			FileHandle.standardError.write("usage: IconGenerator <font.ttf> <output .iconset directory> [seed]\n".data(using: .utf8)!)
			exit(2)
		}
		random = SeededRandom(state: arguments.count > 3 ? UInt64(arguments[3])! : 1)
		let fontURL = URL(fileURLWithPath: arguments[1])
		let iconset = URL(fileURLWithPath: arguments[2])
		try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

		let path = glyphPath(fontURL: fontURL, character: letter, size: letterSize)
		let stitches = satinStitches(for: path)
		print("\(stitches.count) stitches")
		let icon = drawIcon(stitches: stitches)

		/* The sizes an .iconset holds */
		for points in [16, 32, 128, 256, 512] {
			for scale in [1, 2] {
				let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
				let pixels = points * scale
				writePNG(pixels == Int(canvas) ? icon : scaled(icon, to: pixels), to: iconset.appendingPathComponent(name))
			}
		}
	}
}
