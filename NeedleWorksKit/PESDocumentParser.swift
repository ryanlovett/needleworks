//
//  PESDocumentParser.swift
//  NeedleWorksKit
//

import Foundation
import CoreServices

/// Reads the stitches and thread colors of a PES embroidery file from its
/// embedded PEC section.
@objc(PESDocumentParser)
public final class PESDocumentParser: NSObject {
	@objc public let stitchBlocks: [StitchBlock]
	@objc public let minPoint: CGPoint
	@objc public let maxPoint: CGPoint
	@objc public let numColors: Int
	@objc public let numColorChanges: Int
	@objc public let numStitches: Int
	@objc public let designSize: String

	@objc(initWithContentsOfURL:error:)
	public convenience init(contentsOf url: URL) throws {
		try self.init(data: Data(contentsOf: url))
	}

	public init(data: Data) throws {
		let bytes = [UInt8](data)

		guard bytes.count >= 12, bytes.starts(with: Array("#PES".utf8)) else {
			throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr)
		}

		/* The value at 8 is the offset of the PEC section */
		let pecStart = Int(Int32(bitPattern: UInt32(bytes[8]) | UInt32(bytes[9]) << 8 | UInt32(bytes[10]) << 16 | UInt32(bytes[11]) << 24))

		/* The PEC header (including the color list) runs up to the stitches at
		 * pecStart + 532, so make sure the file is at least that long. */
		guard pecStart >= 0, pecStart + 532 <= bytes.count else {
			throw CocoaError(.fileReadCorruptFile)
		}

		/* The 24-bit value at pecStart + 514 is the offset of the thumbnail
		 * graphics, which immediately follow the stitches. Use it to bound the
		 * stitch data when it is plausible; otherwise fall back to the file
		 * length and rely on the end marker. */
		let stitchStart = pecStart + 532
		let graphicsOffset = Int(bytes[pecStart + 514]) | Int(bytes[pecStart + 515]) << 8 | Int(bytes[pecStart + 516]) << 16
		var stitchEnd = pecStart + 513 + graphicsOffset
		if stitchEnd <= stitchStart || stitchEnd > bytes.count {
			stitchEnd = bytes.count
		}

		/* The number of colors is stored at pecStart + 48 as the number minus
		 * one, and 0xFF means there are no colors. The PEC palette index of
		 * each color follows. */
		let storedColors = bytes[pecStart + 48]
		let numColors = storedColors == 0xFF ? 0 : Int(storedColors) + 1
		let colors = bytes[(pecStart + 49)..<(pecStart + 49 + numColors)].map { Int($0) }

		var blocks: [StitchBlock] = []
		var blockStitches: [Stitch] = []
		var colorNum = -1
		var numColorChanges = 0
		var numStitches = 0
		var prev = CGPoint.zero, minPoint = CGPoint.zero, maxPoint = CGPoint.zero

		/* Save a finished block of stitches with the next thread color.
		 * Malformed files can have more color changes than colors, so the
		 * last color is reused. */
		func addBlock() {
			var colorIndex = 0
			if numColors > 0 {
				colorNum = min(colorNum + 1, numColors - 1)
				colorIndex = colors[colorNum]
			}
			blocks.append(StitchBlock(stitches: blockStitches, colorIndex: colorIndex))
			blockStitches = []
		}

		/* Stop at the end marker (0xFF), or if the stitch data runs out */
		var reader = StitchReader(bytes: bytes, position: stitchStart, end: stitchEnd)
		while let command = reader.peek(), command != 0xFF {
			if command == 0xFE {
				/* A color change (0xFE plus two more bytes) starts a new block */
				numColorChanges += 1
				addBlock()
				reader.position += 3
				continue
			}

			guard let dx = reader.readCoordinate(), let dy = reader.readCoordinate() else {
				/* The stitch data was cut off mid-stitch */
				break
			}

			let point = CGPoint(x: prev.x + CGFloat(dx.value), y: prev.y + CGFloat(dy.value))
			let type = dx.type == .trim || dy.type == .trim ? .trim : dx.type == .jump || dy.type == .jump ? .jump : StitchType.normal
			blockStitches.append(Stitch(start: prev, end: point, type: type))
			numStitches += 1

			prev = point
			minPoint = CGPoint(x: min(minPoint.x, point.x), y: min(minPoint.y, point.y))
			maxPoint = CGPoint(x: max(maxPoint.x, point.x), y: max(maxPoint.y, point.y))
		}

		/* Save the last block, unless the design has no stitches at all */
		if !blockStitches.isEmpty || !blocks.isEmpty {
			addBlock()
		}

		self.stitchBlocks = blocks
		self.minPoint = minPoint
		self.maxPoint = maxPoint
		self.numColors = numColors
		self.numColorChanges = numColorChanges
		self.numStitches = numStitches

		/* Show the physical size in the user's preferred units first, with the
		 * other units in parentheses */
		let w = maxPoint.x - minPoint.x
		let h = maxPoint.y - minPoint.y
		let inches = String(format: "%.2f\" x %.2f\"", w / 254, h / 254)
		let millimeters = String(format: "%.0f mm x %.0f mm", w / 10, h / 10)
		if (Locale.current as NSLocale).usesMetricSystem {
			self.designSize = "\(millimeters) (\(inches))"
		} else {
			self.designSize = "\(inches) (\(millimeters))"
		}
	}
}

/// Reads PEC stitch coordinates from the stitch data.
private struct StitchReader {
	let bytes: [UInt8]
	var position: Int
	let end: Int

	func peek() -> UInt8? {
		position < end ? bytes[position] : nil
	}

	private mutating func next() -> UInt8? {
		defer { position += 1 }
		return peek()
	}

	/// Reads one coordinate delta. A coordinate is either one byte (7-bit
	/// signed) or, when the high bit is set, two bytes holding a 12-bit signed
	/// value whose flag bits mark a trim (0x20) or jump (0x10). Returns nil if
	/// the stitch data ends first.
	mutating func readCoordinate() -> (value: Int, type: StitchType)? {
		guard let first = next() else {
			return nil
		}
		guard first & 0x80 != 0 else {
			let value = Int(first)
			return (value > 63 ? value - 128 : value, .normal)
		}

		guard let second = next() else {
			return nil
		}
		let type: StitchType = first & 0x20 != 0 ? .trim : first & 0x10 != 0 ? .jump : .normal
		var value = Int(first & 0x0F) << 8 | Int(second)
		if value & 0x800 != 0 {
			value -= 0x1000
		}
		return (value, type)
	}
}
