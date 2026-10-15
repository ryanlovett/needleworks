//
//  PESDocument.h
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


#import <Cocoa/Cocoa.h>
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>

@class PrintScaleAccessoryController, FabricColorPopUpButton;

@interface PESDocument : NSDocument
{
	//int*			jumpStitches;
	//int				numJumpStitches;

	BOOL			showJumpStitches;
	BOOL			isPES;

	NSPoint			min, max;
	
	NSInteger		numColors;
	NSInteger		numColorChanges;
	NSInteger		numStitches;
	NSNumber*		fileSize;
	NSString*		fileName;
	NSString*		designSize;
	NSString*		docSize;
	NSString*		docName;
	
	CGFloat			lineWidth;

	/* The fabric color chosen for this window from the toolbar, if any */
	NSColor*		ownFabricColor;

	/* The style chosen for this window from View > Stitch Style, if any */
	PESStitchStyle	ownStitchStyle;
	BOOL			hasOwnStitchStyle;

	NSMutableArray* stitchBlocks;
	NSMutableArray* selection;
	
	
	IBOutlet id		mainView;
	IBOutlet id		printView;
	IBOutlet id		splitView;
	IBOutlet id		legendPrintView;

	NSTextField*	emptyDesignLabel;
	BOOL			hasSizedWindow;

	/* The print panel accessory of the current print operation, if any */
	__weak PrintScaleAccessoryController *printScaleAccessory;

	/* The toolbar's stitch style and fabric color pop-ups, if they're in the
	 toolbar */
	__weak NSPopUpButton *stitchStylePopUp;
	__weak FabricColorPopUpButton *fabricColorPopUp;

	/* The toolbar's line width slider, if it's in the toolbar */
	__weak NSSlider *lineWidthSlider;
}


@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSNumber *fileSize;
@property (nonatomic, copy) NSString *docName;
@property (nonatomic, copy) NSString *docSize;
@property (nonatomic, copy) NSString *designSize;
@property (nonatomic, assign) NSInteger numStitches;
@property (nonatomic, assign) NSInteger numColors;
@property (nonatomic, assign) NSInteger numColorChanges;
@property (assign) BOOL isPES;

/* drawing maintenance */
- (void)		addStitchBlock:(id) object;
- (void)		removeStitchBlock:(id) object;

/* Methods that require redrawing */
- (NSArray*)	stitchBlocks;
- (void)		setStitchBlocks:(NSMutableArray*) arr;

/* The window's own fabric color if one was chosen, otherwise the one in
 Settings */
- (NSColor*)	fabricColor;
- (void)		setFabricColor:(NSColor*) c;

/* The width of lines in the Plain style, in design units */
- (CGFloat)		lineWidth;
- (void)		setLineWidth:(CGFloat) w;
- (IBAction)	chooseLineWidth:(id)sender;

/* The width of printed lines */
- (CGFloat)		printLineWidth;

- (BOOL)		showJumpStitches;
- (void)		setShowJumpStitches:(BOOL) show;

/* The window's own stitch style if one was chosen, otherwise the one in Settings */
- (PESStitchStyle)	stitchStyle;

/* Whether the fabric is drawn with a woven texture, when View > Show Fabric
 Texture is on */
- (BOOL)		showsFabricTexture;
- (IBAction)	chooseStitchStyle:(id)sender;

- (NSPoint)		max;
- (NSPoint)		min;

- (NSSize)canvasSize;

/* Printing */
- (void)		layoutPrintViewsForPrintInfo:(NSPrintInfo *)printInfo;

/* Zooming */
- (IBAction)	zoomIn:(id)sender;
- (IBAction)	zoomOut:(id)sender;
- (IBAction)	zoomToActualSize:(id)sender;
- (IBAction)	zoomToFit:(id)sender;

@end
