//
//  DesignView.swift
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

/// Shows a design. It keeps an image of the whole design at the zoom it was
/// last shown at, and draws it again sharp when the zoom changes.
@objc(DesignView)
final class DesignView: NSView {
	@objc weak var delegate: PESDocument?

	/// The largest image of the whole design the view keeps for redrawing and
	/// zooming, in pixels (48 MB). Beyond this zoom only part of the design is
	/// visible, and drawing just that part is fast.
	private static let maximumImagePixels: CGFloat = 12e6

	/// Everything besides the zoom that changes how the design looks
	private struct Settings: Equatable, @unchecked Sendable {
		var style: StitchStyle
		var showJumpStitches: Bool
		var lineWidth: CGFloat
		var fabricColor: NSColor
		var fabricTexture: Bool

		@MainActor init(_ doc: PESDocument) {
			style = doc.stitchStyle
			showJumpStitches = doc.showJumpStitches
			lineWidth = doc.lineWidth
			fabricColor = doc.fabricColor
			fabricTexture = doc.showsFabricTexture
		}
	}

	/// What a background render needs, handed to the render queue. The stitch
	/// blocks and colors are never changed once made.
	private struct RenderJob: @unchecked Sendable {
		var stitchBlocks: [StitchBlock]
		var settings: Settings
		var rect: NSRect
		var pixelRect: CGRect
	}

	/// An image made in the background, handed back to the main thread
	private struct Rendered: @unchecked Sendable {
		var image: NSImage?
	}

	/// The number of the latest background render requested, so older ones
	/// are skipped
	private final class LatestRender: @unchecked Sendable {
		private let lock = NSLock()
		private var number = 0

		func next() -> Int {
			lock.lock()
			defer { lock.unlock() }
			number += 1
			return number
		}

		func isLatest(_ n: Int) -> Bool {
			lock.lock()
			defer { lock.unlock() }
			return n == number
		}
	}

	/* The whole design drawn at the zoom it was last shown at, the area it
	 * covers in design units, and the settings it was drawn with */
	private var designImage: NSImage?
	private var designImageRect = NSRect.zero
	private var designImageSettings: Settings?

	/* Images are drawn in the background, one at a time; each request has a
	 * new number, so only the latest one is used */
	private let renderQueue = DispatchQueue(label: "org.spacecoaster.NeedleWorks.DesignView")
	private let latestRender = LatestRender()
	private var requestedRect = NSRect.zero
	private var requestedSettings: Settings?

	private var liveMagnifying = false
	private var shownMagnification: CGFloat = 0

	/// Whether two areas cover the same pixels, allowing for rounding
	private static func samePixels(_ context: CGContext, _ a: NSRect, _ b: NSRect) -> Bool {
		let da = context.convertToDeviceSpace(a), db = context.convertToDeviceSpace(b)
		return abs(da.minX - db.minX) < 0.01 && abs(da.minY - db.minY) < 0.01 &&
			abs(da.width - db.width) < 0.01 && abs(da.height - db.height) < 0.01
	}

	nonisolated private static func image(of stitchBlocks: [StitchBlock], settings: Settings, rect: NSRect, pixelRect: CGRect) -> NSImage? {
		PESRenderer.image(of: stitchBlocks, style: settings.style, fabricColor: settings.fabricColor, fabricTexture: settings.fabricTexture,
						  lineWidth: settings.lineWidth, showJumpStitches: settings.showJumpStitches,
						  rect: rect, pixelsWide: Int(pixelRect.width), pixelsHigh: Int(pixelRect.height))
	}

	private var stitchBlocks: [StitchBlock] {
		delegate?.stitchBlocks ?? []
	}

	override func draw(_ rect: NSRect) {
		guard let doc = delegate, let context = NSGraphicsContext.current?.cgContext else {
			return
		}
		let settings = Settings(doc)

		/* The pixels the design covers at the current zoom, and the area those
		 * whole pixels cover in design units, so an image of it lines up with
		 * the screen's pixels */
		let pixelRect = context.convertToDeviceSpace(bounds).integral
		let imageRect = context.convertToUserSpace(pixelRect)
		let imageFits = pixelRect.width * pixelRect.height <= Self.maximumImagePixels
		let image = designImageSettings == settings ? designImage : nil

		if let image, Self.samePixels(context, designImageRect, imageRect) {
			image.draw(in: designImageRect)
			return
		}

		/* While zooming, scale the image last drawn; a sharp one is drawn when
		 * the zoom settles */
		if let image, liveMagnifying || imageFits {
			image.draw(in: designImageRect)
			if !liveMagnifying && imageFits {
				requestImage(settings: settings, rect: imageRect, pixelRect: pixelRect, context: context)
			}
			return
		}

		if imageFits {
			designImage = Self.image(of: stitchBlocks, settings: settings, rect: imageRect, pixelRect: pixelRect)
			designImageRect = imageRect
			designImageSettings = settings
			designImage?.draw(in: designImageRect)
			return
		}

		PESRenderer.draw(stitchBlocks, style: settings.style, fabricColor: settings.fabricColor, fabricTexture: settings.fabricTexture,
						 lineWidth: settings.lineWidth, showJumpStitches: settings.showJumpStitches, in: rect)
	}

	/// Draws an image of the design in the background, then shows it
	private func requestImage(settings: Settings, rect: NSRect, pixelRect: CGRect, context: CGContext) {
		if requestedSettings == settings && Self.samePixels(context, requestedRect, rect) {
			return
		}
		requestedRect = rect
		requestedSettings = settings

		let number = latestRender.next()
		let latestRender = latestRender
		let job = RenderJob(stitchBlocks: stitchBlocks, settings: settings, rect: rect, pixelRect: pixelRect)
		renderQueue.async { [weak self] in
			/* Skip requests that a newer one has replaced */
			guard latestRender.isLatest(number) else {
				return
			}
			let rendered = Rendered(image: DesignView.image(of: job.stitchBlocks, settings: job.settings, rect: job.rect, pixelRect: job.pixelRect))
			DispatchQueue.main.async {
				MainActor.assumeIsolated {
					guard let self, latestRender.isLatest(number) else {
						return
					}
					self.designImage = rendered.image
					self.designImageRect = job.rect
					self.designImageSettings = job.settings
					self.requestedSettings = nil
					self.needsDisplay = true
				}
			}
		}
	}

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		let center = NotificationCenter.default
		center.removeObserver(self, name: NSScrollView.willStartLiveMagnifyNotification, object: nil)
		center.removeObserver(self, name: NSScrollView.didEndLiveMagnifyNotification, object: nil)
		center.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
	}

	override func viewDidMoveToWindow() {
		guard let scrollView = enclosingScrollView else {
			return
		}
		let center = NotificationCenter.default
		center.addObserver(self, selector: #selector(willStartLiveMagnify(_:)), name: NSScrollView.willStartLiveMagnifyNotification, object: scrollView)
		center.addObserver(self, selector: #selector(didEndLiveMagnify(_:)), name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)

		/* Zooming changes the clip view's bounds */
		let clipView = scrollView.contentView
		clipView.postsBoundsChangedNotifications = true
		center.addObserver(self, selector: #selector(clipViewBoundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: clipView)
	}

	/// Redraws once AppKit's current display pass is over
	private func redrawSoon() {
		DispatchQueue.main.async { [weak self] in
			MainActor.assumeIsolated {
				self?.needsDisplay = true
			}
		}
	}

	/// When the zoom changes, AppKit can scale what the view last drew without
	/// asking it to draw again, for example when a window is restored zoomed
	/// in. Redraw at the new zoom once AppKit's display pass is over.
	@objc private func clipViewBoundsDidChange(_ notification: Notification) {
		let magnification = enclosingScrollView?.magnification ?? 1
		if magnification == shownMagnification || liveMagnifying {
			return
		}
		shownMagnification = magnification
		redrawSoon()
	}

	/// Moving to a screen with a different resolution needs a new image
	override func viewDidChangeBackingProperties() {
		super.viewDidChangeBackingProperties()
		needsDisplay = true
	}

	@objc private func willStartLiveMagnify(_ notification: Notification) {
		liveMagnifying = true
	}

	@objc private func didEndLiveMagnify(_ notification: Notification) {
		liveMagnifying = false
		shownMagnification = enclosingScrollView?.magnification ?? 1

		/* AppKit redraws for the final zoom before telling us the gesture has
		 * ended, so that redraw showed the scaled image. Ask for a sharp one
		 * once AppKit's own display pass is over, or the request is lost. */
		redrawSoon()
	}

	/* http://developer.apple.com/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/chapter_8_section_7.html */
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		invalidateExposedRects()
	}

	/// We want to draw with (0, 0) at the top left
	override var isFlipped: Bool {
		true
	}

	override var isOpaque: Bool {
		true
	}
}
