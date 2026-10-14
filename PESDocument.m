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
#import "AppDelegate.h"
#import "PrintScaleAccessoryController.h"
#import "StitchBlock.h"
#import "PESDocumentParser.h"

/* Points per design unit (0.1 mm) at 100% zoom. This is the design view's
 base scale; true life size depends on the screen (see actualSizeZoom). */
static const CGFloat PESPointsPerUnit = 100.0 / 254;

/* Zoom limits, and the factor each Zoom In or Zoom Out step changes by */
static const CGFloat PESMinimumZoom = 0.1;
static const CGFloat PESMaximumZoom = 16;
static const CGFloat PESZoomStep = M_SQRT2;

/* Document window toolbar items */
static NSToolbarItemIdentifier const PESZoomOutItem = @"ZoomOut";
static NSToolbarItemIdentifier const PESZoomInItem = @"ZoomIn";
static NSToolbarItemIdentifier const PESZoomToFitItem = @"ZoomToFit";
static NSToolbarItemIdentifier const PESActualSizeItem = @"ActualSize";
static NSToolbarItemIdentifier const PESDesignInformationItem = @"DesignInformation";

@interface PESDocument () <NSToolbarDelegate>
@end

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
	 in points at 100% zoom. Designs do not always originate from (0, 0);
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
	[[mainView window] setContentMinSize:NSMakeSize(480, 300)];

	/* Toolbar with zoom controls and the Design Information panel */
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"PESDocumentToolbar"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[[mainView window] setToolbar:toolbar];


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

/* Once the window is on screen (and has any tab bar it's going to get), we
 size it so that the entire design is visible without scrolling (see
 windowWillUseStandardFrame:defaultFrame:). If the screen is smaller than
 the design, the scroll view will help us out. */
- (void) showWindows {
	[super showWindows];

	if (!hasSizedWindow) {
		hasSizedWindow = YES;
		NSWindow *window = [mainView window];

		/* Open designs at their actual (life) size */
		if (numStitches > 0) {
			[[mainView enclosingScrollView] setMagnification:[self actualSizeZoom]];
		}

		NSRect screenFrame = [[window screen] visibleFrame];
		[window setFrame:[self windowWillUseStandardFrame:window defaultFrame:screenFrame] display:YES];
	}
}

/* The window's standard ("zoomed") frame fits the whole design at the
 current zoom, within the screen, keeping the window's top-left corner. */
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame {
	NSScrollView *scrollView = [mainView enclosingScrollView];
	CGFloat zoom = [scrollView magnification];

	/* Everything in the window other than the visible design area, such as
	 the title bar, toolbar, scrollers and borders, stays the same size */
	NSRect frame = [window frame];
	NSSize visibleSize = [[scrollView contentView] frame].size;
	NSSize designSize = [mainView frame].size;
	frame.size.width += designSize.width * zoom - visibleSize.width;
	frame.size.height += designSize.height * zoom - visibleSize.height;

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

/* The zoom at which the design appears at its real, physical size on the
 screen showing the window, so it can be compared with fabric or a hoop.
 Falls back to 100% if the display doesn't report its physical size. */
- (CGFloat) actualSizeZoom {
	NSScreen *screen = [[mainView window] screen] ?: [NSScreen mainScreen];
	CGDirectDisplayID displayID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
	CGSize physicalSize = CGDisplayScreenSize(displayID);

	if (physicalSize.width <= 0) {
		return 1;
	}

	CGFloat pointsPerMillimeter = NSWidth([screen frame]) / physicalSize.width;
	CGFloat zoom = (pointsPerMillimeter / 10) / PESPointsPerUnit;
	return MIN(MAX(zoom, PESMinimumZoom), PESMaximumZoom);
}

- (IBAction) zoomToActualSize:(id)sender {
	[self setZoom:[self actualSizeZoom]];
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

#pragma mark Toolbar

- (NSArray<NSToolbarItemIdentifier> *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return @[PESZoomOutItem, PESZoomInItem, PESZoomToFitItem,
			 NSToolbarFlexibleSpaceItemIdentifier, PESDesignInformationItem];
}

- (NSArray<NSToolbarItemIdentifier> *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return @[PESZoomOutItem, PESZoomInItem, PESZoomToFitItem, PESActualSizeItem,
			 PESDesignInformationItem, NSToolbarSpaceItemIdentifier,
			 NSToolbarFlexibleSpaceItemIdentifier];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)identifier willBeInsertedIntoToolbar:(BOOL)flag {
	NSString *label, *toolTip, *symbol;
	SEL action;

	if ([identifier isEqualToString:PESZoomOutItem]) {
		label = NSLocalizedString(@"Zoom Out", @"Toolbar item");
		toolTip = NSLocalizedString(@"Make the design smaller", @"Toolbar item tooltip");
		symbol = @"minus.magnifyingglass";
		action = @selector(zoomOut:);
	} else if ([identifier isEqualToString:PESZoomInItem]) {
		label = NSLocalizedString(@"Zoom In", @"Toolbar item");
		toolTip = NSLocalizedString(@"Make the design larger", @"Toolbar item tooltip");
		symbol = @"plus.magnifyingglass";
		action = @selector(zoomIn:);
	} else if ([identifier isEqualToString:PESZoomToFitItem]) {
		label = NSLocalizedString(@"Zoom to Fit", @"Toolbar item");
		toolTip = NSLocalizedString(@"Fit the design to the window", @"Toolbar item tooltip");
		symbol = @"arrow.up.left.and.down.right.magnifyingglass";
		action = @selector(zoomToFit:);
	} else if ([identifier isEqualToString:PESActualSizeItem]) {
		label = NSLocalizedString(@"Actual Size", @"Toolbar item");
		toolTip = NSLocalizedString(@"Show the design at its actual size", @"Toolbar item tooltip");
		symbol = @"1.magnifyingglass";
		action = @selector(zoomToActualSize:);
	} else if ([identifier isEqualToString:PESDesignInformationItem]) {
		label = NSLocalizedString(@"Design Info", @"Toolbar item");
		toolTip = NSLocalizedString(@"Show or hide the Design Information panel", @"Toolbar item tooltip");
		symbol = @"info.circle";
		action = @selector(toggleInspectorPanel:);
	} else {
		return nil;
	}

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	[item setLabel:label];
	[item setPaletteLabel:label];
	[item setToolTip:toolTip];
	[item setImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label]];
	[item setAction:action];
	[item setBordered:YES];
	return item;
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

/* Lay out the printed page for the print info's paper size, orientation and
 margins, and scale the design. This runs each time the print system
 paginates (see PrintLayoutSplitView), so the layout and the print panel's
 preview follow any changes made in the print panel. */
- (void)layoutPrintViewsForPrintInfo:(NSPrintInfo *)printInfo {
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
	
	CGFloat pageWidth  = paperSize.width - marginLR*2;
	CGFloat pageHeight = paperSize.height - marginTB*2;

	// Expand our split view to occupy the whole page
	[splitView setFrameSize:NSMakeSize(pageWidth, pageHeight)];
	
	/* The printed design view's frame is in printer points (1/72 inch) and
	 its bounds are in design units (0.1 mm), so the bounds size sets the
	 printed scale. Work it out from the view's current frame each time, since
	 the frame changes with the paper size and orientation. */
	NSSize printSize = [printView frame].size;
	CGFloat xdiff = max.x - min.x;
	CGFloat ydiff = max.y - min.y;

	/* Design units per printer point at actual size: 254 tenths of a
	 millimetre per inch, 72 points per inch */
	CGFloat unitsPerPoint = 254.0 / 72;

	// User wants the printed size scaled to fit, keeping its proportions
	NSInteger printScale = [[NSUserDefaults standardUserDefaults] integerForKey:PESPrintScaleKey];
	if (printScale == 1 && xdiff > 0 && ydiff > 0) {
		unitsPerPoint = MAX(xdiff / printSize.width, ydiff / printSize.height);
	}

	[printView setBounds:NSMakeRect(min.x, min.y, printSize.width * unitsPerPoint, printSize.height * unitsPerPoint)];
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
	NSPrintInfo* printInfo = [self printInfo];
	[printInfo setHorizontalPagination:NSPrintingPaginationModeFit];
	[printInfo setVerticalPagination:NSPrintingPaginationModeFit];
	[self layoutPrintViewsForPrintInfo:printInfo];

	NSPrintOperation* op = [NSPrintOperation printOperationWithView:splitView printInfo:printInfo];

	/* Let people choose the print scale in the print panel itself */
	NSPrintPanel *printPanel = [op printPanel];
	[printPanel addAccessoryController:[[PrintScaleAccessoryController alloc] init]];
	[printPanel setOptions:[printPanel options] | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsPreview];

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