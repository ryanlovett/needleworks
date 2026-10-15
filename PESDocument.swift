//
//  PESDocument.swift
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

/// A design file, shown in its own window and printed with a legend.
@objc(PESDocument)
final class PESDocument: NSDocument, NSToolbarDelegate, NSWindowDelegate, NSSplitViewDelegate {
	/// Points per design unit (0.1 mm) at 100% zoom. This is the design
	/// view's base scale; true life size depends on the screen (see
	/// actualSizeZoom).
	private static let pointsPerUnit: CGFloat = 100.0 / 254

	/// Zoom limits, and the factor each Zoom In or Zoom Out step changes by
	private static let minimumZoom: CGFloat = 0.1
	private static let maximumZoom: CGFloat = 16
	private static let zoomStep: CGFloat = 2.0.squareRoot()

	/// Plain lines are 1 to 8 design units (0.1 to 0.8 mm) wide, 0.2 mm
	/// unless chosen otherwise
	private static let minimumLineWidth = 1
	private static let maximumLineWidth = 8
	private static let defaultLineWidth: CGFloat = 2

	/// Document window toolbar items
	private static let zoomOutItem = NSToolbarItem.Identifier("ZoomOut")
	private static let zoomInItem = NSToolbarItem.Identifier("ZoomIn")
	private static let zoomToFitItem = NSToolbarItem.Identifier("ZoomToFit")
	private static let actualSizeItem = NSToolbarItem.Identifier("ActualSize")
	private static let designInformationItem = NSToolbarItem.Identifier("DesignInformation")
	private static let stitchStyleItem = NSToolbarItem.Identifier("StitchStyle")
	private static let fabricColorItem = NSToolbarItem.Identifier("FabricColor")
	private static let lineWidthItem = NSToolbarItem.Identifier("LineWidth")

	@IBOutlet var mainView: DesignView?
	@IBOutlet var printView: PrintView?
	@IBOutlet var splitView: NSSplitView?
	@IBOutlet var legendPrintView: LegendPrintView?

	/* What the Design Information panel shows */
	@objc dynamic var docName = ""
	@objc dynamic var docSize = ""
	@objc dynamic var designSize = ""
	@objc dynamic var numStitches = 0
	@objc dynamic var numColors = 0
	@objc dynamic var numColorChanges = 0

	/// The design's stitches, one block per thread color
	@objc private(set) var stitchBlocks: [StitchBlock] = []

	/* The design's extent, in design units */
	private var minPoint = CGPoint.zero
	private var maxPoint = CGPoint.zero

	/// The fabric chosen for this window from the toolbar, if any
	private var ownFabric: Fabric?

	/// The style chosen for this window from View > Stitch Style, if any
	private var ownStitchStyle: StitchStyle?

	/// The design file's fingerprint, under which the choices made for its
	/// window are remembered; nil until they've been restored
	private var fingerprint: String?

	private var emptyDesignLabel: NSTextField?
	private var hasSizedWindow = false

	/// The print panel accessory of the current print operation, if any
	@objc private(set) weak var printScaleAccessory: PrintScaleAccessoryController?

	/* The toolbar's controls, when they're in the toolbar */
	private weak var stitchStylePopUp: NSPopUpButton?
	@objc private(set) weak var fabricColorPopUp: FabricColorPopUpButton?
	@objc private(set) weak var lineWidthSlider: NSSlider?

	override var windowNibName: NSNib.Name? {
		"PESDocument"
	}

	override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
		super.windowControllerDidLoadNib(windowController)
		guard let mainView, let scrollView = mainView.enclosingScrollView, let window = mainView.window else {
			return
		}
		mainView.delegate = self
		printView?.delegate = self
		splitView?.delegate = self
		legendPrintView?.delegate = self

		/* The design view's bounds are in design units (0.1 mm) and its frame
		 * is in points at 100% zoom. Designs do not always originate from
		 * (0, 0); some are even (<0, <0). Keep at least one unit in each
		 * direction so blank or perfectly straight designs still have a
		 * valid size. */
		let designRect = NSRect(x: minPoint.x, y: minPoint.y, width: max(maxPoint.x - minPoint.x, 1), height: max(maxPoint.y - minPoint.y, 1))
		mainView.frame = NSRect(x: 0, y: 0, width: designRect.width * Self.pointsPerUnit, height: designRect.height * Self.pointsPerUnit)
		mainView.bounds = designRect

		/* Fill the area around a centered design with the fabric color, so
		 * the design appears to sit on one continuous piece of fabric. */
		scrollView.backgroundColor = fabric.flatColor

		/* Users zoom with the View menu or by pinching on a trackpad; there
		 * is nothing to zoom in a blank design */
		scrollView.allowsMagnification = numStitches > 0
		scrollView.minMagnification = Self.minimumZoom
		scrollView.maxMagnification = Self.maximumZoom

		/* Keep the window large enough to be easy to see, move and close,
		 * even for blank designs or designs with very few stitches. */
		window.contentMinSize = NSSize(width: 480, height: 300)

		/* Follow the stitch style in Settings until this window has its own */
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)),
											   name: UserDefaults.didChangeNotification, object: nil)

		/* Toolbar with zoom controls and the Design Information panel */
		let toolbar = NSToolbar(identifier: "PESDocumentToolbar")
		toolbar.delegate = self
		toolbar.allowsUserCustomization = true
		toolbar.autosavesConfiguration = true
		toolbar.displayMode = .iconOnly
		window.toolbar = toolbar

		/* A blank design has nothing to draw, so say so rather than showing
		 * an empty window. */
		if numStitches == 0, let contentView = window.contentView {
			let label = NSTextField(labelWithString: NSLocalizedString("This design has no stitches.", comment: "Shown in the window of a design with no stitches"))
			label.font = .systemFont(ofSize: NSFont.systemFontSize + 2)
			label.translatesAutoresizingMaskIntoConstraints = false
			contentView.addSubview(label)
			NSLayoutConstraint.activate([
				label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
				label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			])
			emptyDesignLabel = label
			updateEmptyDesignLabelColor()
		}
	}

	/// Once the window is on screen (and has any tab bar it's going to get),
	/// we size it so that the entire design is visible without scrolling (see
	/// windowWillUseStandardFrame). If the screen is smaller than the design,
	/// the scroll view will help us out.
	override func showWindows() {
		super.showWindows()

		guard !hasSizedWindow, let window = mainView?.window else {
			return
		}
		hasSizedWindow = true

		/* Open designs at their actual (life) size */
		if numStitches > 0 {
			mainView?.enclosingScrollView?.magnification = actualSizeZoom
		}

		if let screenFrame = window.screen?.visibleFrame {
			window.setFrame(windowWillUseStandardFrame(window, defaultFrame: screenFrame), display: true)
		}
	}

	/// The window's standard ("zoomed") frame fits the whole design at the
	/// current zoom, within the screen, keeping the window's top-left corner.
	func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
		guard let mainView, let scrollView = mainView.enclosingScrollView else {
			return window.frame
		}
		let zoom = scrollView.magnification

		/* Everything in the window other than the visible design area, such as
		 * the title bar, toolbar, scrollers and borders, stays the same size */
		var frame = window.frame
		let visibleSize = scrollView.contentView.frame.size
		let designSize = mainView.frame.size
		frame.size.width += designSize.width * zoom - visibleSize.width
		frame.size.height += designSize.height * zoom - visibleSize.height

		let minSize = window.minSize
		frame.size.width = min(max(frame.width, minSize.width), newFrame.width)
		frame.size.height = min(max(frame.height, minSize.height), newFrame.height)

		frame.origin.x = min(window.frame.minX, newFrame.maxX - frame.width)
		frame.origin.y = max(window.frame.maxY - frame.height, newFrame.minY)
		return frame
	}

	// MARK: Zooming

	/// Zoom by setting the scroll view's magnification, keeping the center of
	/// the visible area in place
	private func setZoom(_ zoom: CGFloat) {
		guard let scrollView = mainView?.enclosingScrollView else {
			return
		}
		let visible = scrollView.contentView.bounds
		scrollView.setMagnification(zoom, centeredAt: NSPoint(x: visible.midX, y: visible.midY))
	}

	private var zoom: CGFloat {
		mainView?.enclosingScrollView?.magnification ?? 1
	}

	@IBAction func zoomIn(_ sender: Any?) {
		setZoom(zoom * Self.zoomStep)
	}

	@IBAction func zoomOut(_ sender: Any?) {
		setZoom(zoom / Self.zoomStep)
	}

	/// The zoom at which the design appears at its real, physical size on
	/// the screen showing the window, so it can be compared with fabric or a
	/// hoop. Falls back to 100% if the display doesn't report its physical
	/// size.
	private var actualSizeZoom: CGFloat {
		guard let screen = mainView?.window?.screen ?? NSScreen.main,
			  let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
			return 1
		}
		let physicalSize = CGDisplayScreenSize(displayID.uint32Value)
		if physicalSize.width <= 0 {
			return 1
		}

		let pointsPerMillimeter = screen.frame.width / physicalSize.width
		let zoom = (pointsPerMillimeter / 10) / Self.pointsPerUnit
		return min(max(zoom, Self.minimumZoom), Self.maximumZoom)
	}

	@IBAction func zoomToActualSize(_ sender: Any?) {
		setZoom(actualSizeZoom)
	}

	@IBAction func zoomToFit(_ sender: Any?) {
		if let mainView {
			mainView.enclosingScrollView?.magnify(toFit: mainView.frame)
		}
	}

	override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
		let menuItem = item as? NSMenuItem

		switch item.action {
		/* There's nothing to zoom in a blank design */
		case #selector(zoomIn(_:)):
			return numStitches > 0 && zoom < Self.maximumZoom
		case #selector(zoomOut(_:)):
			return numStitches > 0 && zoom > Self.minimumZoom
		case #selector(zoomToActualSize(_:)), #selector(zoomToFit(_:)):
			return numStitches > 0
		case #selector(chooseStitchStyle(_:)):
			/* Check the window's style, and offer only the styles that can be drawn */
			let style = StitchStyle(rawValue: item.tag) ?? .plain
			menuItem?.state = style == stitchStyle ? .on : .off
			return PESRenderer.canDraw(style)
		case #selector(toggleJumpStitches(_:)):
			menuItem?.state = showJumpStitches ? .on : .off
			return numStitches > 0
		case #selector(chooseLineWidth(_:)):
			/* Only Plain draws lines */
			menuItem?.state = item.tag == Int(lineWidth.rounded()) ? .on : .off
			return stitchStyle == .plain
		case #selector(printDocument(_:)):
			/* ...and nothing to print */
			return numStitches > 0 && super.validateUserInterfaceItem(item)
		default:
			return super.validateUserInterfaceItem(item)
		}
	}

	// MARK: Toolbar

	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		[Self.zoomOutItem, Self.zoomInItem, Self.zoomToFitItem, Self.stitchStyleItem, Self.lineWidthItem,
		 Self.fabricColorItem, .flexibleSpace, Self.designInformationItem]
	}

	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		[Self.zoomOutItem, Self.zoomInItem, Self.zoomToFitItem, Self.actualSizeItem,
		 Self.stitchStyleItem, Self.lineWidthItem, Self.fabricColorItem, Self.designInformationItem, .space, .flexibleSpace]
	}

	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		let label: String, toolTip: String, symbol: String
		let action: Selector

		switch identifier {
		case Self.zoomOutItem:
			label = NSLocalizedString("Zoom Out", comment: "Toolbar item")
			toolTip = NSLocalizedString("Make the design smaller", comment: "Toolbar item tooltip")
			symbol = "minus.magnifyingglass"
			action = #selector(zoomOut(_:))
		case Self.zoomInItem:
			label = NSLocalizedString("Zoom In", comment: "Toolbar item")
			toolTip = NSLocalizedString("Make the design larger", comment: "Toolbar item tooltip")
			symbol = "plus.magnifyingglass"
			action = #selector(zoomIn(_:))
		case Self.zoomToFitItem:
			label = NSLocalizedString("Zoom to Fit", comment: "Toolbar item")
			toolTip = NSLocalizedString("Fit the design to the window", comment: "Toolbar item tooltip")
			symbol = "arrow.up.left.and.down.right.magnifyingglass"
			action = #selector(zoomToFit(_:))
		case Self.actualSizeItem:
			label = NSLocalizedString("Actual Size", comment: "Toolbar item")
			toolTip = NSLocalizedString("Show the design at its actual size", comment: "Toolbar item tooltip")
			symbol = "1.magnifyingglass"
			action = #selector(zoomToActualSize(_:))
		case Self.stitchStyleItem:
			return stitchStyleToolbarItem(identifier, willBeInsertedIntoToolbar: flag)
		case Self.fabricColorItem:
			return fabricColorToolbarItem(identifier, willBeInsertedIntoToolbar: flag)
		case Self.lineWidthItem:
			return lineWidthToolbarItem(identifier, willBeInsertedIntoToolbar: flag)
		case Self.designInformationItem:
			label = NSLocalizedString("Design Info", comment: "Toolbar item")
			toolTip = NSLocalizedString("Show or hide the Design Information panel", comment: "Toolbar item tooltip")
			symbol = "info.circle"
			action = #selector(AppDelegate.toggleInspectorPanel(_:))
		default:
			return nil
		}

		let item = NSToolbarItem(itemIdentifier: identifier)
		item.label = label
		item.paletteLabel = label
		item.toolTip = toolTip
		item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
		item.action = action
		item.isBordered = true
		return item
	}

	/// Keep the empty design message readable on both light and dark fabrics
	private func updateEmptyDesignLabelColor() {
		var brightness: CGFloat = 1
		if let rgb = fabric.flatColor.usingColorSpace(.sRGB) {
			brightness = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
		}
		emptyDesignLabel?.textColor = NSColor(white: brightness > 0.5 ? 0 : 1, alpha: 0.55)
	}

	/// The window's title is the design's file name
	override var displayName: String! {
		get {
			docName
		}
		set {
			super.displayName = newValue
		}
	}

	/// Reads the design. Documents of this class aren't read concurrently
	/// (canConcurrentlyReadDocuments is false), so this runs on the main thread.
	nonisolated override func read(from url: URL, ofType typeName: String) throws {
		let parser = try PESDocumentParser(contentsOf: url)
		let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber
		let fingerprint = (try? Data(contentsOf: url)).map(DesignSettings.fingerprint(of:))

		MainActor.assumeIsolated {
			docName = url.lastPathComponent
			docSize = fileSize?.stringValue ?? ""
			stitchBlocks = parser.stitchBlocks
			minPoint = parser.minPoint
			maxPoint = parser.maxPoint
			numColors = parser.numColors
			numColorChanges = parser.numColorChanges
			numStitches = parser.numStitches
			designSize = parser.designSize

			/* The choices made for this design last time, before the window
			 * opens; they're remembered again once it's known which design
			 * this is */
			if let fingerprint {
				let remembered = DesignSettings.load(for: fingerprint)
				ownFabric = remembered.fabric
				ownStitchStyle = remembered.stitchStyle
				lineWidth = remembered.lineWidth ?? Self.defaultLineWidth
				showJumpStitches = remembered.showJumpStitches ?? true
				self.fingerprint = fingerprint
			}
		}
	}

	/// Remembers the choices made for this design's window
	private func rememberChoices() {
		guard let fingerprint else {
			return
		}
		DesignSettings.save(DesignSettings(fabric: ownFabric, stitchStyle: ownStitchStyle,
										   lineWidth: lineWidth == Self.defaultLineWidth ? nil : lineWidth,
										   showJumpStitches: showJumpStitches ? nil : false),
							for: fingerprint)
	}

	// MARK: Printing

	/// Lay out the printed page for the print info's paper size, orientation
	/// and margins, and scale the design. This runs each time the print
	/// system paginates (see PrintLayoutSplitView), so the layout and the
	/// print panel's preview follow any changes made in the print panel.
	@objc func layoutPrintViews(for printInfo: NSPrintInfo) {
		guard let splitView, let printView else {
			return
		}
		let paperSize = printInfo.paperSize
		let printableRect = printInfo.imageablePageBounds

		/* The page margins, the same on both sides and never negative */
		let marginL = printableRect.minX
		let marginR = paperSize.width - printableRect.maxX
		let marginB = printableRect.minY
		let marginT = paperSize.height - printableRect.maxY
		let marginLR = max(0, marginL, marginR)
		let marginTB = max(0, marginT, marginB)
		printInfo.leftMargin = marginLR
		printInfo.rightMargin = marginLR
		printInfo.topMargin = marginTB
		printInfo.bottomMargin = marginTB

		/* The split view fills the whole page */
		splitView.setFrameSize(NSSize(width: paperSize.width - marginLR * 2, height: paperSize.height - marginTB * 2))

		/* The printed design view's frame is in printer points (1/72 inch)
		 * and its bounds are in design units (0.1 mm), so the bounds size
		 * sets the printed scale. Work it out from the view's current frame
		 * each time, since the frame changes with the paper size and
		 * orientation. */
		let printSize = printView.frame.size
		let xdiff = maxPoint.x - minPoint.x
		let ydiff = maxPoint.y - minPoint.y

		/* Design units per printer point at actual size: 254 tenths of a
		 * millimetre per inch, 72 points per inch */
		var unitsPerPoint: CGFloat = 254.0 / 72

		/* Scaled to fit the page, keeping its proportions, if chosen */
		let printScale = UserDefaults.standard.integer(forKey: PrintScaleAccessoryController.printScaleKey)
		if printScale == 1 && xdiff > 0 && ydiff > 0 {
			unitsPerPoint = max(xdiff / printSize.width, ydiff / printSize.height)
		}

		printView.bounds = NSRect(x: minPoint.x, y: minPoint.y, width: printSize.width * unitsPerPoint, height: printSize.height * unitsPerPoint)

		/* Warn in the print panel if the design will be cut off at actual
		 * size (allowing half a point for rounding) */
		let tooLarge = printScale != 1 && (xdiff / unitsPerPoint > printSize.width + 0.5 ||
										   ydiff / unitsPerPoint > printSize.height + 0.5)
		printScaleAccessory?.designTooLarge = tooLarge
	}

	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
		guard let splitView else {
			throw CocoaError(.featureUnsupported)
		}
		let printInfo = self.printInfo
		printInfo.horizontalPagination = .fit
		printInfo.verticalPagination = .fit
		layoutPrintViews(for: printInfo)

		let operation = NSPrintOperation(view: splitView, printInfo: printInfo)

		/* Let people choose the print scale in the print panel itself. The
		 * accessory's too-large warning is updated whenever the page is laid
		 * out again during pagination. */
		let printPanel = operation.printPanel
		let accessory = PrintScaleAccessoryController()
		accessory.lineWidth = lineWidth
		printPanel.addAccessoryController(accessory)
		printScaleAccessory = accessory
		printPanel.options.formUnion([.showsPaperSize, .showsOrientation, .showsPreview])
		return operation
	}

	// MARK: Fabric

	/// The window's own fabric if one was chosen, otherwise the one in
	/// Settings
	var fabric: Fabric {
		get {
			ownFabric ?? SettingsWindowController.defaultFabric
		}
		set {
			ownFabric = newValue
			showFabric()
			rememberChoices()
		}
	}

	/// Whether the fabric is drawn with a woven texture, when View > Show
	/// Fabric Texture is on
	@objc var showsFabricTexture: Bool {
		UserDefaults.standard.bool(forKey: SettingsWindowController.fabricTextureKey)
	}

	private func showFabric() {
		fabricColorPopUp?.fabric = fabric
		mainView?.enclosingScrollView?.backgroundColor = fabric.flatColor
		updateEmptyDesignLabelColor()
		mainView?.needsDisplay = true

		/* The area around the design shows the fabric too */
		mainView?.enclosingScrollView?.contentView.needsDisplay = true
	}

	@objc private func chooseFabric(_ sender: FabricColorPopUpButton) {
		fabric = sender.fabric
	}

	/// A pop-up of fabric colors, which changes the window's fabric
	private func fabricColorToolbarItem(_ identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem {
		let popUp = FabricColorPopUpButton(frame: .zero, pullsDown: false)
		popUp.fabric = fabric
		popUp.target = self
		popUp.action = #selector(chooseFabric(_:))
		if flag {
			fabricColorPopUp = popUp
		}

		let label = NSLocalizedString("Fabric", comment: "Toolbar item")
		let item = NSToolbarItem(itemIdentifier: identifier)
		item.label = label
		item.paletteLabel = label
		item.toolTip = NSLocalizedString("Choose the color of the fabric in this window", comment: "Toolbar item tooltip")
		item.view = popUp

		/* When the window is too narrow for the pop-up, the toolbar's
		 * overflow menu shows the fabrics as a submenu */
		let menuForm = NSMenuItem(title: label, action: nil, keyEquivalent: "")
		menuForm.submenu = popUp.menu?.copy() as? NSMenu
		item.menuFormRepresentation = menuForm
		return item
	}

	// MARK: Line width

	/// The width of lines in the Plain style, in design units
	@objc var lineWidth: CGFloat = PESDocument.defaultLineWidth {
		didSet {
			lineWidthSlider?.doubleValue = lineWidth
			mainView?.needsDisplay = true
			rememberChoices()
		}
	}

	/// The width of printed lines: the one chosen in the print panel while
	/// it's open, otherwise the window's
	@objc var printLineWidth: CGFloat {
		printScaleAccessory?.lineWidth ?? lineWidth
	}

	@IBAction func chooseLineWidth(_ sender: Any?) {
		/* The sender is the toolbar's slider, or a menu item */
		if let slider = sender as? NSSlider {
			lineWidth = slider.doubleValue
		} else if let menuItem = sender as? NSMenuItem {
			lineWidth = CGFloat(menuItem.tag)
		}
	}

	/// A slider for the width of Plain lines, which is enabled only in Plain
	private func lineWidthToolbarItem(_ identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem {
		let slider = NSSlider(value: Double(lineWidth), minValue: Double(Self.minimumLineWidth), maxValue: Double(Self.maximumLineWidth),
							  target: self, action: #selector(chooseLineWidth(_:)))
		slider.numberOfTickMarks = Self.maximumLineWidth - Self.minimumLineWidth + 1
		slider.allowsTickMarkValuesOnly = true
		slider.controlSize = .small
		slider.widthAnchor.constraint(equalToConstant: 96).isActive = true
		slider.isEnabled = stitchStyle == .plain
		if flag {
			lineWidthSlider = slider
		}

		let label = NSLocalizedString("Line Width", comment: "Toolbar item")
		let item = NSToolbarItem(itemIdentifier: identifier)
		item.label = label
		item.paletteLabel = label
		item.toolTip = NSLocalizedString("Choose how wide the lines are in the Plain stitch style", comment: "Toolbar item tooltip")
		item.view = slider

		/* When the window is too narrow for the slider, the toolbar's
		 * overflow menu shows the widths as a submenu */
		let menu = NSMenu(title: label)
		for width in Self.minimumLineWidth...Self.maximumLineWidth {
			let title = String.localizedStringWithFormat(NSLocalizedString("%.1f mm", comment: "Line width in millimetres"), Double(width) / 10)
			let menuItem = menu.addItem(withTitle: title, action: #selector(chooseLineWidth(_:)), keyEquivalent: "")
			menuItem.tag = width
		}
		let menuForm = NSMenuItem(title: label, action: nil, keyEquivalent: "")
		menuForm.submenu = menu
		item.menuFormRepresentation = menuForm
		return item
	}

	// MARK: Jump stitches

	@objc var showJumpStitches = true {
		didSet {
			mainView?.needsDisplay = true
			rememberChoices()
		}
	}

	@IBAction func toggleJumpStitches(_ sender: Any?) {
		showJumpStitches.toggle()
	}

	// MARK: Stitch style

	/// The window's own stitch style if one was chosen, otherwise the one in
	/// Settings
	@objc var stitchStyle: StitchStyle {
		let style = ownStitchStyle ?? StitchStyle(rawValue: UserDefaults.standard.integer(forKey: SettingsWindowController.stitchStyleKey)) ?? .plain
		return PESRenderer.canDraw(style) ? style : .plain
	}

	/// A pop-up showing the window's stitch style, which changes it like
	/// View > Stitch Style does
	private func stitchStyleToolbarItem(_ identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem {
		/* The pop-up's items aren't validated through the window's responder
		 * chain, so it sends its action straight to the document, and offers
		 * the styles the renderer can draw */
		let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
		popUp.autoenablesItems = false
		let titles = SettingsWindowController.stitchStyleTitles
		for (style, title) in titles.enumerated() {
			popUp.addItem(withTitle: title)
			popUp.lastItem?.tag = style
			popUp.lastItem?.isEnabled = PESRenderer.canDraw(StitchStyle(rawValue: style) ?? .plain)
		}
		popUp.target = self
		popUp.action = #selector(chooseStitchStyle(_:))
		popUp.selectItem(withTag: stitchStyle.rawValue)
		if flag {
			stitchStylePopUp = popUp
		}

		let label = NSLocalizedString("Stitch Style", comment: "Toolbar item")
		let item = NSToolbarItem(itemIdentifier: identifier)
		item.label = label
		item.paletteLabel = label
		item.toolTip = NSLocalizedString("Choose how stitches look in this window", comment: "Toolbar item tooltip")
		item.view = popUp

		/* When the window is too narrow for the pop-up, the toolbar's
		 * overflow menu shows the styles as a submenu */
		let menu = NSMenu(title: label)
		for (style, title) in titles.enumerated() {
			let menuItem = menu.addItem(withTitle: title, action: #selector(chooseStitchStyle(_:)), keyEquivalent: "")
			menuItem.tag = style
		}
		let menuForm = NSMenuItem(title: label, action: nil, keyEquivalent: "")
		menuForm.submenu = menu
		item.menuFormRepresentation = menuForm
		return item
	}

	private func showStitchStyle() {
		stitchStylePopUp?.selectItem(withTag: stitchStyle.rawValue)
		lineWidthSlider?.isEnabled = stitchStyle == .plain
		mainView?.needsDisplay = true

		/* The area around the design shows the fabric too */
		mainView?.enclosingScrollView?.contentView.needsDisplay = true
	}

	@IBAction func chooseStitchStyle(_ sender: Any?) {
		/* The sender is a menu item, or the toolbar's pop-up */
		let item = (sender as? NSPopUpButton)?.selectedItem ?? sender as? NSMenuItem
		guard let item, let style = StitchStyle(rawValue: item.tag) else {
			return
		}
		ownStitchStyle = style
		showStitchStyle()
		rememberChoices()
	}

	@objc private func userDefaultsDidChange(_ notification: Notification) {
		/* The stitch style or fabric color in Settings, or the fabric
		 * texture, may have changed */
		showStitchStyle()
		showFabric()
	}
}
