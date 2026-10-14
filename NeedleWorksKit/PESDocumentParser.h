//
//  PESDocumentParser.h
//  NeedleWorksKit
//

#import <Cocoa/Cocoa.h>

@class StitchBlock;

@interface PESDocumentParser : NSObject

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError;

@property (nonatomic, readonly, copy) NSArray<StitchBlock *> *stitchBlocks;
@property (nonatomic, readonly) NSPoint minPoint;
@property (nonatomic, readonly) NSPoint maxPoint;
@property (nonatomic, readonly) NSInteger numColors;
@property (nonatomic, readonly) NSInteger numColorChanges;
@property (nonatomic, readonly) NSInteger numStitches;
@property (nonatomic, readonly, copy) NSString *designSize;

@end
