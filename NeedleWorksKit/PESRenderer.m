//
//  PESRenderer.m
//  NeedleWorksKit
//

#import "PESRenderer.h"
#import "StitchBlock.h"

@implementation PESRenderer

+ (void)drawStitchBlocks:(NSArray<StitchBlock *> *)stitchBlocks
              fabricColor:(NSColor *)fabricColor
                lineWidth:(CGFloat)lineWidth
         showJumpStitches:(BOOL)showJumpStitches
                   inRect:(NSRect)rect {
	NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];

	/* Draw the background */
	[fabricColor set];
	NSRectFill(rect);

	/* Draw all of the stitches */
	for (StitchBlock *stitchblock in stitchBlocks) {
		[currentContext saveGraphicsState];
		[stitchblock drawWithSelection:FALSE Jumps:showJumpStitches Width:lineWidth];
		[currentContext restoreGraphicsState];
	}
}

@end
