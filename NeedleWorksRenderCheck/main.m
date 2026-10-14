//
//  main.m
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

#import <Cocoa/Cocoa.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>

static int renderDirectly(NSString *inputPath, NSString *outputPath) {
	NSURL *url = [NSURL fileURLWithPath:inputPath];

	NSError *error = nil;
	PESDocumentParser *parser = [[PESDocumentParser alloc] initWithContentsOfURL:url error:&error];
	if (parser == nil) {
		fprintf(stderr, "parse failed: %s\n", [[error description] UTF8String]);
		return 1;
	}

	NSPoint minP = [parser minPoint];
	NSPoint maxP = [parser maxPoint];
	CGFloat w = maxP.x - minP.x;
	CGFloat h = maxP.y - minP.y;
	NSInteger pixelsWide = (NSInteger)ceil(w) + 4;
	NSInteger pixelsHigh = (NSInteger)ceil(h) + 4;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	CGColorSpaceRelease(colorSpace);

	/* Flip so (0,0) is top-left, matching the app's DesignView isFlipped=YES. */
	CGContextTranslateCTM(ctx, 0, pixelsHigh);
	CGContextScaleCTM(ctx, 1, -1);

	/* Translate so the design's min point maps to (2,2) with a small margin. */
	CGContextTranslateCTM(ctx, -minP.x + 2, -minP.y + 2);

	NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:YES];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsContext];

	NSRect rect = NSMakeRect(minP.x - 2, minP.y - 2, w + 4, h + 4);
	[PESRenderer drawStitchBlocks:[parser stitchBlocks]
					   fabricColor:[NSColor whiteColor]
						 lineWidth:2.0
				  showJumpStitches:NO
							inRect:rect];

	[NSGraphicsContext restoreGraphicsState];

	CGImageRef image = CGBitmapContextCreateImage(ctx);
	NSURL *outURL = [NSURL fileURLWithPath:outputPath];
	CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)outURL, CFSTR("public.png"), 1, NULL);
	CGImageDestinationAddImage(dest, image, NULL);
	CGImageDestinationFinalize(dest);
	CFRelease(dest);
	CGImageRelease(image);
	CGContextRelease(ctx);

	printf("wrote %s (%ldx%ld), stitchBlocks=%lu numStitches=%ld numColors=%ld designSize=%s\n",
		   [outputPath UTF8String], (long)pixelsWide, (long)pixelsHigh,
		   (unsigned long)[[parser stitchBlocks] count], (long)[parser numStitches],
		   (long)[parser numColors], [[parser designSize] UTF8String]);
	return 0;
}

static int renderViaQuickLook(NSString *inputPath, NSString *outputPath) {
	NSURL *url = [NSURL fileURLWithPath:inputPath];

	QLThumbnailGenerator *generator = [QLThumbnailGenerator sharedGenerator];
	QLThumbnailGenerationRequest *request =
		[[QLThumbnailGenerationRequest alloc] initWithFileAtURL:url
															size:CGSizeMake(256, 256)
														   scale:1.0
											 representationTypes:QLThumbnailGenerationRequestRepresentationTypeThumbnail];

	dispatch_semaphore_t sem = dispatch_semaphore_create(0);
	__block NSImage *resultImage = nil;
	__block NSError *resultError = nil;
	[generator generateBestRepresentationForRequest:request
								   completionHandler:^(QLThumbnailRepresentation * _Nullable thumbnail, NSError * _Nullable error) {
		resultImage = thumbnail.NSImage;
		resultError = error;
		dispatch_semaphore_signal(sem);
	}];

	if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC)) != 0) {
		fprintf(stderr, "timed out waiting for the system to generate a thumbnail\n");
		return 2;
	}
	if (resultError != nil) {
		fprintf(stderr, "system thumbnail generation failed (this is why Finder shows a blank icon): %s\n",
				[[resultError description] UTF8String]);
		return 1;
	}
	if (resultImage == nil) {
		fprintf(stderr, "no image and no error returned\n");
		return 1;
	}

	NSData *tiffData = [resultImage TIFFRepresentation];
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiffData];
	NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	[pngData writeToFile:outputPath atomically:YES];
	printf("system generated a thumbnail successfully: wrote %s (%.0fx%.0f) -- the NeedleWorksThumbnail extension is working\n",
		   [outputPath UTF8String], resultImage.size.width, resultImage.size.height);
	return 0;
}

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		if (argc == 4 && strcmp(argv[1], "--via-quicklook") == 0) {
			return renderViaQuickLook([NSString stringWithUTF8String:argv[2]],
									   [NSString stringWithUTF8String:argv[3]]);
		}
		if (argc == 3) {
			return renderDirectly([NSString stringWithUTF8String:argv[1]],
								   [NSString stringWithUTF8String:argv[2]]);
		}
		fprintf(stderr, "usage: %s <input.pes> <output.png>\n", argv[0]);
		fprintf(stderr, "       %s --via-quicklook <input.pes> <output.png>\n", argv[0]);
		return 1;
	}
}
