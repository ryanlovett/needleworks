//
//  RealisticRenderer.swift
//  NeedleWorksKit
//

import AppKit
import Metal

/// Draws stitches as realistic thread on the GPU, for the Realistic style.
final class RealisticRenderer: @unchecked Sendable {
	/// The renderer, or nil if this Mac can't run it.
	static let shared = RealisticRenderer()

	private let device: MTLDevice
	private let queue: MTLCommandQueue
	private let pipeline: MTLRenderPipelineState

	private struct StitchData {
		var ab: SIMD4<Float>		/* start and end, in design units */
		var color: SIMD4<Float>		/* linear RGB */
		var params: SIMD4<Float>	/* width, seed, tone, twist phase */
	}

	private struct Uniforms {
		var origin: SIMD2<Float>
		var size: SIMD2<Float>
		var pixelsPerUnit: Float
		var pad: Float = 0
	}

	private init?() {
		guard let device = MTLCreateSystemDefaultDevice(),
			  let queue = device.makeCommandQueue(),
			  let library = try? device.makeLibrary(source: realisticShaderSource, options: nil) else {
			return nil
		}

		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "stitchVertex")
		descriptor.fragmentFunction = library.makeFunction(name: "stitchFragment")
		let attachment = descriptor.colorAttachments[0]!
		attachment.pixelFormat = .rgba8Unorm_srgb
		/* The shader returns premultiplied colors */
		attachment.isBlendingEnabled = true
		attachment.sourceRGBBlendFactor = .one
		attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
		attachment.sourceAlphaBlendFactor = .one
		attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
		guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			return nil
		}

		self.device = device
		self.queue = queue
		self.pipeline = pipeline
	}

	/// An image of `rect`, in design units, `pixelsWide` by `pixelsHigh`,
	/// with the top of the design at the top of the image.
	func image(of stitchBlocks: [StitchBlock], fabricColor: NSColor, showJumpStitches: Bool, rect: CGRect, pixelsWide: Int, pixelsHigh: Int) -> CGImage? {
		let limit = device.supportsFamily(.apple3) || device.supportsFamily(.mac2) ? 16384 : 8192
		guard pixelsWide > 0, pixelsHigh > 0, pixelsWide <= limit, pixelsHigh <= limit else {
			return nil
		}

		let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: pixelsWide, height: pixelsHigh, mipmapped: false)
		textureDescriptor.usage = [.renderTarget]
		textureDescriptor.storageMode = .shared
		guard let target = device.makeTexture(descriptor: textureDescriptor) else {
			return nil
		}

		let fabric = Self.linear(fabricColor)
		let pass = MTLRenderPassDescriptor()
		pass.colorAttachments[0].texture = target
		pass.colorAttachments[0].loadAction = .clear
		pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(fabric.x), green: Double(fabric.y), blue: Double(fabric.z), alpha: 1)
		pass.colorAttachments[0].storeAction = .store

		guard let commandBuffer = queue.makeCommandBuffer(),
			  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
			return nil
		}

		let stitches = Self.stitchData(stitchBlocks, showJumpStitches: showJumpStitches)
		if !stitches.isEmpty, let buffer = device.makeBuffer(bytes: stitches, length: MemoryLayout<StitchData>.stride * stitches.count, options: .storageModeShared) {
			var uniforms = Uniforms(origin: SIMD2(Float(rect.minX), Float(rect.minY)),
									size: SIMD2(Float(rect.width), Float(rect.height)),
									pixelsPerUnit: Float(CGFloat(pixelsWide) / rect.width))
			encoder.setRenderPipelineState(pipeline)
			encoder.setVertexBuffer(buffer, offset: 0, index: 0)
			encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
			encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 12, instanceCount: stitches.count)
		}
		encoder.endEncoding()
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		let bytesPerRow = pixelsWide * 4
		var bytes = [UInt8](repeating: 0, count: bytesPerRow * pixelsHigh)
		target.getBytes(&bytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, pixelsWide, pixelsHigh), mipmapLevel: 0)
		guard let provider = CGDataProvider(data: Data(bytes) as CFData) else {
			return nil
		}
		return CGImage(width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
					   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
					   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	/// The stitches to draw, each with its own repeatable variation.
	private static func stitchData(_ stitchBlocks: [StitchBlock], showJumpStitches: Bool) -> [StitchData] {
		var data: [StitchData] = []
		for (blockIndex, stitchBlock) in stitchBlocks.enumerated() {
			let color = linear(stitchBlock.color)
			for (i, stitch) in stitchBlock.stitches.enumerated() {
				/* A block's first stitch carries the thread from the last block,
				 * trims are cut, and jumps are loose strands only when shown */
				guard i > 0, stitch.type != .trim, stitch.type == .normal || showJumpStitches else {
					continue
				}
				var random = Random(seed: UInt64(blockIndex) << 32 | UInt64(i))
				let width: Float = stitch.type == .jump ? 1.2 : 4 * (0.92 + 0.14 * random.next())
				let tone = (random.next() - 0.5) * 0.12
				let phase = random.next() * 10
				let a = wander(stitch.start), b = wander(stitch.end)
				data.append(StitchData(ab: SIMD4(a.x, a.y, b.x, b.y), color: color,
									   params: SIMD4(width, Float(i % 997) + Float(blockIndex) * 0.37, tone, phase)))
			}
		}
		return data
	}

	/// The needle goes in a little off where it was meant to, the same way for
	/// both stitches that meet there.
	private static func wander(_ p: CGPoint) -> SIMD2<Float> {
		var random = Random(seed: UInt64(bitPattern: Int64(p.x)) << 32 ^ UInt64(bitPattern: Int64(p.y)))
		return SIMD2(Float(p.x) + (random.next() - 0.5) * 0.8, Float(p.y) + (random.next() - 0.5) * 0.8)
	}

	/// The color in linear sRGB, which the shader lights in.
	private static func linear(_ color: NSColor) -> SIMD4<Float> {
		guard let srgb = color.usingColorSpace(.sRGB) else {
			return SIMD4(0, 0, 0, 1)
		}
		func linear(_ c: CGFloat) -> Float {
			let c = Float(c)
			return c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
		}
		return SIMD4(linear(srgb.redComponent), linear(srgb.greenComponent), linear(srgb.blueComponent), 1)
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
	mutating func next() -> Float {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		z ^= z >> 31
		return Float(z >> 40) / Float(1 << 24)
	}
}
