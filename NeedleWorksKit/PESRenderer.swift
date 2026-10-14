//
//  PESRenderer.swift
//  NeedleWorksKit
//

import AppKit

/// Draws designs as plain lines, for the app, printing and Quick Look.
@objc(PESRenderer)
public final class PESRenderer: NSObject {
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
