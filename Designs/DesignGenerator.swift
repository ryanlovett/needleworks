//
//  DesignGenerator.swift
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

// Makes the sample designs: the name Needle Works, a peace sign and a
// flower, as PES files. It is built with the icon's satin stitches; see
// make-designs.sh.
//
// usage: DesignGenerator <font.ttf> <output directory>
//
// The same font always gives the same designs.

import AppKit
import CoreText

// MARK: - Threads

/// Threads, by their index in the PEC palette
enum ThreadColor: UInt8 {
	case prussianBlue = 1
	case deepGold = 11
	case pumpkin = 33
	case white = 29
	case ultramarine = 21
	case leafGreen = 37
	case carmine = 48
}

/// Satin stitches cross a column every 0.2 mm, so the needle goes in every
/// 0.4 mm along each edge; fill rows are 0.4 mm apart, with stitches up to
/// 3 mm long
let satinSpacing = 2.0
let fillRowSpacing: CGFloat = 4
let fillStitchLength: CGFloat = 30

/// Moves longer than this, in design units, are trimmed rather than sewn
let longestTravel: CGFloat = 20

var random = SeededRandom(state: 1)

// MARK: - Sewing

/// A run of stitches that can be sewn from either end: a satin stitch across
/// a column, or a row of fill
typealias Run = [CGPoint]

/// One thread's stitches, in the order they're sewn: each needle position,
/// and whether the thread was trimmed to move there
struct ColorBlock {
	var thread: ThreadColor
	var points: [(CGPoint, trim: Bool)] = []

	var end: CGPoint? {
		points.last?.0
	}

	/// Sews `runs`, each next from the end nearest the needle, moving to it
	/// with a stitch if it's close and trimming otherwise. Satin stitches, of
	/// two points, zigzag: each one's start is skipped when it's close to the
	/// last one's end, so the needle crosses the column on the way back too.
	mutating func sew(_ runs: [Run]) {
		var remaining = runs
		while !remaining.isEmpty {
			let from = end ?? remaining[0][0]
			var best = 0, bestReversed = false, bestDistance = CGFloat.infinity
			for (i, run) in remaining.enumerated() {
				for (reversed, point) in [(false, run[0]), (true, run[run.count - 1])] {
					let d = hypot(point.x - from.x, point.y - from.y)
					if d < bestDistance {
						best = i
						bestReversed = reversed
						bestDistance = d
					}
				}
			}
			var run = remaining.remove(at: best)
			if bestReversed {
				run.reverse()
			}
			let trim = end == nil || bestDistance > longestTravel
			if run.count == 2 && !trim && bestDistance < satinSpacing * 3 {
				run.removeFirst()
			}
			for (i, point) in run.enumerated() {
				points.append((point, trim: trim && i == 0))
			}
		}
	}
}

// MARK: - Shapes

/// Satin stitches across `path`, the filling under them first
func satin(_ path: CGPath) -> [[Run]] {
	let stitches = satinStitches(for: path, spacing: satinSpacing, random: &random)
	return [stitches.filter(\.filling).map { [$0.a, $0.b] }, stitches.filter { !$0.filling }.map { [$0.a, $0.b] }]
}

/// Rows of fill stitches across `path`, leaving out `hole`, at `angle`. The
/// needle goes in every `fillStitchLength`, a third of it further along
/// each row than the last, so the stitches don't line up into ridges.
func fill(_ path: CGPath, minus hole: CGPath? = nil, angle: CGFloat) -> [Run] {
	/* Rotate so the rows run along x, and rasterize at one cell per unit */
	var toRows = CGAffineTransform(rotationAngle: -angle), fromRows = CGAffineTransform(rotationAngle: angle)
	let shape = path.copy(using: &toRows)!, holeShape = hole.flatMap { $0.copy(using: &toRows) }
	let bounds = shape.boundingBoxOfPath.insetBy(dx: -2, dy: -2).integral
	let W = Int(bounds.width), H = Int(bounds.height)
	let context = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
							space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
	context.translateBy(x: 0, y: CGFloat(H))
	context.scaleBy(x: 1, y: -1)
	context.translateBy(x: -bounds.minX, y: -bounds.minY)
	context.addPath(shape)
	context.setFillColor(gray: 1, alpha: 1)
	context.fillPath()
	if let holeShape {
		context.addPath(holeShape)
		context.setFillColor(gray: 0, alpha: 1)
		context.fillPath()
	}
	let mask = context.data!.assumingMemoryBound(to: UInt8.self)

	var runs: [Run] = []
	var row = 0
	var y = bounds.minY + fillRowSpacing / 2
	while y < bounds.maxY {
		let yi = Int(y - bounds.minY)
		let offset = CGFloat(row % 3) * fillStitchLength / 3
		var x = 0
		while x < W {
			guard mask[yi * W + x] > 127 else {
				x += 1
				continue
			}
			let start = x
			while x < W && mask[yi * W + x] > 127 {
				x += 1
			}
			let x0 = bounds.minX + CGFloat(start) + 0.5, x1 = bounds.minX + CGFloat(x) - 0.5
			guard x1 - x0 > 3 else {
				continue
			}
			var run = [CGPoint(x: x0, y: y)]
			var needle = ((x0 - offset) / fillStitchLength).rounded(.up) * fillStitchLength + offset
			while needle < x1 - fillStitchLength / 3 {
				if needle > x0 + fillStitchLength / 3 {
					run.append(CGPoint(x: needle, y: y))
				}
				needle += fillStitchLength
			}
			run.append(CGPoint(x: x1, y: y))
			runs.append(run.map { $0.applying(fromRows) })
		}
		row += 1
		y += fillRowSpacing
	}
	return runs
}

/// A line of `width` along `points`, as an outline to stitch across
func stroke(_ points: [CGPoint], width: CGFloat, curved: Bool = false) -> CGPath {
	let line = CGMutablePath()
	line.move(to: points[0])
	if curved {
		for i in stride(from: 1, to: points.count - 1, by: 2) {
			line.addQuadCurve(to: points[i + 1], control: points[i])
		}
	} else {
		points.dropFirst().forEach { line.addLine(to: $0) }
	}
	return line.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4)
}

/// A circle, or the ring between two circles
func circle(radius: CGFloat, center: CGPoint = .zero) -> CGPath {
	CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
}

/// A leaf or petal pointing from `base` along `angle`: two arcs meeting in a
/// point at the tip, and rounder at the base if `round`
func petal(base: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat, round: Bool) -> CGPath {
	let path = CGMutablePath()
	let w = width / 2
	path.move(to: .zero)
	path.addCurve(to: CGPoint(x: length, y: 0), control1: CGPoint(x: round ? 0 : length * 0.25, y: -w * 1.3), control2: CGPoint(x: length * 0.75, y: -w * 1.1))
	path.addCurve(to: .zero, control1: CGPoint(x: length * 0.75, y: w * 1.1), control2: CGPoint(x: round ? 0 : length * 0.25, y: w * 1.3))
	path.closeSubpath()
	var place = CGAffineTransform(translationX: base.x, y: base.y).rotated(by: angle)
	return path.copy(using: &place)!
}

// MARK: - The designs

/// The name in the icon's font, on a gold rule
func wordmark(fontURL: URL) -> [ColorBlock] {
	let text = "Needle Works", width: CGFloat = 1100
	guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor])?.first else {
		fatalError("Can't read the font at \(fontURL.path)")
	}
	let unscaled = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
	let measured = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: unscaled])), nil, nil, nil)
	let font = CTFontCreateWithFontDescriptor(descriptor, 100 * width / measured, nil)
	let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))

	/* Each letter is stitched on its own, filling then satin, left to right,
	 * with y down and the text centered */
	var letters = ColorBlock(thread: .prussianBlue)
	for run in CTLineGetGlyphRuns(line) as! [CTRun] {
		let count = CTRunGetGlyphCount(run)
		var glyphs = [CGGlyph](repeating: 0, count: count), positions = [CGPoint](repeating: .zero, count: count)
		CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
		CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
		for (glyph, position) in zip(glyphs, positions) {
			var place = CGAffineTransform(translationX: -width / 2, y: 0).scaledBy(x: 1, y: -1).translatedBy(x: position.x, y: position.y)
			guard let outline = CTFontCreatePathForGlyph(font, glyph, &place) else {
				continue
			}
			satin(outline).forEach { letters.sew($0) }
		}
	}

	var rule = ColorBlock(thread: .deepGold)
	satin(stroke([CGPoint(x: -width / 2, y: 70), CGPoint(x: width / 2, y: 70)], width: 18)).forEach { rule.sew($0) }
	return [rule, letters]
}

/// A peace sign in white satin on a blue fill
func peaceSign() -> [ColorBlock] {
	let r: CGFloat = 370, band: CGFloat = 60
	let legs = [CGPoint(x: 0, y: -r), CGPoint(x: 0, y: r), CGPoint(x: -r * 0.7071, y: r * 0.7071)]
	func lines(_ width: CGFloat) -> CGPath {
		stroke([legs[0], legs[1]], width: width)
			.union(stroke([.zero, legs[2]], width: width))
			.union(stroke([.zero, CGPoint(x: -legs[2].x, y: legs[2].y)], width: width))
	}
	let symbol = circle(radius: r).copy(strokingWithWidth: band, lineCap: .butt, lineJoin: .round, miterLimit: 4)
		.union(lines(band))

	/* The fill runs a millimeter under the satin, so no fabric shows between them */
	var background = ColorBlock(thread: .ultramarine)
	background.sew(fill(circle(radius: r - band / 2 + 10), minus: lines(band - 20), angle: .pi / 4))
	var sign = ColorBlock(thread: .white)
	satin(symbol).forEach { sign.sew($0) }
	return [background, sign]
}

/// A flower on a curved stem with two leaves
func flower() -> [ColorBlock] {
	let center = CGPoint(x: 0, y: -170)

	var green = ColorBlock(thread: .leafGreen)
	let stem = stroke([CGPoint(x: center.x, y: center.y + 60), CGPoint(x: 60, y: 160), CGPoint(x: -20, y: 420)], width: 26, curved: true)
	let leaves = petal(base: CGPoint(x: 22, y: 190), length: 210, width: 90, angle: -0.45, round: false)
		.union(petal(base: CGPoint(x: 18, y: 280), length: 190, width: 80, angle: .pi + 0.55, round: false))
	satin(stem.union(leaves)).forEach { green.sew($0) }

	var petals = ColorBlock(thread: .carmine)
	var shape = CGMutablePath() as CGPath
	for i in 0..<6 {
		let angle = CGFloat(i) * .pi / 3 - .pi / 2
		shape = shape.union(petal(base: CGPoint(x: center.x + 40 * cos(angle), y: center.y + 40 * sin(angle)),
								  length: 200, width: 105, angle: angle, round: true))
	}
	satin(shape).forEach { petals.sew($0) }

	var middle = ColorBlock(thread: .pumpkin)
	middle.sew(fill(circle(radius: 62, center: center), angle: .pi / 6))
	return [green, petals, middle]
}

// MARK: - PES files

/// A PES file holding just the PEC section, which embroidery machines and
/// most software read: a label, the threads, the stitches, and a 48 × 38
/// picture of the design and of each thread's stitches for the machine's
/// screen.
func pesData(name: String, blocks: [ColorBlock]) -> Data {
	var pec = Data()
	func byte(_ b: UInt8) { pec.append(b) }
	func le16(_ v: Int) { byte(UInt8(v & 0xFF)); byte(UInt8(v >> 8 & 0xFF)) }
	func be16(_ v: Int) { byte(UInt8(v >> 8 & 0xFF)); byte(UInt8(v & 0xFF)) }

	/* The header, with the threads at 48 and padded to 512 bytes */
	pec.append(("LA:" + name.padding(toLength: 16, withPad: " ", startingAt: 0) + "\r").data(using: .ascii)!)
	pec.append(Data(repeating: 0x20, count: 12))
	pec.append(contentsOf: [0xFF, 0x00, 0x06, 0x26])
	pec.append(Data(repeating: 0x20, count: 12))
	byte(UInt8(blocks.count - 1))
	blocks.forEach { byte($0.thread.rawValue) }
	pec.append(Data(repeating: 0x20, count: 463 - blocks.count))

	/* The stitches, each a move from the last needle position, in one byte
	 * per coordinate if it's short and two if it's long or a trim */
	let all = blocks.flatMap { $0.points.map(\.0) }
	let minX = all.map(\.x).min()!.rounded(), minY = all.map(\.y).min()!.rounded()
	let maxX = all.map(\.x).max()!.rounded(), maxY = all.map(\.y).max()!.rounded()
	let stitchStart = pec.count
	le16(0)
	pec.append(contentsOf: [0, 0, 0])
	pec.append(contentsOf: [0x31, 0xFF, 0xF0])
	le16(Int(maxX - minX))
	le16(Int(maxY - minY))
	le16(0x1E0)
	le16(0x1B0)
	be16(0x9000 | (-Int(minX) & 0xFFF))
	be16(0x9000 | (-Int(minY) & 0xFFF))
	var x = 0, y = 0
	func move(_ dx: Int, _ dy: Int, trim: Bool) {
		if !trim && (-64...63).contains(dx) && (-64...63).contains(dy) {
			byte(UInt8(dx & 0x7F))
			byte(UInt8(dy & 0x7F))
		} else {
			let flag = trim ? 0xA000 : 0x8000
			be16(flag | (dx & 0xFFF))
			be16(flag | (dy & 0xFFF))
		}
	}
	for (i, block) in blocks.enumerated() {
		if i > 0 {
			pec.append(contentsOf: [0xFE, 0xB0, i % 2 == 1 ? 2 : 1])
		}
		for (point, trim) in block.points {
			let tx = Int(point.x.rounded()), ty = Int(point.y.rounded())
			/* Moves are at most 2047 units each way */
			while trim && (abs(tx - x) > 2000 || abs(ty - y) > 2000) {
				let sx = max(-2000, min(2000, tx - x)), sy = max(-2000, min(2000, ty - y))
				move(sx, sy, trim: true)
				x += sx
				y += sy
			}
			if tx != x || ty != y || !trim {
				move(tx - x, ty - y, trim: trim)
			}
			x = tx
			y = ty
		}
	}
	byte(0xFF)
	byte(0x00)
	let length = pec.count - stitchStart
	pec[stitchStart + 2] = UInt8(length & 0xFF)
	pec[stitchStart + 3] = UInt8(length >> 8 & 0xFF)
	pec[stitchStart + 4] = UInt8(length >> 16 & 0xFF)

	/* The pictures, one bit a pixel, the leftmost pixel in the low bit */
	func picture(_ points: [(CGPoint, trim: Bool)]) {
		let context = CGContext(data: nil, width: 48, height: 38, bitsPerComponent: 8, bytesPerRow: 48,
								space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
		context.setFillColor(gray: 0, alpha: 1)
		context.fill(CGRect(x: 0, y: 0, width: 48, height: 38))
		context.setStrokeColor(gray: 1, alpha: 1)
		context.stroke(CGRect(x: 1.5, y: 1.5, width: 45, height: 35))
		let scale = min(40 / (maxX - minX), 30 / (maxY - minY))
		context.translateBy(x: 24, y: 19)
		context.scaleBy(x: scale, y: -scale)
		context.translateBy(x: -(minX + maxX) / 2, y: -(minY + maxY) / 2)
		context.setLineWidth(1 / scale)
		for (i, (point, trim)) in points.enumerated() {
			if i == 0 || trim {
				context.move(to: point)
			} else {
				context.addLine(to: point)
			}
		}
		context.strokePath()
		let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
		for row in 0..<38 {
			for column in stride(from: 0, to: 48, by: 8) {
				var bits: UInt8 = 0
				for bit in 0..<8 where pixels[row * 48 + column + bit] > 127 {
					bits |= 1 << bit
				}
				byte(bits)
			}
		}
	}
	picture(blocks.flatMap(\.points))
	blocks.forEach { picture($0.points) }

	/* The PES header just says where the PEC section starts */
	var pes = "#PES0001".data(using: .ascii)!
	pes.append(contentsOf: [0x16, 0, 0, 0])
	pes.append(Data(repeating: 0, count: 10))
	return pes + pec
}

// MARK: - Main

@main
struct DesignGenerator {
	static func main() throws {
		let arguments = CommandLine.arguments
		guard arguments.count == 3 else {
			FileHandle.standardError.write("usage: DesignGenerator <font.ttf> <output directory>\n".data(using: .utf8)!)
			exit(2)
		}
		let output = URL(fileURLWithPath: arguments[2])
		try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

		let designs: [(String, () -> [ColorBlock])] = [("Needle Works", { wordmark(fontURL: URL(fileURLWithPath: arguments[1])) }),
														("Peace", peaceSign),
														("Flower", flower)]
		for (name, make) in designs {
			random = SeededRandom(state: 1)
			let blocks = make()
			try pesData(name: name, blocks: blocks).write(to: output.appendingPathComponent("\(name).pes"))
			print("\(name).pes: \(blocks.map(\.points.count).reduce(0, +)) stitches, \(blocks.count) threads")
		}
	}
}
