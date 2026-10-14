//
//  PESDocument.m
//  Needle Works
//
//  Copyright 2008 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
//  
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//   
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.

#import "PESDocument.h"
#import "StitchBlock.h"
#import "PESDocumentParser.h"

@implementation PESDocument

/*
 Designated initializer for new documents: creates the people array
 */
- (id) init {
    self = [super init];
    if (self) {
		stitchBlocks = [[NSMutableArray alloc] init];
		selection = [[NSMutableArray alloc] init];
		docName = @"";
		docSize = @"";
		lineWidth = 2;
		fabricColor = [NSColor whiteColor];
		showJumpStitches = YES;

		colorLists = [[NSMutableArray alloc] init];
		origPrintViewSizePortrait = NSMakeSize(0, 0);
		origPrintViewSizeLandscape = NSMakeSize(0, 0);
		
		// Our application's shared color panel
		NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
		
		// The paths to our .clr files in Needle Works.app/Contents/Resources/
		NSArray *colorPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"clr" inDirectory:nil];
		NSEnumerator *colorPathIter;
		NSColorList *colorList;
		
		NSArray *colorNames;
		NSEnumerator *colorNameIter;
		NSString *path, *pathBasename;
		
		colorPathIter = [colorPaths objectEnumerator];
		while (path = [colorPathIter nextObject]) {
			pathBasename = [path lastPathComponent];
			colorList = [[NSColorList alloc] initWithName:[pathBasename stringByDeletingPathExtension] fromFile:path];
			if (colorList != nil) {
				[colorPanel attachColorList:colorList];
				colorNames = [colorList allKeys];
				colorNameIter = [colorNames objectEnumerator];
				/*while (colorStr = [colorNameIter nextObject]) {
					NSLog(colorStr);
				}*/
				[[self colorLists] addObject:colorList];
			} else {
				NSLog(@"Cannot find %@ color list", [path lastPathComponent]);
			}
			
		}
		
		//NSLog(@"colorLists count: %d", [[self colorLists] count]);
    }
    return self;
}

/*
 windowNibName returns the name of the document's nib file
 */
- (NSString *) windowNibName {
    return @"PESDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[mainView setDelegate:self];
	[printView setDelegate:self];
	[splitView setDelegate:self];
	[legendPrintView setDelegate:self];
		
	NSRect			r;
	r.origin.x = min.x;
	r.origin.y = min.y;
	r.size.width = max.x - min.x;
	r.size.height = max.y - min.y;
	
	/* We set the bounds origin since designs do not always originate
	 from (0, 0). Some are even (<0, <0). */
	[mainView setBoundsOrigin:min];
	
	/* Resize the clip view using the proper DPI */
	CGFloat actualScale = 100.0f / 254;
	NSView *clipView = [mainView superview];
	NSSize clipViewFrameSize = [clipView frame].size;
	NSSize actualSize = NSMakeSize((clipViewFrameSize.width / actualScale), (clipViewFrameSize.height / actualScale));
	[clipView setBoundsSize:actualSize];
	
	[mainView setFrame:r];

	/* Fill the area around a centered design with the fabric color, so the
	 design appears to sit on one continuous piece of fabric. */
	[[mainView enclosingScrollView] setBackgroundColor:fabricColor];
		
	/* Keep the window large enough to be easy to see, move and close, even
	 for blank designs or designs with very few stitches. */
	NSSize minContentSize = NSMakeSize(400, 300);
	[[mainView window] setContentMinSize:minContentSize];

	/* We set the maximum size of the window's content to be no larger than the content itself. (plus the scrollbar troughs?) We don't want the user dragging the window beyond so that it exposes the Land of Infinite Grey. */
	/* TODO: I might need to disable this when I implement zooming. */
	/* We also scale the max dimensions to the proper DPI since the view will be too. */
	r.size.width = MAX((max.x - min.x) * actualScale + 16, minContentSize.width);
	r.size.height = MAX((max.y - min.y) * actualScale + 16, minContentSize.height);
	[[mainView window] setContentMaxSize:r.size];
		
	/* We zoom the window so that the entire design is visible without 
	 scrolling. If the screen is smaller than the design, the scroll view
	 will help us out. */
	[[mainView window] performZoom:nil];
}

// Since we are a new document and haven't been saved we need to explicitly set our
// window title to something other than "Untitled n"
- (NSString *)displayName {
	return docName;
}

- (BOOL) readFromURL:(NSURL *)anUrl ofType:(NSString *)aType error:(NSError **) outError {
	self.docName = [[anUrl path] lastPathComponent];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[anUrl path] error:NULL];

	self.docSize = [[fileAttributes objectForKey:NSFileSize] stringValue];

	PESDocumentParser *parser = [[PESDocumentParser alloc] initWithContentsOfURL:anUrl error:outError];

	if (parser == nil) {
		return NO;
	}

	for (StitchBlock *block in [parser stitchBlocks]) {
		[self addStitchBlock:block];
	}

	min = [parser minPoint];
	max = [parser maxPoint];
	numColors = [parser numColors];
	numColorChanges = [parser numColorChanges];
	numStitches = [parser numStitches];
	self.designSize = [parser designSize];

	return YES;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
	
	NSPrintInfo* printInfo = [self printInfo];
	
    NSSize paperSize = [printInfo paperSize];
    NSRect printableRect = [printInfo imageablePageBounds];
	
    // calculate page margins
    CGFloat marginL = printableRect.origin.x;
    CGFloat marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
    CGFloat marginB = printableRect.origin.y;
    CGFloat marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);
	
    // Make sure margins are symetric and positive
    CGFloat marginLR = MAX(0, MAX(marginL, marginR));
    CGFloat marginTB = MAX(0, MAX(marginT, marginB));
    
    // Tell printInfo what the nice new margins are
    [printInfo setLeftMargin:   marginLR];
    [printInfo setRightMargin:  marginLR];
    [printInfo setTopMargin:    marginTB];
    [printInfo setBottomMargin: marginTB];
	
	[printInfo setHorizontalPagination:NSPrintingPaginationModeFit];
	[printInfo setVerticalPagination:NSPrintingPaginationModeFit];
	//[printInfo setHorizontallyCentered:NO];
	//[printInfo setVerticallyCentered:NO];
	
	CGFloat pageWidth  = paperSize.width - marginLR*2;
	CGFloat pageHeight = paperSize.height - marginTB*2;
	//NSLog(@"page size: %f x %f", pageWidth, pageHeight);

	// Expand our split view to occupy the whole page
	[splitView setFrameSize:NSMakeSize(pageWidth, pageHeight)];
	
	CGFloat xdiff = max.x - min.x;
	CGFloat ydiff = max.y - min.y;
	CGFloat factor;
	
	// Set our printed design view's bounds and save it
	NSRect npb;
	if ([printInfo orientation] == NSPaperOrientationPortrait) {
		if (origPrintViewSizePortrait.width == 0 && origPrintViewSizePortrait.height == 0) {
			origPrintViewSizePortrait = [printView bounds].size;
		}		
		npb = NSMakeRect(min.x, min.y,
						 origPrintViewSizePortrait.width, origPrintViewSizePortrait.height);
	} else {
		if (origPrintViewSizeLandscape.width == 0 && origPrintViewSizeLandscape.height == 0) {
			origPrintViewSizeLandscape = [printView bounds].size;
		}
		npb = NSMakeRect(min.x, min.y,
						 origPrintViewSizeLandscape.width, origPrintViewSizeLandscape.height);
	}
	
	// Fetch the print scale preference
	NSInteger printScale = [[NSUserDefaults standardUserDefaults] integerForKey:@"printScale"];

	// User wants the printed size scaled to fit
	if (printScale == 1) {
				
		// If the design's aspect ratio is wider than the design's portion of our page,
		// our bounds must be scaled to fit it by width, otherwise by height.
		if ((xdiff/ydiff) >= (pageWidth/pageHeight)) {
			//NSLog(@"Design is wide.");
			factor = xdiff/npb.size.width;
		} else {			
			//NSLog(@"Design is tall.");
			factor = ydiff/npb.size.height;
		}
	}
	// User wants the design printed at actual size
	else {
		factor = 1 + 254/100.0f; // why 3.54?		
	}
	
	npb.size.width *= factor;
	npb.size.height *= factor;

	//NSLog(@"design size: %f x %f", xdiff, ydiff);
	//NSLog(@"old frame: %f x %f (%f, %f)",
	//	  [printView frame].size.width, [printView frame].size.height,
	//	  [printView frame].origin.x, [printView frame].origin.y);
	//NSLog(@"old bounds: %f x %f (%f, %f)",
	//	  [printView bounds].size.width, [printView bounds].size.height,
	//	  [printView bounds].origin.x, [printView bounds].origin.y);

	[printView setBounds:npb];

	//NSLog(@"new bounds: %f x %f (%f, %f)",
	//	  [printView bounds].size.width, [printView bounds].size.height,
	//	  [printView bounds].origin.x, [printView bounds].origin.y);
	
	NSPrintOperation* op = [NSPrintOperation printOperationWithView:splitView printInfo:printInfo];
	
	return op;
}

- (void)addStitchBlock:(id) object {
	if (![stitchBlocks containsObject:object]) {
		[stitchBlocks addObject:object];
	}
}

- (void)removeStitchBlock:(id) object {
	[stitchBlocks removeObject:object];
}

- (NSArray*) stitchBlocks {
	return stitchBlocks;
}

- (void) setStitchBlocks:(NSMutableArray*) arr {
	stitchBlocks = arr;
}

- (NSColor*) fabricColor {
	return fabricColor;
}

- (void) setFabricColor:(NSColor*) c {
	fabricColor = c;
	[[mainView enclosingScrollView] setBackgroundColor:c];
	[mainView setNeedsDisplay:YES];
}

- (CGFloat) lineWidth {
	return lineWidth;
}

- (void) setLineWidth:(CGFloat) w {
	lineWidth = w;
	[mainView setNeedsDisplay:YES];
	//[[mainView window] performZoom:nil];
}

- (BOOL) showJumpStitches {
	return showJumpStitches;
}

- (void) setShowJumpStitches:(BOOL) show {
	showJumpStitches = !showJumpStitches;
	[mainView setNeedsDisplay:YES];
	//[[mainView window] performZoom:nil];
}

- (NSPoint) max {
	return max;
}

- (NSPoint) min {
	return min;
}

- (NSSize)canvasSize {
	return NSMakeSize(max.x - min.x, max.y - min.y);
}

- (NSMutableArray*)colorLists {
	return colorLists;
}

/*
 Accessor methods
*/ 
@synthesize fileName;
@synthesize docName;
@synthesize fileSize;
@synthesize docSize;
@synthesize designSize;
@synthesize numStitches;
@synthesize numColors;
@synthesize numColorChanges;
@synthesize isPES;

@end