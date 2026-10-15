//
//  PESThumbnailProvider.swift
//  NeedleWorksThumbnail
//

import AppKit
import NeedleWorksKit
import QuickLookThumbnailing

/// Finder's thumbnail of a design: its stitches as plain lines on white,
/// scaled to fit the size Finder asks for.
@objc(PESThumbnailProvider)
final class PESThumbnailProvider: QLThumbnailProvider {
	override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		let parser: PESDocumentParser
		do {
			parser = try PESDocumentParser(contentsOf: request.fileURL)
		} catch {
			handler(nil, error)
			return
		}
		let minPoint = parser.minPoint, maxPoint = parser.maxPoint

		/* Blank or perfectly straight designs have a zero dimension; keep the
		 * canvas at least 1 unit in each direction so scaling stays finite. */
		let canvasSize = CGSize(width: max(maxPoint.x - minPoint.x, 1), height: max(maxPoint.y - minPoint.y, 1))
		let stitchBlocks = parser.stitchBlocks

		/* Scale to fit the requested maximum size, keeping the proportions */
		let maximumSize = request.maximumSize
		let scale = min(maximumSize.width / canvasSize.width, maximumSize.height / canvasSize.height)
		let contextSize = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)

		let reply = QLThumbnailReply(contextSize: contextSize) { () -> Bool in
			guard let context = NSGraphicsContext.current?.cgContext else {
				return false
			}

			/* Flip so (0,0) is top-left, matching the app's DesignView */
			context.translateBy(x: 0, y: contextSize.height)
			context.scaleBy(x: 1, y: -1)

			context.scaleBy(x: scale, y: scale)
			context.translateBy(x: -minPoint.x, y: -minPoint.y)

			let rect = CGRect(origin: minPoint, size: canvasSize)
			PESRenderer.draw(stitchBlocks, fabricColor: .white, lineWidth: 2, showJumpStitches: false, in: rect)
			return true
		}
		handler(reply, nil)
	}
}
