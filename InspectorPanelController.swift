//
//  InspectorPanelController.swift
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

/// The Design Information panel, which shows the main window's design.
@objc(InspectorPanelController)
final class InspectorPanelController: NSWindowController, NSMenuItemValidation {
	@IBOutlet var documentObjectController: NSObjectController?

	/// The document the panel shows, or nil when the main window has none;
	/// the panel's controls are bound to it
	@objc dynamic var inspectedDocument: PESDocument?

	@objc convenience init() {
		self.init(windowNibName: "InspectorPanel")
	}

	/// The main window, or its document, changed: show its design, finishing
	/// any editing in the one shown before
	private func activeDocumentChanged() {
		let mainDocument = NSApp.mainWindow?.windowController?.document as? PESDocument
		if mainDocument !== inspectedDocument {
			if inspectedDocument != nil {
				documentObjectController?.commitEditing()
			}
			inspectedDocument = mainDocument
		}
	}

	/// The main window, or its document, changed. AppKit changes them, and
	/// so tells us, on the main thread.
	nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "mainWindow.windowController.document" && object is NSApplication {
			MainActor.assumeIsolated {
				activeDocumentChanged()
			}
		} else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
		}
	}

	/// When controls in the panel start editing, register it with the
	/// inspected document
	@objc func objectDidBeginEditing(_ editor: any NSEditor) {
		inspectedDocument?.objectDidBeginEditing(editor)
	}

	@objc func objectDidEndEditing(_ editor: any NSEditor) {
		inspectedDocument?.objectDidEndEditing(editor)
	}

	/// We don't observe anything until the panel is first shown
	override func windowDidLoad() {
		super.windowDidLoad()

		/* Commit editing when the panel stops being key */
		NotificationCenter.default.addObserver(self, selector: #selector(inspectorPanelDidResignKey(_:)),
											   name: NSWindow.didResignKeyNotification, object: window)

		/* Show the active document, and follow changes to it */
		activeDocumentChanged()
		NSApp.addObserver(self, forKeyPath: "mainWindow.windowController.document", options: [], context: nil)
	}

	@objc private func inspectorPanelDidResignKey(_ notification: Notification) {
		documentObjectController?.commitEditing()
	}

	/// Hides the panel if it's showing and key; otherwise makes it key
	@objc func toggleInspectorPanel(_ sender: Any?) {
		guard let window else {
			return
		}
		if window.isVisible && window.isKeyWindow {
			window.orderOut(sender)
		} else {
			window.makeKeyAndOrderFront(sender)
		}
	}

	/// The menu item says whether choosing it shows or hides the panel
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(toggleInspectorPanel(_:)) {
			/* Checking isWindowLoaded first keeps this from loading the nib */
			if !isWindowLoaded || window?.isVisible != true || window?.isKeyWindow != true {
				menuItem.title = NSLocalizedString("Show Design Information",
												   comment: "Title for menu item to show the document properties panel (should be the same as the initial menu item in the nib).")
			} else {
				menuItem.title = NSLocalizedString("Hide Design Information", comment: "Title for menu item to hide the Inspector panel.")
			}
		}
		return true
	}
}
