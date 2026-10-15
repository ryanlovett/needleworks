//
//  ShadedRenderer.swift
//  NeedleWorksKit
//

import AppKit
import simd

/// Draws stitches as round thread at its real width, lit from the top left.
///
/// Each stitch is a capsule with a faint shadow, shaded across its width so
/// it looks round, and darker at the ends where it goes into the fabric. How
/// bright the thread is depends on its direction, as with real thread, whose
/// fibers reflect light along their length (Kajiya-Kay shading).
struct ShadedRenderer {
	/// 40 weight embroidery thread is about 0.4 mm across.
	static let threadWidth: CGFloat = 4

	/// The light comes from the top left (y points down) and above.
	private static let light = simd_normalize(SIMD3<Double>(-1, -1, 1.4))
	private static let halfway = simd_normalize(light + SIMD3<Double>(0, 0, 1))

	/// Brightness is rounded to this many levels, so stitches can share
	/// gradients.
	private static let levels = 32.0

	private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
	private static let shadowColor = CGColor(gray: 0, alpha: 0.22)

	private struct GradientKey: Hashable {
		var color: SIMD3<Double>
		var diffuse: Int
		var specular: Int
	}

	private var gradients: [GradientKey: CGGradient] = [:]

	private let endShade = CGGradient(colorsSpace: colorSpace,
									  colors: [CGColor(gray: 0, alpha: 0.45), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.45)] as CFArray,
									  locations: [0, 0.3, 0.7, 1])!

	/// Draws the stitches that touch `rect`, in design units, into `context`.
	/// Jumps and trims, the threads between sewn areas, are drawn as thin
	/// loose strands if `showJumpStitches`, as they are left until clipped.
	static func draw(_ stitchBlocks: [StitchBlock], in rect: CGRect, context: CGContext, showJumpStitches: Bool) {
		var renderer = ShadedRenderer()
		let r = threadWidth / 2

		for stitchBlock in stitchBlocks {
			let color = rgb(stitchBlock.color)

			for (i, stitch) in stitchBlock.stitches.enumerated() {
				/* Skip stitches outside the area being drawn. The thread's width
				 * keeps the bounds of straight stitches from being empty. */
				let a = stitch.start, b = stitch.end
				let bounds = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)).insetBy(dx: -threadWidth, dy: -threadWidth)

				/* A block's first stitch carries the thread from the last block */
				guard i > 0, bounds.intersects(rect) else {
					continue
				}
				if stitch.type != .normal {
					if showJumpStitches {
						drawStrand(from: a, to: b, color: color, context: context)
					}
					continue
				}

				let dx = b.x - a.x, dy = b.y - a.y
				let length = max(hypot(dx, dy), 0.5)
				let tangent = SIMD3<Double>(Double(dx / length), Double(dy / length), 0)
				let tl = simd_dot(tangent, light), th = simd_dot(tangent, halfway)
				let diffuse = sqrt(max(0, 1 - tl * tl))
				let specular = pow(sqrt(max(0, 1 - th * th)), 40)
				let gradient = renderer.gradient(color: color, diffuse: diffuse, specular: specular)

				context.saveGState()
				context.translateBy(x: a.x, y: a.y)
				context.rotate(by: atan2(dy, dx))
				let capsule = CGPath(roundedRect: CGRect(x: -r * 0.6, y: -r, width: length + r * 1.2, height: threadWidth),
									 cornerWidth: r * 0.6, cornerHeight: r * 0.99, transform: nil)

				/* A faint shadow on the fabric and earlier stitches, away from the light */
				context.saveGState()
				context.translateBy(x: 0.6, y: 0.6)
				context.addPath(capsule)
				context.setFillColor(shadowColor)
				context.fillPath()
				context.restoreGState()

				/* Round thread: dark edges and a lit crown */
				context.addPath(capsule)
				context.clip()
				context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: -r), end: CGPoint(x: 0, y: r), options: [])

				/* Darker where the thread goes into the fabric at each end */
				if length > 3 {
					context.drawLinearGradient(renderer.endShade, start: CGPoint(x: -r * 0.6, y: 0), end: CGPoint(x: length + r * 0.6, y: 0), options: [])
				}
				context.restoreGState()
			}
		}
	}

	/// A loose thread between sewn areas: a thin strand in the thread's color.
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

	/// The gradient across a thread's width for its color and lighting.
	private mutating func gradient(color: SIMD3<Double>, diffuse: Double, specular: Double) -> CGGradient {
		let key = GradientKey(color: color, diffuse: Int((diffuse * Self.levels).rounded()), specular: Int((specular * Self.levels).rounded()))
		if let gradient = gradients[key] {
			return gradient
		}

		let base = 0.62 + 0.38 * Double(key.diffuse) / Self.levels
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
