//
//  PrintLayoutSplitView.swift
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

/// The root view of a printed page. Each time the print system paginates,
/// including when the print panel refreshes its preview, it asks its delegate
/// (the document) to lay out the page for the current paper size, orientation
/// and print scale.
@objc(PrintLayoutSplitView)
final class PrintLayoutSplitView: NSSplitView {
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		if let operation = NSPrintOperation.current, let document = delegate as? PESDocument {
			document.layoutPrintViews(for: operation.printInfo)
		}
		return super.knowsPageRange(range)
	}
}
