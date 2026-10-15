//
//  FabricColorPopUpButton.swift
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

/// A pop-up of common fabrics, each with a swatch, and Other… to pick a plain
/// weave in any color from the color panel. It sends its action when the
/// fabric changes.
@objc(FabricColorPopUpButton)
final class FabricColorPopUpButton: NSPopUpButton {
	/// The tags of the item for a color that isn't one of the fabrics, and of
	/// Other…
	private static let customTag = -1
	private static let otherTag = -2

	/// Common fabrics, in sRGB. Heather Gray is spun from light and dark
	/// fibers, and Denim and Chambray have blue warp and white weft, Denim in
	/// a twill.
	private static let fabrics: [(name: String, fabric: Fabric)] = {
		func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
			NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
		}
		return [(NSLocalizedString("White", comment: "Fabric"), Fabric(color: rgb(1, 1, 1))),
				(NSLocalizedString("Natural", comment: "Fabric: unbleached cotton or linen"), Fabric(color: rgb(0.93, 0.89, 0.80))),
				(NSLocalizedString("Khaki", comment: "Fabric"), Fabric(color: rgb(0.76, 0.69, 0.53))),
				(NSLocalizedString("Heather Gray", comment: "Fabric"), Fabric(weave: .heather, color: rgb(0.62, 0.62, 0.62))),
				(NSLocalizedString("Red", comment: "Fabric"), Fabric(color: rgb(0.70, 0.10, 0.12))),
				(NSLocalizedString("Forest Green", comment: "Fabric"), Fabric(color: rgb(0.13, 0.30, 0.20))),
				(NSLocalizedString("Chambray", comment: "Fabric: plain weave of blue and white yarn"), Fabric(weave: .chambray, color: rgb(0.40, 0.52, 0.70))),
				(NSLocalizedString("Denim", comment: "Fabric"), Fabric(weave: .denim, color: rgb(0.15, 0.24, 0.42))),
				(NSLocalizedString("Navy", comment: "Fabric"), Fabric(color: rgb(0.13, 0.17, 0.30))),
				(NSLocalizedString("Black", comment: "Fabric"), Fabric(color: rgb(0.08, 0.08, 0.08)))]
	}()

	/// Denim's color before it was woven as denim, in Needle Works 0.7
	private static let plainDenimColor = NSColor(srgbRed: 0.27, green: 0.36, blue: 0.50, alpha: 1)

	/// The fabric a color saved by an earlier version stood for: the preset
	/// of that color, or a plain weave in it
	static func fabric(savedAs color: NSColor) -> Fabric {
		if sameColor(color, plainDenimColor), let denim = fabrics.first(where: { $0.fabric.weave == .denim }) {
			return denim.fabric
		}
		return fabrics.first(where: { sameColor($0.fabric.color, color) })?.fabric ?? Fabric(color: color)
	}

	/// The color panel sends its changes here, and this passes them to the
	/// pop-up that opened it. The panel doesn't keep its target, so it can't
	/// be left sending to a pop-up that has gone.
	@MainActor
	private final class ColorPanelRelay: NSObject {
		weak var popUp: FabricColorPopUpButton?

		@objc func colorPanelDidChange(_ panel: NSColorPanel) {
			popUp?.useFabric(Fabric(color: panel.color.withAlphaComponent(1)))
		}
	}
	private static let colorPanelRelay = ColorPanelRelay()

	private var currentFabric = Fabric(color: .white)

	override init(frame frameRect: NSRect, pullsDown flag: Bool) {
		super.init(frame: frameRect, pullsDown: false)
		buildMenu()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		buildMenu()
	}

	var fabric: Fabric {
		get {
			currentFabric
		}
		set {
			if newValue == currentFabric {
				return
			}
			currentFabric = newValue
			buildMenu()
		}
	}

	/// Whether two colors look the same
	private static func sameColor(_ a: NSColor, _ b: NSColor) -> Bool {
		guard let ca = a.usingColorSpace(.sRGB), let cb = b.usingColorSpace(.sRGB) else {
			return false
		}
		return abs(ca.redComponent - cb.redComponent) < 0.002 &&
			abs(ca.greenComponent - cb.greenComponent) < 0.002 &&
			abs(ca.blueComponent - cb.blueComponent) < 0.002
	}

	/// A swatch of the fabric: a piece of its weave, enlarged to about two
	/// points a thread, so the weave shows at menu size and denim's twill
	/// shows a few diagonals
	private static func swatch(_ fabric: Fabric) -> NSImage {
		NSImage(size: NSSize(width: 16, height: 12), flipped: true) { rect in
			let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
			NSGraphicsContext.saveGraphicsState()
			shape.addClip()
			let scale: CGFloat = 0.75
			let transform = NSAffineTransform()
			transform.scale(by: scale)
			transform.concat()
			PESRenderer.drawFabric(fabric, texture: true, in: NSRect(x: 0, y: 0, width: rect.width / scale, height: rect.height / scale))
			NSGraphicsContext.restoreGraphicsState()
			NSColor.tertiaryLabelColor.setStroke()
			shape.stroke()
			return true
		}
	}

	/// The fabrics, the fabric shown if it's none of them, and Other…. Each
	/// item sends its own action to the pop-up, which sends the pop-up's
	/// action once the fabric has changed.
	private func buildMenu() {
		removeAllItems()
		guard let menu else {
			return
		}
		var selected: NSMenuItem?

		for (index, preset) in Self.fabrics.enumerated() {
			let item = menu.addItem(withTitle: preset.name, action: #selector(chooseItem(_:)), keyEquivalent: "")
			item.target = self
			item.image = Self.swatch(preset.fabric)
			item.tag = index
			if selected == nil && preset.fabric.weave == currentFabric.weave && Self.sameColor(preset.fabric.color, currentFabric.color) {
				selected = item
			}
		}
		if selected == nil {
			let custom = NSMenuItem(title: NSLocalizedString("Custom", comment: "Fabric color chosen from the color panel"),
									action: #selector(chooseItem(_:)), keyEquivalent: "")
			custom.target = self
			custom.image = Self.swatch(currentFabric)
			custom.tag = Self.customTag
			menu.insertItem(custom, at: 0)
			menu.insertItem(.separator(), at: 1)
			selected = custom
		}

		menu.addItem(.separator())
		let other = menu.addItem(withTitle: NSLocalizedString("Other…", comment: "Fabric color item that opens the color panel"),
								 action: #selector(chooseItem(_:)), keyEquivalent: "")
		other.target = self
		other.tag = Self.otherTag

		select(selected)
	}

	@objc private func chooseItem(_ item: NSMenuItem) {
		if item.tag == Self.otherTag {
			/* Show the color shown before Other… was chosen */
			buildMenu()
			let panel = NSColorPanel.shared
			panel.showsAlpha = false
			panel.color = currentFabric.flatColor
			Self.colorPanelRelay.popUp = self
			panel.setTarget(Self.colorPanelRelay)
			panel.setAction(#selector(ColorPanelRelay.colorPanelDidChange(_:)))
			panel.isContinuous = true
			panel.orderFront(self)
			return
		}
		if Self.fabrics.indices.contains(item.tag) {
			useFabric(Self.fabrics[item.tag].fabric)
		}
	}

	fileprivate func useFabric(_ newFabric: Fabric) {
		if newFabric == currentFabric {
			return
		}
		fabric = newFabric
		sendAction(action, to: target)
	}
}
