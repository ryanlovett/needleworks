//
//  CenteringClipView.swift
//  Needle Works
//
//  Copyright 2026 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
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

/// A clip view that centers its document view when the document is smaller
/// than the visible area, instead of pinning it to the bottom-left corner.
@objc(CenteringClipView)
final class CenteringClipView: NSClipView {
	override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
		var constrained = super.constrainBoundsRect(proposedBounds)
		guard let documentFrame = documentView?.frame else {
			return constrained
		}

		/* Along each axis where the document fits, center it in the visible area */
		if proposedBounds.width > documentFrame.width {
			constrained.origin.x = documentFrame.midX - proposedBounds.width / 2
		}
		if proposedBounds.height > documentFrame.height {
			constrained.origin.y = documentFrame.midY - proposedBounds.height / 2
		}
		return constrained
	}

	/// Around the design, show the same woven fabric as under it, lined up
	/// with the design so the two join without a seam
	override func draw(_ dirtyRect: NSRect) {
		guard let designView = documentView as? DesignView, let doc = designView.delegate, doc.showsFabricTexture() else {
			super.draw(dirtyRect)
			return
		}

		/* Draw in the design's coordinates */
		let origin = convert(NSPoint.zero, from: designView)
		let unitX = convert(NSPoint(x: 1, y: 0), from: designView)
		let unitY = convert(NSPoint(x: 0, y: 1), from: designView)
		let transform = NSAffineTransform()
		transform.transformStruct = NSAffineTransformStruct(m11: unitX.x - origin.x, m12: unitX.y - origin.y,
															m21: unitY.x - origin.x, m22: unitY.y - origin.y,
															tX: origin.x, tY: origin.y)

		NSGraphicsContext.saveGraphicsState()
		transform.concat()
		PESRenderer.drawFabric(doc.fabricColor(), texture: true, in: convert(dirtyRect, to: designView))
		NSGraphicsContext.restoreGraphicsState()
	}
}
