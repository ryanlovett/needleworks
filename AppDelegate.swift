//
//  AppDelegate.swift
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

@objc(AppDelegate)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
	@IBOutlet var inspectorPanelController: InspectorPanelController?

	private var settingsWindowController: SettingsWindowController?

	override init() {
		super.init()
		UserDefaults.standard.register(defaults: [SettingsWindowController.stitchStyleKey: StitchStyle.plain.rawValue,
												  SettingsWindowController.fabricTextureKey: true])

		/* The color panel opens on the color wheel */
		NSColorPanel.shared.mode = .wheel
	}

	/// Lets document windows (e.g. their toolbars) show or hide the Design
	/// Information panel through the responder chain
	@IBAction func toggleInspectorPanel(_ sender: Any?) {
		inspectorPanelController?.toggleInspectorPanel(sender)
	}

	@IBAction func toggleFabricTexture(_ sender: Any?) {
		let defaults = UserDefaults.standard
		defaults.set(!defaults.bool(forKey: SettingsWindowController.fabricTextureKey), forKey: SettingsWindowController.fabricTextureKey)
	}

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(toggleFabricTexture(_:)) {
			menuItem.state = UserDefaults.standard.bool(forKey: SettingsWindowController.fabricTextureKey) ? .on : .off
		}
		return true
	}

	@IBAction func showSettings(_ sender: Any?) {
		if settingsWindowController == nil {
			settingsWindowController = SettingsWindowController()
		}
		settingsWindowController?.showWindow(sender)
	}

	/// Don't open a blank window when the application starts
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		false
	}
}
