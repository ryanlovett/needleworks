//
//  main.swift
//  NeedleWorksRenderCheck
//
//  Two modes:
//
//  1. NeedleWorksRenderCheck <input.pes> <output.png>
//     Renders a .pes file through the shared NeedleWorksKit parser/renderer
//     directly into an offscreen bitmap. This exercises our own parsing and
//     drawing code, bypassing the installed QuickLook extensions entirely.
//
//  2. NeedleWorksRenderCheck --via-quicklook <input.pes> <output.png>
//     Asks the OS for a thumbnail via QLThumbnailGenerator -- the same
//     non-UI API Finder itself calls to render icon thumbnails. If this
//     succeeds, Finder's thumbnails for the file will too, because it's
//     the same call; if it fails, that failure is the actual reason Finder
//     shows a blank icon for the file. This is how to check whether the
//     NeedleWorksThumbnail app extension is actually being found and
//     invoked by the system, as opposed to just checking our own
//     rendering code in mode 1.
//

import AppKit
import NeedleWorksKit
import QuickLookThumbnailing

func printError(_ message: String) {
	FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

func writePNG(_ image: CGImage, to path: String) {
	let url = URL(fileURLWithPath: path) as CFURL
	guard let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
		printError("can't write \(path)")
		return
	}
	CGImageDestinationAddImage(destination, image, nil)
	CGImageDestinationFinalize(destination)
}

func renderDirectly(_ inputPath: String, _ outputPath: String) -> Int32 {
	let parser: PESDocumentParser
	do {
		parser = try PESDocumentParser(contentsOf: URL(fileURLWithPath: inputPath))
	} catch {
		printError("parse failed: \(error)")
		return 1
	}

	let minP = parser.minPoint, maxP = parser.maxPoint
	let w = maxP.x - minP.x, h = maxP.y - minP.y
	let pixelsWide = Int(w.rounded(.up)) + 4, pixelsHigh = Int(h.rounded(.up)) + 4

	guard let context = CGContext(data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0,
								  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
		printError("can't make a \(pixelsWide)x\(pixelsHigh) bitmap")
		return 1
	}

	/* Flip so (0,0) is top-left, matching the app's DesignView isFlipped=YES. */
	context.translateBy(x: 0, y: CGFloat(pixelsHigh))
	context.scaleBy(x: 1, y: -1)

	/* Translate so the design's min point maps to (2,2) with a small margin. */
	context.translateBy(x: -minP.x + 2, y: -minP.y + 2)

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
	let rect = CGRect(x: minP.x - 2, y: minP.y - 2, width: w + 4, height: h + 4)
	PESRenderer.draw(parser.stitchBlocks, fabricColor: .white, lineWidth: 2, showJumpStitches: false, in: rect)
	NSGraphicsContext.restoreGraphicsState()

	guard let image = context.makeImage() else {
		printError("can't make the image")
		return 1
	}
	writePNG(image, to: outputPath)

	print("wrote \(outputPath) (\(pixelsWide)x\(pixelsHigh)), stitchBlocks=\(parser.stitchBlocks.count) numStitches=\(parser.numStitches) numColors=\(parser.numColors) designSize=\(parser.designSize)")
	return 0
}

func renderViaQuickLook(_ inputPath: String, _ outputPath: String) async -> Int32 {
	let url = URL(fileURLWithPath: inputPath)

	/* Give up after 15 seconds */
	let result = await withTaskGroup(of: Result<CGImage, Error>?.self) { group in
		group.addTask {
			let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 256, height: 256),
													   scale: 1, representationTypes: .thumbnail)
			do {
				return .success(try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage)
			} catch {
				return .failure(error)
			}
		}
		group.addTask {
			try? await Task.sleep(nanoseconds: 15_000_000_000)
			return nil
		}
		let first = await group.next() ?? nil
		group.cancelAll()
		return first
	}

	switch result {
	case nil:
		printError("timed out waiting for the system to generate a thumbnail")
		return 2
	case .failure(let error):
		printError("system thumbnail generation failed (this is why Finder shows a blank icon): \(error)")
		return 1
	case .success(let image):
		writePNG(image, to: outputPath)
		print("system generated a thumbnail successfully: wrote \(outputPath) (\(image.width)x\(image.height)) -- the NeedleWorksThumbnail extension is working")
		return 0
	}
}

let arguments = CommandLine.arguments
if arguments.count == 4 && arguments[1] == "--via-quicklook" {
	exit(await renderViaQuickLook(arguments[2], arguments[3]))
}
if arguments.count == 3 {
	exit(renderDirectly(arguments[1], arguments[2]))
}
printError("usage: \(arguments[0]) <input.pes> <output.png>")
printError("       \(arguments[0]) --via-quicklook <input.pes> <output.png>")
exit(1)
