//
//  IconGenerator.swift
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

// Makes the app icon: a letter satin-stitched on cloth in a wooden
// embroidery hoop, drawn with Needle Works' own Realistic thread and fabric.
// It is built together with NeedleWorksKit's sources; see make-icon.sh.
//
// usage: IconGenerator <font.ttf> <output .iconset directory> [seed]
//
// The same font and seed always give the same icon.

import AppKit
import CoreText

// MARK: - Settings

/// The letter, and its thread and fabric colors (sRGB, 0–255)
let letter = "N"
let threadColor = (r: 16, g: 30, b: 78)
let fabricColor = (r: 245, g: 242, b: 235)

/// The letter's largest size, in design units (0.1 mm)
let letterSize = CGSize(width: 600, height: 460)

/// Satin stitches are about this far apart, in design units
let stitchSpacing = 1.9

/// The 1024-pixel canvas: the rounded square macOS icons sit in, the hoop,
/// and how many pixels a design unit covers
let canvas: CGFloat = 1024
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileCorner: CGFloat = 185
let hoopCenter = CGPoint(x: 512, y: 528)
let hoopOuterRadius: CGFloat = 352
let hoopInnerRadius: CGFloat = 302
let pixelsPerUnit: CGFloat = 0.78

// MARK: - Repeatable randomness

/// Every random choice comes from here; main seeds it. SeededRandom is in
/// Satin.swift.
var random = SeededRandom(state: 1)

// MARK: - The letter

/// The glyph's outline, `size` at most, centered on the origin, y down
func glyphPath(fontURL: URL, character: String, size: CGSize) -> CGPath {
	guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
		  let descriptor = descriptors.first else {
		fatalError("Can't read the font at \(fontURL.path)")
	}
	let font = CTFontCreateWithFontDescriptor(descriptor, 1000, nil)
	var characters = Array(character.utf16), glyphs = [CGGlyph](repeating: 0, count: characters.count)
	CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
	guard let raw = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
		fatalError("The font has no outline for \(character)")
	}
	let bounds = raw.boundingBoxOfPath
	let scale = min(size.width / bounds.width, size.height / bounds.height)
	var transform = CGAffineTransform(scaleX: scale, y: -scale).translatedBy(x: -bounds.midX, y: -bounds.midY)
	return raw.copy(using: &transform)!
}

// MARK: - Drawing

func srgb(_ c: (r: Int, g: Int, b: Int), _ k: CGFloat = 1) -> CGColor {
	CGColor(srgbRed: CGFloat(c.r) / 255 * k, green: CGFloat(c.g) / 255 * k, blue: CGFloat(c.b) / 255 * k, alpha: 1)
}

/// Draws a CGImage into `rect` of a context whose y runs down
func drawUpright(_ image: CGImage, in rect: CGRect, context: CGContext) {
	context.saveGState()
	context.translateBy(x: 0, y: rect.minY + rect.maxY)
	context.scaleBy(x: 1, y: -1)
	context.draw(image, in: rect)
	context.restoreGState()
}

/// The fabric, in design units around `center`, filling `rect` (pixels)
func drawFabric(_ color: NSColor, in rect: CGRect, context: CGContext) {
	context.saveGState()
	context.translateBy(x: hoopCenter.x, y: hoopCenter.y)
	context.scaleBy(x: pixelsPerUnit, y: pixelsPerUnit)
	let designRect = rect.offsetBy(dx: -hoopCenter.x, dy: -hoopCenter.y).applying(CGAffineTransform(scaleX: 1 / pixelsPerUnit, y: 1 / pixelsPerUnit))
	FabricTexture.shared.draw(Fabric(color: color), in: designRect, context: context)
	context.restoreGState()
}

/// The icon at 1024 pixels: cloth in a rounded square, held in a wooden hoop,
/// with the letter stitched in the middle
func drawIcon(stitches: [(a: CGPoint, b: CGPoint, filling: Bool)]) -> CGImage {
	let size = Int(canvas)
	let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
							space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.translateBy(x: 0, y: canvas)
	context.scaleBy(x: 1, y: -1)
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	let fabric = NSColor(cgColor: srgb(fabricColor))!

	/* The cloth around the hoop, looser and a little darker, in the rounded
	 * square with a soft shadow */
	let tileShape = CGPath(roundedRect: tile, cornerWidth: tileCorner, cornerHeight: tileCorner, transform: nil)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
	context.addPath(tileShape)
	context.setFillColor(srgb(fabricColor, 0.9))
	context.fillPath()
	context.restoreGState()
	context.saveGState()
	context.addPath(tileShape)
	context.clip()
	drawFabric(NSColor(cgColor: srgb(fabricColor, 0.93))!, in: tile, context: context)
	let vignette = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.16)] as CFArray, locations: [0.55, 1])!
	context.drawRadialGradient(vignette, startCenter: hoopCenter, startRadius: 0, endCenter: hoopCenter, endRadius: tile.width * 0.72, options: [.drawsAfterEndLocation])
	context.restoreGState()

	/* The taut cloth inside the hoop, and the stitches */
	let inner = CGRect(x: hoopCenter.x - hoopInnerRadius, y: hoopCenter.y - hoopInnerRadius, width: 2 * hoopInnerRadius, height: 2 * hoopInnerRadius)
	context.saveGState()
	context.addEllipse(in: inner)
	context.clip()
	drawFabric(fabric, in: inner, context: context)
	var kitStitches = [Stitch(start: .zero, end: .zero, type: .normal)]
	kitStitches += stitches.map { Stitch(start: $0.a, end: $0.b, type: .normal) }
	let block = StitchBlock(stitches: kitStitches, color: NSColor(cgColor: srgb(threadColor))!)
	let designRect = CGRect(x: -hoopInnerRadius / pixelsPerUnit, y: -hoopInnerRadius / pixelsPerUnit,
							width: 2 * hoopInnerRadius / pixelsPerUnit, height: 2 * hoopInnerRadius / pixelsPerUnit)
	guard let renderer = ThreadRenderer.shared,
		  let thread = renderer.image(of: [block], style: .realistic, showJumpStitches: false, rect: designRect,
									  pixelsWide: Int(inner.width), pixelsHigh: Int(inner.height)) else {
		fatalError("Can't draw Realistic thread on this Mac")
	}
	drawUpright(thread, in: inner, context: context)

	/* The hoop's shadow on the cloth */
	let shade = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.22)] as CFArray, locations: [0.8, 1])!
	context.drawRadialGradient(shade, startCenter: hoopCenter, startRadius: 0, endCenter: hoopCenter, endRadius: hoopInnerRadius, options: [])
	context.restoreGState()

	/* The wooden hoop */
	let ring = CGMutablePath()
	ring.addEllipse(in: CGRect(x: hoopCenter.x - hoopOuterRadius, y: hoopCenter.y - hoopOuterRadius, width: 2 * hoopOuterRadius, height: 2 * hoopOuterRadius))
	ring.addEllipse(in: inner)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: 8), blur: 18, color: CGColor(gray: 0, alpha: 0.4))
	context.addPath(ring)
	context.setFillColor(CGColor(srgbRed: 0.78, green: 0.6, blue: 0.4, alpha: 1))
	context.fillPath(using: .evenOdd)
	context.restoreGState()
	context.saveGState()
	context.addPath(ring)
	context.clip(using: .evenOdd)
	let wood = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 0.9, green: 0.74, blue: 0.52, alpha: 1),
													   CGColor(srgbRed: 0.72, green: 0.52, blue: 0.32, alpha: 1),
													   CGColor(srgbRed: 0.58, green: 0.4, blue: 0.24, alpha: 1)] as CFArray, locations: [0, 0.6, 1])!
	context.drawLinearGradient(wood, start: CGPoint(x: hoopCenter.x - hoopOuterRadius, y: hoopCenter.y - hoopOuterRadius),
							   end: CGPoint(x: hoopCenter.x + hoopOuterRadius, y: hoopCenter.y + hoopOuterRadius), options: [])
	/* Grain: faint rings at random shades */
	for i in 0..<40 {
		let r = hoopInnerRadius + CGFloat(i) * (hoopOuterRadius - hoopInnerRadius) / 40
		context.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.3, blue: 0.16, alpha: CGFloat.random(in: 0.03...0.12, using: &random)))
		context.setLineWidth(1)
		context.addEllipse(in: CGRect(x: hoopCenter.x - r, y: hoopCenter.y - r, width: 2 * r, height: 2 * r))
		context.strokePath()
	}
	/* Rounded edges: light on the inside top, shadow on the outside bottom */
	let bevel = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0.18), CGColor(gray: 1, alpha: 0), CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.18)] as CFArray, locations: [0, 0.35, 0.65, 1])!
	context.drawRadialGradient(bevel, startCenter: hoopCenter, startRadius: hoopInnerRadius, endCenter: hoopCenter, endRadius: hoopOuterRadius, options: [])
	context.restoreGState()

	drawTensionScrew(context: context, ring: ring)

	return context.makeImage()!
}

/// The tension screw at the top of the hoop. The outer ring is split there,
/// with a brass lug on each side of the split, and a screw through both that's
/// tightened with a knurled thumb nut.
func drawTensionScrew(context: CGContext, ring: CGPath) {
	let space = CGColorSpace(name: CGColorSpace.sRGB)!
	let x = hoopCenter.x, top = hoopCenter.y - hoopOuterRadius
	let gap: CGFloat = 12, lugWidth: CGFloat = 30, lugHeight: CGFloat = 52
	let screwY = top - 6, screwThickness: CGFloat = 9

	/* Brass, lit from above */
	func brass(_ rect: CGRect, corner: CGFloat, shadow: Bool = true) {
		let shape = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
		if shadow {
			context.saveGState()
			context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6, color: CGColor(gray: 0, alpha: 0.45))
			context.addPath(shape)
			context.setFillColor(CGColor(srgbRed: 0.7, green: 0.53, blue: 0.2, alpha: 1))
			context.fillPath()
			context.restoreGState()
		}
		context.saveGState()
		context.addPath(shape)
		context.clip()
		let gradient = CGGradient(colorsSpace: space, colors: [CGColor(srgbRed: 1.0, green: 0.92, blue: 0.62, alpha: 1),
															   CGColor(srgbRed: 0.82, green: 0.64, blue: 0.27, alpha: 1),
															   CGColor(srgbRed: 0.5, green: 0.36, blue: 0.12, alpha: 1)] as CFArray, locations: [0, 0.45, 1])!
		context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
		context.restoreGState()
	}

	/* The split, where the inner ring shows, set back in shadow */
	context.saveGState()
	context.addPath(ring)
	context.clip(using: .evenOdd)
	context.setFillColor(CGColor(srgbRed: 0.42, green: 0.28, blue: 0.15, alpha: 1))
	context.fill(CGRect(x: x - gap / 2, y: top - 2, width: gap, height: hoopOuterRadius - hoopInnerRadius + 4))
	context.restoreGState()

	/* The screw, through both lugs, with its head on the left and the thumb
	 * nut on the right */
	let left = x - gap / 2 - lugWidth, right = x + gap / 2 + lugWidth
	brass(CGRect(x: left - 6, y: screwY - screwThickness / 2, width: right - left + 22, height: screwThickness), corner: screwThickness / 2)
	brass(CGRect(x: left, y: top - lugHeight + 22, width: lugWidth, height: lugHeight), corner: 6)
	brass(CGRect(x: x + gap / 2, y: top - lugHeight + 22, width: lugWidth, height: lugHeight), corner: 6)
	brass(CGRect(x: left - 9, y: screwY - 9, width: 9, height: 18), corner: 3)

	let nut = CGRect(x: right + 8, y: screwY - 24, width: 16, height: 48)
	brass(nut, corner: 4)
	context.saveGState()
	context.clip(to: nut)
	context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.24, blue: 0.08, alpha: 0.55))
	context.setLineWidth(1.2)
	var knurl = nut.minY + 3
	while knurl < nut.maxY {
		context.move(to: CGPoint(x: nut.minX, y: knurl))
		context.addLine(to: CGPoint(x: nut.maxX, y: knurl))
		knurl += 4
	}
	context.strokePath()
	context.restoreGState()
}

/// The image scaled to `pixels` square
func scaled(_ image: CGImage, to pixels: Int) -> CGImage {
	let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
							space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	context.interpolationQuality = .high
	context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
	return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
	guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
		fatalError("Can't write \(url.path)")
	}
	CGImageDestinationAddImage(destination, image, nil)
	CGImageDestinationFinalize(destination)
}

// MARK: - Main

@main
struct IconGenerator {
	static func main() throws {
		let arguments = CommandLine.arguments
		guard arguments.count >= 3 else {
			FileHandle.standardError.write("usage: IconGenerator <font.ttf> <output .iconset directory> [seed]\n".data(using: .utf8)!)
			exit(2)
		}
		random = SeededRandom(state: arguments.count > 3 ? UInt64(arguments[3])! : 1)
		let fontURL = URL(fileURLWithPath: arguments[1])
		let iconset = URL(fileURLWithPath: arguments[2])
		try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

		let path = glyphPath(fontURL: fontURL, character: letter, size: letterSize)
		let stitches = satinStitches(for: path, spacing: stitchSpacing, random: &random)
		print("\(stitches.count) stitches")
		let icon = drawIcon(stitches: stitches)

		/* The sizes an .iconset holds */
		for points in [16, 32, 128, 256, 512] {
			for scale in [1, 2] {
				let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
				let pixels = points * scale
				writePNG(pixels == Int(canvas) ? icon : scaled(icon, to: pixels), to: iconset.appendingPathComponent(name))
			}
		}
	}
}
