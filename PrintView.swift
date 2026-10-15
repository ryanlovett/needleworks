//
//  PrintView.swift
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

/// The design on the printed page, as plain lines.
@objc(PrintView)
final class PrintView: NSView {
	@objc weak var delegate: PESDocument?

	override func draw(_ rect: NSRect) {
		guard let doc = delegate else {
			return
		}
		PESRenderer.draw(doc.stitchBlocks() as? [StitchBlock] ?? [], lineWidth: doc.printLineWidth(), showJumpStitches: doc.showJumpStitches())
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

extension NSView {
	/// After a resize, redraws only what the live resize exposed, or the
	/// whole view otherwise
	func invalidateExposedRects() {
		if inLiveResize {
			var rects = [NSRect](repeating: .zero, count: 4)
			var count = 0
			getRectsExposedDuringLiveResize(&rects, count: &count)
			for rect in rects.prefix(count) {
				setNeedsDisplay(rect)
			}
		} else {
			needsDisplay = true
		}
	}
}
