//
//  FabricTexture.swift
//  NeedleWorksKit
//

import AppKit

/// A fine plain-weave fabric to draw thread on, at its real size.
final class FabricTexture: @unchecked Sendable {
	static let shared = FabricTexture()

	/// The width of a weave thread, in design units (0.3 mm), and the size of
	/// the tile the weave repeats in (6 mm).
	private static let threadSize = 3
	private static let tileThreads = 20
	private static let tileSize = CGFloat(threadSize * tileThreads)
	private static let pixelsPerUnit = 12

	/// Faint patches across the cloth repeat at a size that shares no factor
	/// with the weave's, so neither repeat shows (16.1 mm, 7 patches across)
	private static let patchSize = 161
	private static let patchesAcross = 7

	/// Smaller copies of the tile, each half the size of the last, are drawn
	/// when zoomed out, as shrinking a tile much while drawing it makes
	/// stripes and false patterns. The smallest has 0.2 pixels per design
	/// unit, where a weave thread is under a pixel wide.
	private static let tileLevels = 7

	private let lock = NSLock()
	private var tileFabric: Fabric?
	private var tiles: [CGImage] = []
	private lazy var patches: CGImage? = Self.makePatches()

	/// Fills `rect`, in design units, with the fabric in `color`. The weave
	/// lines up with the design's origin, so areas drawn separately join up.
	func draw(_ fabric: Fabric, in rect: CGRect, context: CGContext) {
		let color = fabric.flatColor
		let ctm = context.ctm
		let scale = sqrt(abs(ctm.a * ctm.d - ctm.b * ctm.c))
		guard let (tile, patches) = images(for: fabric, scale: scale) else {
			context.setFillColor(color.cgColor)
			context.fill(rect)
			return
		}
		context.saveGState()
		context.clip(to: rect)

		/* Core Graphics can leave the odd pixel bare where tiles meet; this
		 * shows the fabric's color there */
		context.setFillColor(color.cgColor)
		context.fill(rect)

		context.interpolationQuality = .medium
		context.draw(tile, in: CGRect(x: 0, y: 0, width: Self.tileSize, height: Self.tileSize), byTiling: true)
		if let patches {
			context.draw(patches, in: CGRect(x: 0, y: 0, width: Self.patchSize, height: Self.patchSize), byTiling: true)
		}
		context.restoreGState()
	}

	/// The smallest tile with at least a pixel for each pixel drawn at
	/// `scale` pixels per design unit, and the patches
	private func images(for fabric: Fabric, scale: CGFloat) -> (CGImage, CGImage?)? {
		lock.lock()
		defer { lock.unlock() }
		if tiles.isEmpty || tileFabric != fabric {
			tiles = Self.makeTiles(fabric)
			tileFabric = fabric
		}
		guard let tile = tiles.last(where: { CGFloat($0.width) / Self.tileSize >= scale }) ?? tiles.first else {
			return nil
		}
		return (tile, patches)
	}

	/// The tile, then copies of it each half the size of the last
	private static func makeTiles(_ fabric: Fabric) -> [CGImage] {
		guard var tile = makeTile(fabric) else {
			return []
		}
		var tiles = [tile]
		for _ in 1..<tileLevels {
			guard let smaller = halved(tile) else {
				break
			}
			tiles.append(smaller)
			tile = smaller
		}
		return tiles
	}

	/// `tile` at half its size, rounded up. It's shrunk in the middle of a
	/// 3 × 3 grid of itself, so its edges blend into the opposite ones as they
	/// do when it repeats; shrunk alone, its edges would show as seams.
	private static func halved(_ tile: CGImage) -> CGImage? {
		let size = tile.width, half = (size + 1) / 2
		let space = CGColorSpace(name: CGColorSpace.sRGB)!, info = CGImageAlphaInfo.premultipliedLast.rawValue
		guard size > 1,
			  let grid = CGContext(data: nil, width: 3 * size, height: 3 * size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info),
			  let small = CGContext(data: nil, width: 3 * half, height: 3 * half, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info) else {
			return nil
		}
		for i in 0..<3 {
			for j in 0..<3 {
				grid.draw(tile, in: CGRect(x: i * size, y: j * size, width: size, height: size))
			}
		}
		guard let gridImage = grid.makeImage() else {
			return nil
		}
		small.interpolationQuality = .high
		small.draw(gridImage, in: CGRect(x: 0, y: 0, width: 3 * half, height: 3 * half))
		return small.makeImage()?.cropping(to: CGRect(x: half, y: half, width: half, height: half))
	}

	/// The weave: over and under threads in a checkerboard, or for denim, a
	/// twill where each warp thread passes over three weft threads and under
	/// one, a step further along on each row, making diagonal ribs. Each
	/// thread is round, with shadowed gaps beside it, and dips into shadow
	/// where it passes under the threads across it. Threads differ a little in
	/// shade and thickness, thicken and thin along their length, and show
	/// faint lengthwise fibers, which in heather yarn are light and dark.
	private static func makeTile(_ fabric: Fabric) -> CGImage? {
		func rgb(_ color: NSColor) -> [Double]? {
			color.usingColorSpace(.sRGB).map { [$0.redComponent, $0.greenComponent, $0.blueComponent] }
		}
		guard let base = rgb(fabric.color), let white = rgb(Fabric.weftColor) else {
			return nil
		}
		let twoColor = fabric.weave == .chambray || fabric.weave == .denim
		let warpColor = base

		/* Chambray's white weft takes a hint of the warp's color, so it reads
		 * as soft blue rather than a check */
		let weftColor = fabric.weave == .chambray ? zip(white, base).map { $0 + ($1 - $0) * 0.15 } : twoColor ? white : base

		/* Heather yarn is spun from fibers lighter and darker than its color */
		let light = base.map { $0 + (1 - $0) * 0.3 }, dark = base.map { $0 * 0.72 }

		let size = Int(tileSize) * pixelsPerUnit
		var pixels = [UInt8](repeating: 255, count: size * size * 4)
		let length = Double(tileThreads)

		for py in 0..<size {
			for px in 0..<size {
				/* Position in threads */
				let x = (Double(px) + 0.5) / Double(pixelsPerUnit * threadSize)
				let y = (Double(py) + 0.5) / Double(pixelsPerUnit * threadSize)
				let cx = Int(x), cy = Int(y)
				let fx = x - Double(cx), fy = y - Double(cy)

				/* Warp threads run up and down, weft threads across; the one on
				 * top here, which thread it is, and where along it we are. In
				 * twill a warp thread floats over three rows, so it dips only at
				 * the ends of the three. */
				let warpOver: Bool, dip: Double
				if fabric.weave == .denim {
					/* Right-hand twill, its ribs rising to the right. (The tile
					 * is drawn upside down, into the design's coordinates.) */
					let step = ((cx - cy) % 4 + 4) % 4
					warpOver = step != 0
					dip = warpOver ? (Double(step - 1) + fy) / 3 : fx
				} else {
					warpOver = (cx + cy) % 2 == 0
					dip = warpOver ? fy : fx
				}
				let thread = warpOver ? cx : cy
				let along = warpOver ? y : x
				let seed = warpOver ? 0 : 1000
				var color = warpOver ? warpColor : weftColor

				/* Threads aren't quite straight: each wanders a little from side
				 * to side */
				let wander = 0.16 * (noise(along * 0.9, period: length * 0.9, seed: thread + seed + 200) - 0.5)
				let across = (warpOver ? fx : fy) - 0.5 - wander

				/* Thickness, from 80 to 100% of the spacing, varying along the
				 * thread like slubs in spun yarn */
				let thickness = 0.87 + 0.02 * hash(thread, seed + 1) + 0.11 * noise(along * 1.3, period: length * 1.3, seed: thread + seed)
				let half = thickness / 2
				var shade: Double
				if abs(across) > half {
					/* The gap beside the thread, showing the thread beneath in
					 * shadow */
					shade = 0.86
					if twoColor {
						color = warpOver ? weftColor : warpColor
						shade = 0.8
					}
				} else {
					/* Round across the thread, and darker where it dips under */
					let s = across / half
					shade = 0.9 + 0.1 * sqrt(1 - s * s)
					shade *= 0.93 + 0.07 * sin(dip * .pi)

					/* Fibers along the thread */
					let fiber = Int(((s + 1) * 6).rounded(.down))
					shade *= 0.985 + 0.03 * noise(along * 2.1, period: length * 2.1, seed: thread * 31 + fiber + seed)

					/* Heather fibers are light or dark, changing slowly as they
					 * twist along the yarn */
					if fabric.weave == .heather {
						let fine = Int(((s + 1) * 11).rounded(.down))
						let n = noise(along * 4.2, period: length * 4.2, seed: thread * 53 + fine * 7 + seed + 900)
						let t = min(max((n - 0.35) / 0.3, 0), 1)
						color = zip(dark, light).map { $0 + ($1 - $0) * t * t * (3 - 2 * t) }
					}

					/* Denim's warp is dyed unevenly, lighter in places */
					if fabric.weave == .denim && warpOver {
						let fade = 0.25 * noise(along * 0.8, period: length * 0.8, seed: thread + 1700)
						color = color.map { $0 + (1 - $0) * fade }
					}
				}

				/* Each thread a little lighter or darker, and blotchy along it */
				shade *= 0.99 + 0.012 * hash(thread, seed + 7)
				shade *= 0.99 + 0.02 * noise(along * 0.6, period: length * 0.6, seed: thread + seed + 500)

				for c in 0..<3 {
					pixels[(py * size + px) * 4 + c] = UInt8(max(0, min(255, (color[c] * shade * 255).rounded())))
				}
			}
		}

		guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
			return nil
		}
		return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
					   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
					   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	/// Soft patches, a few millimetres across, that darken the cloth slightly:
	/// black, partly transparent, one pixel per design unit, laid over the
	/// weave in any color.
	private static func makePatches() -> CGImage? {
		let size = patchSize
		var pixels = [UInt8](repeating: 0, count: size * size * 4)
		let period = Double(patchesAcross)
		for py in 0..<size {
			for px in 0..<size {
				let x = Double(px) * period / Double(size), y = Double(py) * period / Double(size)
				let n = 0.65 * noise2(x, y, period: period, seed: 1) + 0.35 * noise2(x * 2, y * 2, period: period * 2, seed: 2)
				pixels[(py * size + px) * 4 + 3] = UInt8((n * 0.05 * 255).rounded())
			}
		}
		guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
			return nil
		}
		return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
					   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
					   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	/// Smooth noise from 0 to 1 along a line, repeating every `period`, which
	/// is rounded to a whole number of lattice steps.
	private static func noise(_ t: Double, period: Double, seed: Int) -> Double {
		let n = max(1, Int(period.rounded()))
		let i = Int(t.rounded(.down)), f = t - t.rounded(.down)
		let k = f * f * (3 - 2 * f)
		let a = hash(((i % n) + n) % n, seed), b = hash((((i + 1) % n) + n) % n, seed)
		return a + (b - a) * k
	}

	/// Smooth noise from 0 to 1 over a plane, repeating every `period` both ways.
	private static func noise2(_ x: Double, _ y: Double, period: Double, seed: Int) -> Double {
		let n = max(1, Int(period.rounded()))
		let i = Int(x.rounded(.down)), j = Int(y.rounded(.down))
		let fx = x - Double(i), fy = y - Double(j)
		let kx = fx * fx * (3 - 2 * fx), ky = fy * fy * (3 - 2 * fy)
		func h(_ a: Int, _ b: Int) -> Double {
			hash(((a % n) + n) % n * 7919 + ((b % n) + n) % n, seed)
		}
		let top = h(i, j) + (h(i + 1, j) - h(i, j)) * kx
		let bottom = h(i, j + 1) + (h(i + 1, j + 1) - h(i, j + 1)) * kx
		return top + (bottom - top) * ky
	}

	/// A repeatable number from 0 up to 1 for a pair of numbers.
	private static func hash(_ a: Int, _ b: Int) -> Double {
		var z = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663)) &+ 0x9E37_79B9_7F4A_7C15
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		z ^= z >> 31
		return Double(z >> 40) / Double(1 << 24)
	}
}
