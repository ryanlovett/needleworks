//
//  PESPreviewProvider.m
//  NeedleWorksPreview
//

#import "PESPreviewProvider.h"
#import "PESDocumentParser.h"
#import "PESRenderer.h"

@implementation PESPreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
					completionHandler:(void (^)(QLPreviewReply * _Nullable reply, NSError * _Nullable error))handler {
	NSError *parseError = nil;
	PESDocumentParser *parser = [[PESDocumentParser alloc] initWithContentsOfURL:request.fileURL error:&parseError];
	if (parser == nil) {
		handler(nil, parseError);
		return;
	}

	NSPoint minPoint = [parser minPoint];
	NSPoint maxPoint = [parser maxPoint];
	/* Blank or perfectly straight designs have a zero dimension; keep the
	 canvas at least 1 unit in each direction so scaling stays finite. */
	CGSize canvasSize = CGSizeMake(MAX(maxPoint.x - minPoint.x, 1), MAX(maxPoint.y - minPoint.y, 1));
	NSArray<StitchBlock *> *stitchBlocks = [parser stitchBlocks];

	QLPreviewReply *reply = [[QLPreviewReply alloc] initWithContextSize:canvasSize
																isBitmap:NO
															drawingBlock:^BOOL(CGContextRef _Nonnull context, QLPreviewReply * _Nonnull reply, NSError * _Nullable __autoreleasing * _Nullable error) {
		NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:nsContext];

		/* Flip so (0,0) is top-left, as the thumbnail extension does; the
		 context itself isn't flipped. */
		CGContextTranslateCTM(context, 0, canvasSize.height);
		CGContextScaleCTM(context, 1, -1);

		/* Translate so the design's min point maps to the context's origin, matching
		 the app's own DesignView, which sets its bounds origin to the document's min. */
		CGContextTranslateCTM(context, -minPoint.x, -minPoint.y);

		NSRect rect = NSMakeRect(minPoint.x, minPoint.y, canvasSize.width, canvasSize.height);
		[PESRenderer drawStitchBlocks:stitchBlocks
						   fabricColor:[NSColor whiteColor]
							 lineWidth:2.0
					  showJumpStitches:NO
								inRect:rect];

		[NSGraphicsContext restoreGraphicsState];
		return YES;
	}];

	handler(reply, nil);
}

@end
