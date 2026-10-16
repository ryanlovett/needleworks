//
//  Satin.swift
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


// Satin stitches for any shape, shared by the icon and sample design
// generators.

import CoreGraphics

// MARK: - Repeatable randomness

/// SplitMix64, so the same seed always gives the same stitches
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

// MARK: - Satin stitches

/// Satin stitches about `stitchSpacing` apart filling `path`, each crossing
/// the stroke from edge to edge at right angles to it, turning with its
/// curves as a digitizer's would.
///
/// The outline is rasterized at one cell per design unit. An exact distance
/// transform finds the middle of each stroke, and the smoothed structure
/// tensor of its gradient gives the direction across it. Stitches are seeded
/// along the stroke middles. Where strokes join, and in serifs, that direction
/// can run along a stroke instead, making a stitch far longer than the stroke
/// is wide. Those seeds are stitched instead along the shortest line across
/// the letter through them, as a digitizer stitches a serif across its short
/// side, and any part of the letter still bare gets stitches of its own the
/// same way, so there are no gaps. Those filling stitches come first, marked
/// `filling`.
func satinStitches(for path: CGPath, spacing stitchSpacing: Double, random: inout SeededRandom) -> [(a: CGPoint, b: CGPoint, filling: Bool)] {
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
		return flip ? (toDesign(p.a), toDesign(p.b), p.fill) : (toDesign(p.b), toDesign(p.a), p.fill)
	}
}
