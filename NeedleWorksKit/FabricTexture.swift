//
//  FabricTexture.swift
//  NeedleWorksKit
//

import AppKit

/// A fine plain-weave fabric to draw thread on, at its real size.
final class FabricTexture: @unchecked Sendable {
	static let shared = FabricTexture()

	/// The width of a weave thread, in design units (0.3 mm), and the size of
	/// the tile the weave repeats in.
	private static let threadSize = 3
	private static let tileThreads = 8
	private static let tileSize = CGFloat(threadSize * tileThreads)
	private static let pixelsPerUnit = 12

	private let lock = NSLock()
	private var tileColor: NSColor?
	private var tile: CGImage?

	/// Fills `rect`, in design units, with the fabric in `color`. The weave
	/// lines up with the design's origin, so areas drawn separately join up.
	func draw(_ color: NSColor, in rect: CGRect, context: CGContext) {
		guard let tile = tile(for: color) else {
			context.setFillColor(color.cgColor)
			context.fill(rect)
			return
		}
		context.saveGState()
		context.clip(to: rect)
		context.interpolationQuality = .medium
		context.draw(tile, in: CGRect(x: 0, y: 0, width: Self.tileSize, height: Self.tileSize), byTiling: true)
		context.restoreGState()
	}

	private func tile(for color: NSColor) -> CGImage? {
		lock.lock()
		defer { lock.unlock() }
		if let tile, tileColor == color {
			return tile
		}
		tile = Self.makeTile(color)
		tileColor = color
		return tile
	}

	/// Over and under threads in a checkerboard, each shaded so it looks
	/// round, with a little variation from thread to thread.
	private static func makeTile(_ color: NSColor) -> CGImage? {
		guard let srgb = color.usingColorSpace(.sRGB) else {
			return nil
		}
		let size = Int(tileSize) * pixelsPerUnit
		var pixels = [UInt8](repeating: 255, count: size * size * 4)
		let base = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]

		for py in 0..<size {
			for px in 0..<size {
				let x = (CGFloat(px) + 0.5) / CGFloat(pixelsPerUnit), y = (CGFloat(py) + 0.5) / CGFloat(pixelsPerUnit)
				let cx = Int(x) / threadSize, cy = Int(y) / threadSize
				let fx = x / CGFloat(threadSize) - CGFloat(cx), fy = y / CGFloat(threadSize) - CGFloat(cy)
				let over = (cx + cy) % 2 == 0
				let across = over ? fy : fx
				var shade = 0.955 + 0.045 * sin(across * .pi)
				shade *= 0.985 + 0.03 * hash(cx, cy)
				shade *= 0.99 + 0.02 * hash(over ? cy : cx, over ? 7 : 13)
				for c in 0..<3 {
					pixels[(py * size + px) * 4 + c] = UInt8(max(0, min(255, (base[c] * shade * 255).rounded())))
				}
			}
		}

		guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
			return nil
		}
		return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
					   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
					   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	/// A repeatable number from 0 up to 1 for a weave cell.
	private static func hash(_ a: Int, _ b: Int) -> CGFloat {
		var z = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663)) &+ 0x9E37_79B9_7F4A_7C15
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		z ^= z >> 31
		return CGFloat(z >> 40) / CGFloat(1 << 24)
	}
}
