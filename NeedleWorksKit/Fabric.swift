//
//  Fabric.swift
//  NeedleWorksKit
//

import AppKit

/// A fabric to draw stitches on: its color, and how it's woven.
public struct Fabric: Equatable, @unchecked Sendable {
	/// How the fabric is woven, and from what yarn
	public enum Weave: String, CaseIterable, Sendable {
		/// A plain weave of one color
		case plain
		/// A plain weave of yarn spun from light and dark fibers
		case heather
		/// A plain weave with colored warp and white weft
		case chambray
		/// A 3/1 twill with colored warp and white weft
		case denim
	}

	public var weave: Weave

	/// The yarn's color; for chambray and denim, the warp's
	public var color: NSColor

	public init(weave: Weave = .plain, color: NSColor) {
		self.weave = weave
		self.color = color
	}

	/// The off-white weft of chambray and denim
	static let weftColor = NSColor(srgbRed: 0.90, green: 0.89, blue: 0.85, alpha: 1)

	/// The color the fabric looks from a distance, used when it's drawn
	/// without its texture
	public var flatColor: NSColor {
		switch weave {
		case .plain, .heather:
			return color
		case .chambray:
			return Self.mix(color, Self.weftColor, 0.5)
		case .denim:
			return Self.mix(color, Self.weftColor, 0.25)
		}
	}

	/// `a` with the fraction `t` of `b` mixed in, in sRGB
	static func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
		guard let a = a.usingColorSpace(.sRGB), let b = b.usingColorSpace(.sRGB) else {
			return a
		}
		return NSColor(srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
					   green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
					   blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t, alpha: 1)
	}
}
