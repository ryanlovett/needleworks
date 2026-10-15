//
//  PESRenderer.swift
//  NeedleWorksKit
//

import AppKit

/// How stitches look on screen.
@objc(PESStitchStyle)
public enum StitchStyle: Int {
	/// Lines of a chosen width, as printed.
	case plain
	/// Thread at its real width, with simple shading.
	case shaded
	/// Shaded thread with twist and natural variation.
	case realistic
}

/// Draws designs for the app, printing and Quick Look.
@objc(PESRenderer)
public final class PESRenderer: NSObject {
	/// Whether the renderer can draw in `style` yet.
	@objc(canDrawStitchStyle:)
	public class func canDraw(_ style: StitchStyle) -> Bool {
		style != .realistic || RealisticRenderer.shared != nil
	}

	/// Fills `rect` with the fabric color, then draws the stitches in `style`.
	@objc(drawStitchBlocks:style:fabricColor:lineWidth:showJumpStitches:inRect:)
	public class func draw(_ stitchBlocks: [StitchBlock], style: StitchStyle, fabricColor: NSColor, lineWidth: CGFloat, showJumpStitches: Bool, in rect: NSRect) {
		guard style != .plain, let context = NSGraphicsContext.current?.cgContext else {
			draw(stitchBlocks, fabricColor: fabricColor, lineWidth: lineWidth, showJumpStitches: showJumpStitches, in: rect)
			return
		}

		if style == .realistic, let renderer = RealisticRenderer.shared {
			/* Draw on the GPU at the context's resolution, then copy it in,
			 * flipped so the top of the image is at the top of `rect` */
			let pixels = context.convertToDeviceSpace(rect).integral
			if let image = renderer.image(of: stitchBlocks, fabricColor: fabricColor, showJumpStitches: showJumpStitches,
										  rect: rect, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height)) {
				context.saveGState()
				context.translateBy(x: 0, y: rect.minY + rect.maxY)
				context.scaleBy(x: 1, y: -1)
				context.draw(image, in: rect)
				context.restoreGState()
				return
			}
		}

		fabricColor.set()
		rect.fill()
		ShadedRenderer.draw(stitchBlocks, in: rect, context: context, showJumpStitches: showJumpStitches)
	}

	/// Draws `rect`, in design units, into an image `pixelsWide` by
	/// `pixelsHigh`, with the top of the design at the top of the image. It
	/// can be called on any thread.
	@objc(imageOfStitchBlocks:style:fabricColor:lineWidth:showJumpStitches:rect:pixelsWide:pixelsHigh:)
	public class func image(of stitchBlocks: [StitchBlock], style: StitchStyle, fabricColor: NSColor, lineWidth: CGFloat, showJumpStitches: Bool, rect: NSRect, pixelsWide: Int, pixelsHigh: Int) -> NSImage? {
		guard pixelsWide > 0, pixelsHigh > 0, rect.width > 0, rect.height > 0,
			  let context = CGContext(data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0,
									  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
			return nil
		}

		/* Flip so y points down, as in the design view */
		context.translateBy(x: 0, y: CGFloat(pixelsHigh))
		context.scaleBy(x: CGFloat(pixelsWide) / rect.width, y: -CGFloat(pixelsHigh) / rect.height)
		context.translateBy(x: -rect.minX, y: -rect.minY)

		/* The current graphics context belongs to this thread */
		let previous = NSGraphicsContext.current
		NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
		draw(stitchBlocks, style: style, fabricColor: fabricColor, lineWidth: lineWidth, showJumpStitches: showJumpStitches, in: rect)
		NSGraphicsContext.current = previous

		guard let image = context.makeImage() else {
			return nil
		}
		return NSImage(cgImage: image, size: rect.size)
	}

	/// Fills `rect` with the fabric color, then draws the stitches.
	@objc(drawStitchBlocks:fabricColor:lineWidth:showJumpStitches:inRect:)
	public class func draw(_ stitchBlocks: [StitchBlock], fabricColor: NSColor, lineWidth: CGFloat, showJumpStitches: Bool, in rect: NSRect) {
		fabricColor.set()
		rect.fill()

		draw(stitchBlocks, lineWidth: lineWidth, showJumpStitches: showJumpStitches)
	}

	/// Draws the stitches in the current graphics context, each block in its
	/// thread color. Jumps and trims are drawn only if `showJumpStitches`.
	@objc(drawStitchBlocks:lineWidth:showJumpStitches:)
	public class func draw(_ stitchBlocks: [StitchBlock], lineWidth: CGFloat, showJumpStitches: Bool) {
		guard let context = NSGraphicsContext.current?.cgContext else {
			return
		}

		for stitchBlock in stitchBlocks {
			let path = CGMutablePath()
			for (i, stitch) in stitchBlock.stitches.enumerated() {
				/* A block's first stitch carries the new thread from where the
				 * last block ended, so it is never drawn */
				if i == 0 || (stitch.type != .normal && !showJumpStitches) {
					path.move(to: stitch.end)
				} else {
					path.addLine(to: stitch.end)
				}
			}

			context.saveGState()
			context.setStrokeColor(stitchBlock.color.cgColor)
			context.setLineCap(.round)
			context.setLineJoin(.round)
			context.setLineWidth(lineWidth)
			/* Round the caps and joins as finely as NSBezierPath does, which
			 * the stitches were drawn with before */
			context.setFlatness(NSBezierPath.defaultFlatness)
			context.addPath(path)
			context.strokePath()
			context.restoreGState()
		}
	}
}
