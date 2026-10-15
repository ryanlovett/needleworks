//
//  SettingsWindowController.swift
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

/// The Settings window, and the settings it shows.
@objc(SettingsWindowController)
final class SettingsWindowController: NSWindowController {
	/// The user defaults key for the stitch style new windows use (a
	/// PESStitchStyle). Each window can choose its own from View > Stitch Style.
	@objc nonisolated static let stitchStyleKey = "stitchStyle"

	/// The user defaults key for whether stitches are drawn on a woven fabric
	/// texture; View > Show Fabric Texture changes it
	@objc nonisolated static let fabricTextureKey = "fabricTexture"

	/// The user defaults key for the fabric new windows use. Each window can
	/// choose its own from the toolbar. Versions before 0.8 kept just a color,
	/// under the second key.
	nonisolated static let fabricKey = "fabric"
	nonisolated static let fabricColorKey = "fabricColor"

	/// The fabric in Settings
	static var defaultFabric: Fabric {
		get {
			let defaults = UserDefaults.standard
			if let fabric = defaults.dictionary(forKey: fabricKey).flatMap(Fabric.init(propertyList:)) {
				return fabric
			}
			if let data = defaults.data(forKey: fabricColorKey),
			   let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
				return FabricColorPopUpButton.fabric(savedAs: color)
			}
			return Fabric(color: .white)
		}
		set {
			UserDefaults.standard.set(newValue.propertyList, forKey: fabricKey)
			UserDefaults.standard.removeObject(forKey: fabricColorKey)
		}
	}

	/// The names of the stitch styles, in PESStitchStyle order
	@objc static var stitchStyleTitles: [String] {
		[NSLocalizedString("Plain", comment: "Stitch style: lines"),
		 NSLocalizedString("Shaded", comment: "Stitch style: shaded thread"),
		 NSLocalizedString("Realistic", comment: "Stitch style: realistic thread")]
	}

	private let fabricColorPopUp = FabricColorPopUpButton(frame: .zero, pullsDown: false)

	init() {
		let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
		window.title = NSLocalizedString("Settings", comment: "Settings window title")
		super.init(window: window)
		buildContent()
		window.center()
	}

	required init?(coder: NSCoder) {
		fatalError("The Settings window isn't loaded from a nib")
	}

	private func note(_ text: String) -> NSTextField {
		let note = NSTextField(wrappingLabelWithString: text)
		note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		note.textColor = .secondaryLabelColor
		note.preferredMaxLayoutWidth = 260
		note.widthAnchor.constraint(equalToConstant: 260).isActive = true
		return note
	}

	private func buildContent() {
		let label = NSTextField(labelWithString: NSLocalizedString("Stitch style:", comment: "Settings label for the stitch style"))
		let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
		popUp.autoenablesItems = false
		for (style, title) in Self.stitchStyleTitles.enumerated() {
			popUp.addItem(withTitle: title)
			popUp.lastItem?.isEnabled = PESRenderer.canDraw(StitchStyle(rawValue: style) ?? .plain)
		}
		popUp.bind(.selectedIndex, to: NSUserDefaultsController.shared, withKeyPath: "values." + Self.stitchStyleKey, options: nil)
		let styleNote = note(NSLocalizedString("Windows use this style unless you choose another for a window from View > Stitch Style.",
											   comment: "Settings note under the stitch style"))

		let fabricLabel = NSTextField(labelWithString: NSLocalizedString("Fabric:", comment: "Settings label for the fabric"))
		fabricColorPopUp.fabric = Self.defaultFabric
		fabricColorPopUp.target = self
		fabricColorPopUp.action = #selector(chooseFabricColor(_:))
		let fabricNote = note(NSLocalizedString("Windows use this color unless you choose another for a window from the toolbar.",
												comment: "Settings note under the fabric color"))

		let grid = NSGridView(views: [[label, popUp],
									  [NSGridCell.emptyContentView, styleNote],
									  [fabricLabel, fabricColorPopUp],
									  [NSGridCell.emptyContentView, fabricNote]])
		grid.rowSpacing = 6
		grid.column(at: 0).xPlacement = .trailing
		grid.row(at: 0).yPlacement = .center
		grid.row(at: 2).yPlacement = .center
		grid.row(at: 2).topPadding = 14
		grid.cell(for: fabricColorPopUp)?.xPlacement = .leading
		grid.translatesAutoresizingMaskIntoConstraints = false

		let content = NSView(frame: .zero)
		content.addSubview(grid)
		NSLayoutConstraint.activate([
			grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
			grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
			grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
			grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
		])
		window?.contentView = content
		window?.setContentSize(content.fittingSize)
	}

	@objc private func chooseFabricColor(_ sender: FabricColorPopUpButton) {
		Self.defaultFabric = sender.fabric
	}
}
