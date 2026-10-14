//
//  PESThumbnailProvider.m
//  NeedleWorksThumbnail
//

#import "PESThumbnailProvider.h"
#import "PESDocumentParser.h"
#import "PESRenderer.h"

@implementation PESThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
					  completionHandler:(void (^)(QLThumbnailReply * _Nullable reply, NSError * _Nullable error))handler {
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

	/* Scale to fit the requested maximumSize while preserving aspect ratio
	 (the legacy plugin ignored maxSize entirely and always rendered full-size). */
	CGSize maximumSize = request.maximumSize;
	CGFloat scale = MIN(maximumSize.width / canvasSize.width, maximumSize.height / canvasSize.height);
	CGSize contextSize = CGSizeMake(canvasSize.width * scale, canvasSize.height * scale);

	QLThumbnailReply *reply = [QLThumbnailReply replyWithContextSize:contextSize
								   currentContextDrawingBlock:^BOOL{
		CGContextRef context = [NSGraphicsContext currentContext].CGContext;

		/* Flip so (0,0) is top-left, matching the app's DesignView isFlipped=YES. */
		CGContextTranslateCTM(context, 0, contextSize.height);
		CGContextScaleCTM(context, 1, -1);

		CGContextScaleCTM(context, scale, scale);
		CGContextTranslateCTM(context, -minPoint.x, -minPoint.y);

		NSRect rect = NSMakeRect(minPoint.x, minPoint.y, canvasSize.width, canvasSize.height);
		[PESRenderer drawStitchBlocks:stitchBlocks
						   fabricColor:[NSColor whiteColor]
							 lineWidth:2.0
					  showJumpStitches:NO
								inRect:rect];
		return YES;
	}];

	handler(reply, nil);
}

@end
