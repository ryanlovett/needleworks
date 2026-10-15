//
//  PESPreviewProvider.swift
//  NeedleWorksPreview
//

import AppKit
import NeedleWorksKit
import QuickLookUI

/// The Quick Look preview of a design: its stitches as plain lines on white.
@objc(PESPreviewProvider)
final class PESPreviewProvider: QLPreviewProvider, QLPreviewingController {
	func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
		let parser = try PESDocumentParser(contentsOf: request.fileURL)
		let minPoint = parser.minPoint, maxPoint = parser.maxPoint

		/* Blank or perfectly straight designs have a zero dimension; keep the
		 * canvas at least 1 unit in each direction so scaling stays finite. */
		let canvasSize = CGSize(width: max(maxPoint.x - minPoint.x, 1), height: max(maxPoint.y - minPoint.y, 1))
		let stitchBlocks = parser.stitchBlocks

		return QLPreviewReply(contextSize: canvasSize, isBitmap: false) { context, _ in
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

			/* Flip so (0,0) is top-left, as the thumbnail extension does; the
			 * context itself isn't flipped. */
			context.translateBy(x: 0, y: canvasSize.height)
			context.scaleBy(x: 1, y: -1)

			/* Translate so the design's min point maps to the context's origin,
			 * matching the app's own DesignView, which sets its bounds origin to
			 * the document's min. */
			context.translateBy(x: -minPoint.x, y: -minPoint.y)

			let rect = CGRect(origin: minPoint, size: canvasSize)
			PESRenderer.draw(stitchBlocks, fabricColor: .white, lineWidth: 2, showJumpStitches: false, in: rect)

			NSGraphicsContext.restoreGraphicsState()
		}
	}
}
