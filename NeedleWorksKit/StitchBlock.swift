//
//  StitchBlock.swift
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

/// The stitches sewn with one thread color.
@objc(StitchBlock)
public final class StitchBlock: NSObject {
	/// Every needle movement in the block, in order. The first one carries
	/// the new thread from wherever the last block ended, so it isn't drawn.
	public let stitches: [Stitch]

	/// The PEC palette index of the thread, from 1, or 0 if the design has
	/// no colors.
	@objc public let colorIndex: Int

	public init(stitches: [Stitch], colorIndex: Int) {
		self.stitches = stitches
		self.colorIndex = colorIndex
	}

	@objc public var numStitches: Int {
		stitches.count
	}

	private var thread: PECThread? {
		(1...PECThread.palette.count).contains(colorIndex) ? PECThread.palette[colorIndex - 1] : nil
	}

	@objc public var color: NSColor {
		guard let thread else {
			return .black
		}
		return NSColor(srgbRed: CGFloat(thread.r) / 255, green: CGFloat(thread.g) / 255, blue: CGFloat(thread.b) / 255, alpha: 1)
	}

	/// The thread's name and Brother thread number, e.g. "Prussian Blue (7)",
	/// or nil if the color index isn't in the PEC palette.
	@objc public var threadName: String? {
		guard let thread else {
			return nil
		}
		return thread.number > 0 ? "\(thread.name) (\(thread.number))" : thread.name
	}

	/// The sewn stitches as one path; jumps and trims move without drawing.
	private lazy var stitchesPath = path(drawingJumps: false)

	/// Every stitch including jumps and trims, as the needle travels.
	private lazy var stitchesAndJumpsPath = path(drawingJumps: true)

	private func path(drawingJumps: Bool) -> NSBezierPath {
		let path = NSBezierPath()
		for (i, stitch) in stitches.enumerated() {
			if i == 0 || (stitch.type != .normal && !drawingJumps) {
				path.move(to: stitch.end)
			} else {
				path.line(to: stitch.end)
			}
		}
		return path
	}

	@objc(drawWithSelection:Jumps:Width:)
	public func draw(selected: Bool, jumps: Bool, width lineWidth: CGFloat) {
		let path = jumps ? stitchesAndJumpsPath : stitchesPath

		color.setStroke()
		path.lineCapStyle = .round
		path.lineJoinStyle = .round
		path.lineWidth = lineWidth
		path.stroke()
	}
}

/// A thread in the PEC palette.
struct PECThread {
	let name: String
	/// The Brother thread number, or 0 if none.
	let number: Int
	let r, g, b: UInt8

	/// The PEC thread palette, indexed from 1: Brother thread names, thread
	/// numbers and colors. The colors are those of the BuzzEdit color list,
	/// which agree with the palette libpes verified against a Brother Innovis
	/// 955 (https://github.com/frno7/libpes).
	static let palette: [PECThread] = [
		PECThread(name: "Prussian Blue",       number:   7, r:  26, g:  10, b: 148),
		PECThread(name: "Blue",                number: 405, r:  15, g: 117, b: 255),
		PECThread(name: "Teal Green",          number: 534, r:   0, g: 147, b:  76),
		PECThread(name: "Corn Flower Blue",    number:  70, r: 186, g: 189, b: 254),
		PECThread(name: "Red",                 number: 800, r: 236, g:   0, b:   0),
		PECThread(name: "Reddish Brown",       number: 337, r: 228, g: 153, b:  90),
		PECThread(name: "Magenta",             number: 620, r: 204, g:  72, b: 171),
		PECThread(name: "Light Lilac",         number: 810, r: 253, g: 196, b: 250),
		PECThread(name: "Lilac",               number: 612, r: 221, g: 132, b: 205),
		PECThread(name: "Mint Green",          number: 502, r: 107, g: 221, b: 138),
		PECThread(name: "Deep Gold",           number: 214, r: 228, g: 169, b:  69),
		PECThread(name: "Orange",              number: 208, r: 255, g: 189, b:  69),
		PECThread(name: "Yellow",              number: 205, r: 255, g: 230, b:   0),
		PECThread(name: "Lime Green",          number: 513, r: 108, g: 217, b:   0),
		PECThread(name: "Brass",               number: 328, r: 193, g: 169, b:  65),
		PECThread(name: "Silver",              number:   5, r: 181, g: 173, b: 151),
		PECThread(name: "Russet Brown",        number: 330, r: 186, g: 156, b:  95),
		PECThread(name: "Cream Brown",         number:  10, r: 250, g: 245, b: 158),
		PECThread(name: "Pewter",              number: 704, r: 128, g: 128, b: 128),
		PECThread(name: "Black",               number: 900, r:   0, g:   0, b:   0),
		PECThread(name: "Ultramarine",         number: 406, r:   0, g:  28, b: 223),
		PECThread(name: "Royal Purple",        number: 869, r: 223, g:   0, b: 184),
		PECThread(name: "Dark Gray",           number: 707, r:  98, g:  98, b:  98),
		PECThread(name: "Dark Brown",          number:  58, r: 105, g:  38, b:  13),
		PECThread(name: "Deep Rose",           number:  86, r: 255, g:   0, b:  96),
		PECThread(name: "Light Brown",         number: 323, r: 191, g: 130, b:   0),
		PECThread(name: "Salmon Pink",         number:  79, r: 243, g: 145, b: 120),
		PECThread(name: "Vermilion",           number:  30, r: 255, g: 104, b:   5),
		PECThread(name: "White",               number:   1, r: 240, g: 240, b: 240),
		PECThread(name: "Violet",              number: 613, r: 200, g:  50, b: 205),
		PECThread(name: "Seacrest",            number: 542, r: 176, g: 191, b: 155),
		PECThread(name: "Sky Blue",            number:  19, r: 101, g: 191, b: 235),
		PECThread(name: "Pumpkin",             number: 126, r: 255, g: 186, b:   4),
		PECThread(name: "Cream Yellow",        number: 812, r: 255, g: 240, b: 108),
		PECThread(name: "Khaki",               number: 348, r: 254, g: 202, b:  21),
		PECThread(name: "Clay Brown",          number: 339, r: 243, g: 129, b:   1),
		PECThread(name: "Leaf Green",          number: 509, r:  55, g: 169, b:  35),
		PECThread(name: "Peacock Blue",        number: 415, r:  35, g:  70, b:  95),
		PECThread(name: "Gray",                number: 817, r: 166, g: 166, b: 149),
		PECThread(name: "Warm Gray",           number: 399, r: 206, g: 191, b: 166),
		PECThread(name: "Dark Olive",          number: 517, r: 150, g: 170, b:   2),
		PECThread(name: "Linen",               number: 307, r: 255, g: 227, b: 198),
		PECThread(name: "Pink",                number:  85, r: 255, g: 153, b: 215),
		PECThread(name: "Deep Green",          number: 808, r:   0, g: 112, b:   4),
		PECThread(name: "Lavender",            number: 804, r: 237, g: 204, b: 251),
		PECThread(name: "Wisteria Violet",     number: 607, r: 192, g: 137, b: 216),
		PECThread(name: "Beige",               number: 843, r: 231, g: 217, b: 180),
		PECThread(name: "Carmine",             number: 807, r: 233, g:  14, b: 134),
		PECThread(name: "Amber Red",           number: 333, r: 207, g: 104, b:  41),
		PECThread(name: "Olive Green",         number: 519, r:  64, g: 134, b:  21),
		PECThread(name: "Dark Fuschia",        number: 107, r: 219, g:  23, b: 151),
		PECThread(name: "Tangerine",           number: 209, r: 255, g: 167, b:   4),
		PECThread(name: "Light Blue",          number:  17, r: 185, g: 255, b: 255),
		PECThread(name: "Emerald Green",       number: 507, r:  34, g: 137, b:  39),
		PECThread(name: "Purple",              number: 614, r: 182, g:  18, b: 205),
		PECThread(name: "Moss Green",          number: 515, r:   0, g: 170, b:   0),
		PECThread(name: "Flesh Pink",          number: 124, r: 254, g: 169, b: 220),
		PECThread(name: "Harvest Gold",        number: 206, r: 254, g: 213, b:  16),
		PECThread(name: "Electric Blue",       number: 420, r:   0, g: 151, b: 223),
		PECThread(name: "Lemon Yellow",        number: 202, r: 255, g: 255, b: 132),
		PECThread(name: "Fresh Green",         number:  27, r: 207, g: 231, b: 116),
		PECThread(name: "Applique Material",   number:   0, r: 255, g: 200, b: 100),
		PECThread(name: "Applique Position",   number:   0, r: 255, g: 200, b: 150),
		PECThread(name: "Applique",            number:   0, r: 255, g: 200, b: 200),
	]
}
