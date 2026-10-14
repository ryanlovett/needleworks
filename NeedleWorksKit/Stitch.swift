//
//  Stitch.swift
//  NeedleWorksKit
//

import CoreGraphics

/// What the machine does when it moves the needle to a stitch's end point.
public enum StitchType: Equatable {
	/// Sews thread from the start point to the end point.
	case normal
	/// Moves the frame without sewing; the thread is left as a loose strand.
	case jump
	/// Cuts the thread, then moves without sewing.
	case trim
}

/// One needle movement, in PES units (tenths of a millimeter).
public struct Stitch: Equatable {
	public var start: CGPoint
	public var end: CGPoint
	public var type: StitchType

	public init(start: CGPoint, end: CGPoint, type: StitchType) {
		self.start = start
		self.end = end
		self.type = type
	}
}
