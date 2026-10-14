//
//  PESRenderer.swift
//  NeedleWorksKit
//

import AppKit

/// Draws designs as plain lines, for the app, printing and Quick Look.
@objc(PESRenderer)
public final class PESRenderer: NSObject {
	@objc(drawStitchBlocks:fabricColor:lineWidth:showJumpStitches:inRect:)
	public class func draw(_ stitchBlocks: [StitchBlock], fabricColor: NSColor, lineWidth: CGFloat, showJumpStitches: Bool, in rect: NSRect) {
		let currentContext = NSGraphicsContext.current

		/* Draw the background */
		fabricColor.set()
		rect.fill()

		/* Draw all of the stitches */
		for stitchBlock in stitchBlocks {
			currentContext?.saveGraphicsState()
			stitchBlock.draw(selected: false, jumps: showJumpStitches, width: lineWidth)
			currentContext?.restoreGraphicsState()
		}
	}
}
