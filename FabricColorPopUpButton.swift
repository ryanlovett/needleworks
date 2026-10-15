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

/// A pop-up of common fabric colors, each with a swatch, and Other… to pick
/// any color from the color panel. It sends its action when the color changes.
@objc(FabricColorPopUpButton)
final class FabricColorPopUpButton: NSPopUpButton {
	/// The tags of the item for a color that isn't one of the fabrics, and of
	/// Other…
	private static let customTag = -1
	private static let otherTag = -2

	/// Common fabrics, in sRGB
	private static let fabrics: [(name: String, color: NSColor)] = {
		func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
			NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
		}
		return [(NSLocalizedString("White", comment: "Fabric color"), rgb(1, 1, 1)),
				(NSLocalizedString("Natural", comment: "Fabric color: unbleached cotton or linen"), rgb(0.93, 0.89, 0.80)),
				(NSLocalizedString("Khaki", comment: "Fabric color"), rgb(0.76, 0.69, 0.53)),
				(NSLocalizedString("Heather Gray", comment: "Fabric color"), rgb(0.62, 0.62, 0.62)),
				(NSLocalizedString("Red", comment: "Fabric color"), rgb(0.70, 0.10, 0.12)),
				(NSLocalizedString("Forest Green", comment: "Fabric color"), rgb(0.13, 0.30, 0.20)),
				(NSLocalizedString("Denim", comment: "Fabric color"), rgb(0.27, 0.36, 0.50)),
				(NSLocalizedString("Navy", comment: "Fabric color"), rgb(0.13, 0.17, 0.30)),
				(NSLocalizedString("Black", comment: "Fabric color"), rgb(0.08, 0.08, 0.08))]
	}()

	/// The color panel sends its changes here, and this passes them to the
	/// pop-up that opened it. The panel doesn't keep its target, so it can't
	/// be left sending to a pop-up that has gone.
	@MainActor
	private final class ColorPanelRelay: NSObject {
		weak var popUp: FabricColorPopUpButton?

		@objc func colorPanelDidChange(_ panel: NSColorPanel) {
			popUp?.useColor(panel.color.withAlphaComponent(1))
		}
	}
	private static let colorPanelRelay = ColorPanelRelay()

	private var currentColor: NSColor = .white

	override init(frame frameRect: NSRect, pullsDown flag: Bool) {
		super.init(frame: frameRect, pullsDown: false)
		buildMenu()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		buildMenu()
	}

	@objc var color: NSColor {
		get {
			currentColor
		}
		set {
			if newValue == currentColor {
				return
			}
			currentColor = newValue.copy() as? NSColor ?? .white
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

	private static func swatch(_ color: NSColor) -> NSImage {
		NSImage(size: NSSize(width: 16, height: 12), flipped: false) { rect in
			let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
			color.setFill()
			path.fill()
			NSColor.tertiaryLabelColor.setStroke()
			path.stroke()
			return true
		}
	}

	/// The fabrics, the color shown if it's none of them, and Other…. Each
	/// item sends its own action to the pop-up, which sends the pop-up's
	/// action once the color has changed.
	private func buildMenu() {
		removeAllItems()
		guard let menu else {
			return
		}
		var selected: NSMenuItem?

		for fabric in Self.fabrics {
			let item = menu.addItem(withTitle: fabric.name, action: #selector(chooseItem(_:)), keyEquivalent: "")
			item.target = self
			item.image = Self.swatch(fabric.color)
			item.representedObject = fabric.color
			if selected == nil && Self.sameColor(fabric.color, currentColor) {
				selected = item
			}
		}
		if selected == nil {
			let custom = NSMenuItem(title: NSLocalizedString("Custom", comment: "Fabric color chosen from the color panel"),
									action: #selector(chooseItem(_:)), keyEquivalent: "")
			custom.target = self
			custom.image = Self.swatch(currentColor)
			custom.representedObject = currentColor
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
			panel.color = currentColor
			Self.colorPanelRelay.popUp = self
			panel.setTarget(Self.colorPanelRelay)
			panel.setAction(#selector(ColorPanelRelay.colorPanelDidChange(_:)))
			panel.isContinuous = true
			panel.orderFront(self)
			return
		}
		if let color = item.representedObject as? NSColor {
			useColor(color)
		}
	}

	fileprivate func useColor(_ newColor: NSColor) {
		if newColor == currentColor {
			return
		}
		color = newColor
		sendAction(action, to: target)
	}
}
