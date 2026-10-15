//
//  LegendPrintView.swift
//  Needle Works
//
//  Copyright 2008 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
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


import AppKit
import NeedleWorksKit

/// The printed legend: a swatch and the name of each thread, in sewing order.
@objc(LegendPrintView)
final class LegendPrintView: NSView {
	@objc weak var delegate: PESDocument?

	override func draw(_ rect: NSRect) {
		guard let doc = delegate else {
			return
		}

		let textHeight: CGFloat = 6
		let boxWidth = textHeight * 2
		let x = textHeight
		var y: CGFloat = 0
		let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.black,
														 .font: NSFont.systemFont(ofSize: textHeight)]

		for stitchBlock in doc.stitchBlocks {
			/* A generic label for colors that aren't in the PEC palette */
			let label = stitchBlock.threadName ?? String(format: NSLocalizedString("Color %lu", comment: "Legend label for a thread color with no name"), stitchBlock.colorIndex)

			/* The color's swatch */
			let box = NSRect(x: x, y: y + (textHeight / 2 - 1), width: boxWidth, height: textHeight)
			NSColor.black.setStroke()
			NSBezierPath.stroke(box)
			stitchBlock.color.setFill()
			NSBezierPath.fill(box)

			label.draw(at: NSPoint(x: x + boxWidth + boxWidth / 4, y: y), withAttributes: attributes)

			/* The next line */
			y += textHeight * 1.5
		}
	}

	/* http://developer.apple.com/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/chapter_8_section_7.html */
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		invalidateExposedRects()
	}

	/// We want to draw with (0, 0) at the top left
	override var isFlipped: Bool {
		true
	}

	override var isOpaque: Bool {
		true
	}
}
