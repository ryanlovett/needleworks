//
//  PrintScaleAccessoryController.swift
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

/// Adds a Scale choice (Actual Size or Fit to Page) and the width of the
/// printed lines to the print panel
@objc(PrintScaleAccessoryController)
final class PrintScaleAccessoryController: NSViewController, NSPrintPanelAccessorizing {
	/// The user defaults key for the print scale: 0 prints designs at their
	/// actual size, 1 scales them to fit the page.
	@objc static let printScaleKey = "printScale"

	private var warningLabel: NSTextField?
	private var lineWidthLabel: NSTextField?

	@objc dynamic var printScale: Int {
		get {
			UserDefaults.standard.integer(forKey: Self.printScaleKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.printScaleKey)
		}
	}

	/// The width of printed lines, in design units; it starts as the window's
	@objc dynamic var lineWidth: CGFloat = 2 {
		didSet {
			lineWidthLabel?.stringValue = lineWidthText
		}
	}

	/// Set by the document when the design doesn't fit on the page at actual
	/// size, which shows a warning under the Scale choice
	@objc var designTooLarge = false {
		didSet {
			updateWarning()
		}
	}

	private var lineWidthText: String {
		String.localizedStringWithFormat(NSLocalizedString("%.1f mm", comment: "Line width in millimetres"), lineWidth / 10)
	}

	private var scaleTitles: [String] {
		[NSLocalizedString("Actual Size", comment: "Print scale: print the design at its real size"),
		 NSLocalizedString("Fit to Page", comment: "Print scale: scale the design to fit the page")]
	}

	private var warningText: String {
		NSLocalizedString("At actual size this design doesn't fit on the page and will be cut off. Try Landscape, a larger paper size, or Fit to Page.",
						  comment: "Print panel warning when the design is larger than the printable area")
	}

	override func loadView() {
		let label = NSTextField(labelWithString: NSLocalizedString("Scale:", comment: "Print panel label for the print scale"))
		let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
		popUp.addItems(withTitles: scaleTitles)
		popUp.bind(.selectedIndex, to: self, withKeyPath: "printScale", options: nil)
		let scaleRow = NSStackView(views: [label, popUp])

		let lineWidthTitle = NSTextField(labelWithString: NSLocalizedString("Line width:", comment: "Print panel label for the width of printed lines"))
		let slider = NSSlider(value: Double(lineWidth), minValue: 1, maxValue: 8, target: nil, action: nil)
		slider.numberOfTickMarks = 8
		slider.allowsTickMarkValuesOnly = true
		slider.widthAnchor.constraint(equalToConstant: 120).isActive = true
		slider.bind(.value, to: self, withKeyPath: "lineWidth", options: nil)
		let lineWidthLabel = NSTextField(labelWithString: lineWidthText)
		lineWidthLabel.textColor = .secondaryLabelColor
		self.lineWidthLabel = lineWidthLabel
		let lineWidthRow = NSStackView(views: [lineWidthTitle, slider, lineWidthLabel])

		/* Size the warning with its text so the panel reserves room for it,
		 * then show it only when it applies */
		let warningLabel = NSTextField(wrappingLabelWithString: warningText)
		warningLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
		warningLabel.textColor = .systemRed
		warningLabel.preferredMaxLayoutWidth = 320
		self.warningLabel = warningLabel

		let stack = NSStackView(views: [scaleRow, warningLabel, lineWidthRow])
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.edgeInsets = NSEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
		stack.setFrameSize(stack.fittingSize)
		view = stack

		updateWarning()
	}

	private func updateWarning() {
		warningLabel?.stringValue = designTooLarge ? warningText : ""
	}

	// MARK: NSPrintPanelAccessorizing

	func localizedSummaryItems() -> [[NSPrintPanel.AccessorySummaryKey: String]] {
		let titles = scaleTitles
		let scale = min(max(printScale, 0), titles.count - 1)
		return [[.itemName: NSLocalizedString("Scale", comment: "Print panel summary item name"), .itemDescription: titles[scale]],
				[.itemName: NSLocalizedString("Line Width", comment: "Print panel summary item name"), .itemDescription: lineWidthText]]
	}

	func keyPathsForValuesAffectingPreview() -> Set<String> {
		["printScale", "lineWidth"]
	}
}
