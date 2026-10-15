//
//  PrintHeaderView.swift
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

/// The header of a printed page. When printing at actual size it draws a
/// 50 mm or 2 inch line (depending on the Mac's measurement system) at its
/// right edge, so people can check with a ruler that the printer didn't
/// scale the page.
@objc(PrintHeaderView)
final class PrintHeaderView: NSView {
	override func draw(_ rect: NSRect) {
		/* The check only makes sense when the design prints at actual size */
		if UserDefaults.standard.integer(forKey: PrintScaleAccessoryController.printScaleKey) != 0 {
			return
		}

		/* Use the units of the Mac's measurement system: 50 mm for metric, 2
		 * inches otherwise. Printer points are 1/72 inch. */
		let length: CGFloat
		let label: String
		if Locale.current.usesMetricSystem {
			length = 50 * 72 / 25.4
			label = NSLocalizedString("Should measure 50 mm", comment: "Printed under the metric scale check line")
		} else {
			length = 2 * 72
			label = NSLocalizedString("Should measure 2 inches", comment: "Printed under the US scale check line")
		}

		let rightEdge = bounds.maxX - 17
		let leftEdge = rightEdge - length
		let lineY: CGFloat = 34
		let ruler = NSBezierPath()
		ruler.move(to: NSPoint(x: leftEdge, y: lineY))
		ruler.line(to: NSPoint(x: rightEdge, y: lineY))
		ruler.move(to: NSPoint(x: leftEdge, y: lineY - 4))
		ruler.line(to: NSPoint(x: leftEdge, y: lineY + 4))
		ruler.move(to: NSPoint(x: rightEdge, y: lineY - 4))
		ruler.line(to: NSPoint(x: rightEdge, y: lineY + 4))
		ruler.lineWidth = 0.75
		NSColor.black.setStroke()
		ruler.stroke()

		let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .mini)),
														 .foregroundColor: NSColor.black]
		let labelSize = label.size(withAttributes: attributes)
		label.draw(at: NSPoint(x: rightEdge - labelSize.width, y: 14), withAttributes: attributes)
	}
}
