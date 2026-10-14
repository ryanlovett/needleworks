//
//  ThreadRenderer.swift
//  NeedleWorksKit
//

import AppKit
import simd

/// Draws stitches as round thread at its real width, lit from the top left,
/// for the Shaded and Realistic styles.
///
/// Each stitch is a capsule with a faint shadow, shaded across its width so
/// it looks round, and darker at the ends where it goes into the fabric. How
/// bright the thread is depends on its direction, as with real thread, whose
/// fibers reflect light along their length (Kajiya-Kay shading).
///
/// Realistic thread also shows the twist of its two plies as fine diagonal
/// grooves, and each stitch varies a little in thickness, brightness and
/// where the needle went in, as real embroidery does.
struct ThreadRenderer {
	/// 40 weight embroidery thread is about 0.4 mm across.
	static let threadWidth: CGFloat = 4

	/// The light comes from the top left (y points down) and above.
	private static let light = simd_normalize(SIMD3<Double>(-1, -1, 1.4))
	private static let halfway = simd_normalize(light + SIMD3<Double>(0, 0, 1))

	/// Brightness is rounded to this many levels, so stitches can share
	/// gradients.
	private static let levels = 32.0

	/// Realistic thread's brightness varies by this many levels either way.
	private static let toneLevels = 3

	/// The distance between the grooves of the twist, along the thread, and
	/// their angle from straight across it.
	private static let twistPitch: CGFloat = 2.2
	private static let twistAngle: CGFloat = .pi / 4

	private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
	private static let shadowColor = CGColor(gray: 0, alpha: 0.22)
	private static let grooveColor = CGColor(gray: 0, alpha: 0.28)
	private static let ridgeColor = CGColor(gray: 1, alpha: 0.12)

	private struct GradientKey: Hashable {
		var color: SIMD3<Double>
		var diffuse: Int
		var specular: Int
		var tone: Int
	}

	private let realistic: Bool
	private var gradients: [GradientKey: CGGradient] = [:]

	private let endShade = CGGradient(colorsSpace: colorSpace,
									  colors: [CGColor(gray: 0, alpha: 0.45), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.45)] as CFArray,
									  locations: [0, 0.3, 0.7, 1])!

	/// Draws the stitches that touch `rect`, in design units, into `context`.
	/// Jump stitches, the loose threads left between sewn areas, are drawn
	/// as thin strands if `showJumpStitches`; trimmed threads are cut, so
	/// they never are.
	static func draw(_ stitchBlocks: [StitchBlock], realistic: Bool, in rect: CGRect, context: CGContext, showJumpStitches: Bool) {
		var renderer = ThreadRenderer(realistic: realistic)

		for (blockIndex, stitchBlock) in stitchBlocks.enumerated() {
			let color = rgb(stitchBlock.color)

			for (i, stitch) in stitchBlock.stitches.enumerated() {
				/* Skip stitches outside the area being drawn. The thread's width
				 * keeps the bounds of straight stitches from being empty. */
				let a = stitch.start, b = stitch.end
				let bounds = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)).insetBy(dx: -threadWidth, dy: -threadWidth)

				/* A block's first stitch carries the thread from the last block */
				guard i > 0, stitch.type != .trim, bounds.intersects(rect) else {
					continue
				}
				if stitch.type == .jump {
					if showJumpStitches {
						drawStrand(from: a, to: b, color: color, context: context)
					}
					continue
				}

				renderer.drawStitch(from: a, to: b, color: color, seed: UInt64(blockIndex) << 32 | UInt64(i), context: context)
			}
		}
	}

	private init(realistic: Bool) {
		self.realistic = realistic
	}

	private mutating func drawStitch(from a: CGPoint, to b: CGPoint, color: SIMD3<Double>, seed: UInt64, context: CGContext) {
		var a = a, b = b
		var width = Self.threadWidth
		var tone = 0
		var random = Random(seed: seed)
		if realistic {
			/* The needle goes in a little off where it was meant to, the same
			 * way for both stitches that meet there, so they stay joined */
			a = Self.wander(a)
			b = Self.wander(b)
			width *= 0.9 + 0.18 * random.next()
			tone = Int((random.next() * Double(2 * Self.toneLevels + 1)).rounded(.down)) - Self.toneLevels
		}
		let r = width / 2

		let dx = b.x - a.x, dy = b.y - a.y
		let length = max(hypot(dx, dy), 0.5)
		let tangent = SIMD3<Double>(Double(dx / length), Double(dy / length), 0)
		let tl = simd_dot(tangent, Self.light), th = simd_dot(tangent, Self.halfway)
		let diffuse = sqrt(max(0, 1 - tl * tl))
		let specular = pow(sqrt(max(0, 1 - th * th)), 40)
		let gradient = gradient(color: color, diffuse: diffuse, specular: specular, tone: tone)

		context.saveGState()
		context.translateBy(x: a.x, y: a.y)
		context.rotate(by: atan2(dy, dx))
		let capsule = CGPath(roundedRect: CGRect(x: -r * 0.6, y: -r, width: length + r * 1.2, height: width),
							 cornerWidth: r * 0.6, cornerHeight: r * 0.99, transform: nil)

		/* A faint shadow on the fabric and earlier stitches, away from the light */
		context.saveGState()
		context.translateBy(x: 0.6, y: 0.6)
		context.addPath(capsule)
		context.setFillColor(Self.shadowColor)
		context.fillPath()
		context.restoreGState()

		/* Round thread: dark edges and a lit crown */
		context.addPath(capsule)
		context.clip()
		context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: -r), end: CGPoint(x: 0, y: r), options: [])

		/* The plies' twist: slanted grooves, each with a lit ridge beside it */
		if realistic {
			let grooves = CGMutablePath()
			let ridges = CGMutablePath()
			let slant = width * tan(Self.twistAngle)
			var x = -r - slant + Self.twistPitch * CGFloat(random.next())
			while x < length + r {
				grooves.move(to: CGPoint(x: x, y: -r))
				grooves.addLine(to: CGPoint(x: x + slant, y: r))
				ridges.move(to: CGPoint(x: x + 0.5, y: -r))
				ridges.addLine(to: CGPoint(x: x + 0.5 + slant, y: r))
				x += Self.twistPitch
			}
			context.setLineWidth(0.35)
			context.addPath(grooves)
			context.setStrokeColor(Self.grooveColor)
			context.strokePath()
			context.addPath(ridges)
			context.setStrokeColor(Self.ridgeColor)
			context.strokePath()
		}

		/* Darker where the thread goes into the fabric at each end */
		if length > 3 {
			context.drawLinearGradient(endShade, start: CGPoint(x: -r * 0.6, y: 0), end: CGPoint(x: length + r * 0.6, y: 0), options: [])
		}
		context.restoreGState()
	}

	/// A loose jump thread: a thin strand in the thread's color.
	private static func drawStrand(from a: CGPoint, to b: CGPoint, color: SIMD3<Double>, context: CGContext) {
		context.saveGState()
		context.setStrokeColor(shade(color, 0.8))
		context.setLineWidth(threadWidth * 0.3)
		context.setLineCap(.round)
		context.move(to: a)
		context.addLine(to: b)
		context.strokePath()
		context.restoreGState()
	}

	/// Moves a needle point up to a quarter unit (0.025 mm) in each
	/// direction, always the same way for the same point.
	private static func wander(_ p: CGPoint) -> CGPoint {
		var random = Random(seed: UInt64(bitPattern: Int64(p.x)) << 32 ^ UInt64(bitPattern: Int64(p.y)))
		return CGPoint(x: p.x + 0.5 * CGFloat(random.next() - 0.5), y: p.y + 0.5 * CGFloat(random.next() - 0.5))
	}

	/// The gradient across a thread's width for its color and lighting.
	private mutating func gradient(color: SIMD3<Double>, diffuse: Double, specular: Double, tone: Int) -> CGGradient {
		let key = GradientKey(color: color, diffuse: Int((diffuse * Self.levels).rounded()), specular: Int((specular * Self.levels).rounded()), tone: tone)
		if let gradient = gradients[key] {
			return gradient
		}

		let base = (0.62 + 0.38 * Double(key.diffuse) / Self.levels) * (1 + 0.02 * Double(tone))
		let crown = base + 0.55 * Double(key.specular) / Self.levels + 0.08
		let colors = [Self.shade(color, base * 0.55), Self.shade(color, base * 0.92), Self.shade(color, crown), Self.shade(color, base * 0.92), Self.shade(color, base * 0.5)]
		let gradient = CGGradient(colorsSpace: Self.colorSpace, colors: colors as CFArray, locations: [0, 0.25, 0.45, 0.7, 1])!
		gradients[key] = gradient
		return gradient
	}

	private static func rgb(_ color: NSColor) -> SIMD3<Double> {
		guard let srgb = color.usingColorSpace(.sRGB) else {
			return .zero
		}
		return SIMD3(Double(srgb.redComponent), Double(srgb.greenComponent), Double(srgb.blueComponent))
	}

	/// Darkens the color for k < 1, and blends it toward white for k > 1.
	private static func shade(_ c: SIMD3<Double>, _ k: Double) -> CGColor {
		let rgb = k <= 1 ? c * k : c + (SIMD3(repeating: 1) - c) * min(k - 1, 1)
		return CGColor(srgbRed: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1)
	}
}

/// Repeatable pseudo-random numbers (SplitMix64), so each stitch varies the
/// same way every time it is drawn.
private struct Random {
	private var state: UInt64

	init(seed: UInt64) {
		state = seed
	}

	/// The next number, from 0 up to 1.
	mutating func next() -> Double {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		z ^= z >> 31
		return Double(z >> 11) / Double(1 << 53)
	}
}
