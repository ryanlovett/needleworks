//
//  PESRenderer.h
//  NeedleWorksKit
//

#import <Cocoa/Cocoa.h>

@class StitchBlock;

@interface PESRenderer : NSObject

+ (void)drawStitchBlocks:(NSArray<StitchBlock *> *)stitchBlocks
              fabricColor:(NSColor *)fabricColor
                lineWidth:(CGFloat)lineWidth
         showJumpStitches:(BOOL)showJumpStitches
                   inRect:(NSRect)rect;

@end
