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

/* Points per design unit (0.1 mm) at actual size */
static const CGFloat PESPointsPerUnit = 100.0 / 254;

/* Zoom limits, and the factor each Zoom In or Zoom Out step changes by */
static const CGFloat PESMinimumZoom = 0.1;
static const CGFloat PESMaximumZoom = 16;
static const CGFloat PESZoomStep = M_SQRT2;

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

		origPrintViewSizePortrait = NSMakeSize(0, 0);
		origPrintViewSizeLandscape = NSMakeSize(0, 0);
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
		
	/* The design view's bounds are in design units (0.1 mm) and its frame is
	 in points at actual size. Designs do not always originate from (0, 0);
	 some are even (<0, <0). Keep at least one unit in each direction so
	 blank or perfectly straight designs still have a valid size. */
	NSRect designRect = NSMakeRect(min.x, min.y, MAX(max.x - min.x, 1), MAX(max.y - min.y, 1));
	[mainView setFrame:NSMakeRect(0, 0, NSWidth(designRect) * PESPointsPerUnit, NSHeight(designRect) * PESPointsPerUnit)];
	[mainView setBounds:designRect];

	NSScrollView *scrollView = [mainView enclosingScrollView];

	/* Fill the area around a centered design with the fabric color, so the
	 design appears to sit on one continuous piece of fabric. */
	[scrollView setBackgroundColor:fabricColor];

	/* Users zoom with the View menu or by pinching on a trackpad; there is
	 nothing to zoom in a blank design */
	[scrollView setAllowsMagnification:(numStitches > 0)];
	[scrollView setMinMagnification:PESMinimumZoom];
	[scrollView setMaxMagnification:PESMaximumZoom];

	/* Keep the window large enough to be easy to see, move and close, even
	 for blank designs or designs with very few stitches. */
	[[mainView window] setContentMinSize:NSMakeSize(400, 300)];

	/* We zoom the window so that the entire design is visible without
	 scrolling (see windowWillUseStandardFrame:defaultFrame:). If the screen
	 is smaller than the design, the scroll view will help us out. */
	[[mainView window] performZoom:nil];

	/* A blank design has nothing to draw, so say so rather than showing an
	 empty window. */
	if (numStitches == 0) {
		emptyDesignLabel = [NSTextField labelWithString:NSLocalizedString(@"This design has no stitches.", @"Shown in the window of a design with no stitches")];
		[emptyDesignLabel setFont:[NSFont systemFontOfSize:[NSFont systemFontSize] + 2]];
		[emptyDesignLabel setTranslatesAutoresizingMaskIntoConstraints:NO];

		NSView *contentView = [[mainView window] contentView];
		[contentView addSubview:emptyDesignLabel];
		[NSLayoutConstraint activateConstraints:@[
			[[emptyDesignLabel centerXAnchor] constraintEqualToAnchor:[contentView centerXAnchor]],
			[[emptyDesignLabel centerYAnchor] constraintEqualToAnchor:[contentView centerYAnchor]]
		]];
		[self updateEmptyDesignLabelColor];
	}
}

/* The window's standard ("zoomed") frame fits the whole design at the
 current zoom, within the screen, keeping the window's top-left corner. */
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame {
	NSScrollView *scrollView = [mainView enclosingScrollView];
	CGFloat zoom = [scrollView magnification];

	/* Everything in the window other than the visible design area, such as
	 scrollers and borders, stays the same size */
	NSSize contentSize = [[window contentView] frame].size;
	NSSize visibleSize = [[scrollView contentView] frame].size;
	NSSize designSize = [mainView frame].size;
	contentSize.width += designSize.width * zoom - visibleSize.width;
	contentSize.height += designSize.height * zoom - visibleSize.height;

	NSRect frame = [window frameRectForContentRect:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	NSSize minSize = [window minSize];
	frame.size.width = MIN(MAX(NSWidth(frame), minSize.width), NSWidth(newFrame));
	frame.size.height = MIN(MAX(NSHeight(frame), minSize.height), NSHeight(newFrame));

	frame.origin.x = MIN(NSMinX([window frame]), NSMaxX(newFrame) - NSWidth(frame));
	frame.origin.y = MAX(NSMaxY([window frame]) - NSHeight(frame), NSMinY(newFrame));
	return frame;
}

/* Zoom by setting the scroll view's magnification, keeping the center of
 the visible area in place */
- (void) setZoom:(CGFloat)zoom {
	NSScrollView *scrollView = [mainView enclosingScrollView];
	NSRect visible = [[scrollView contentView] bounds];
	[scrollView setMagnification:zoom centeredAtPoint:NSMakePoint(NSMidX(visible), NSMidY(visible))];
}

- (IBAction) zoomIn:(id)sender {
	[self setZoom:[[mainView enclosingScrollView] magnification] * PESZoomStep];
}

- (IBAction) zoomOut:(id)sender {
	[self setZoom:[[mainView enclosingScrollView] magnification] / PESZoomStep];
}

- (IBAction) zoomToActualSize:(id)sender {
	[self setZoom:1];
}

- (IBAction) zoomToFit:(id)sender {
	[[mainView enclosingScrollView] magnifyToFitRect:[mainView frame]];
}

- (BOOL) validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
	SEL action = [item action];
	CGFloat zoom = [[mainView enclosingScrollView] magnification];

	/* There's nothing to zoom in a blank design */
	if (action == @selector(zoomIn:)) {
		return numStitches > 0 && zoom < PESMaximumZoom;
	} else if (action == @selector(zoomOut:)) {
		return numStitches > 0 && zoom > PESMinimumZoom;
	} else if (action == @selector(zoomToActualSize:) || action == @selector(zoomToFit:)) {
		return numStitches > 0;
	}
	return [super validateUserInterfaceItem:item];
}

/* Keep the empty design message readable on both light and dark fabrics */
- (void) updateEmptyDesignLabelColor {
	NSColor *rgb = [fabricColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
	CGFloat brightness = 1;
	if (rgb != nil) {
		brightness = 0.299 * [rgb redComponent] + 0.587 * [rgb greenComponent] + 0.114 * [rgb blueComponent];
	}
	[emptyDesignLabel setTextColor:[NSColor colorWithWhite:(brightness > 0.5 ? 0 : 1) alpha:0.55]];
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
	[self updateEmptyDesignLabelColor];
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