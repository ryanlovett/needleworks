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
	NSColor*		fabricColor;

	NSMutableArray* stitchBlocks;
	NSMutableArray* selection;
	
	NSSize			origPrintViewSizePortrait;
	NSSize			origPrintViewSizeLandscape;
	
	IBOutlet id		mainView;
	IBOutlet id		printView;
	IBOutlet id		splitView;
	IBOutlet id		legendPrintView;

	NSTextField*	emptyDesignLabel;
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

- (NSColor*)	fabricColor;
- (void)		setFabricColor:(NSColor*) c;

- (CGFloat)		lineWidth;
- (void)		setLineWidth:(CGFloat) w;

- (BOOL)		showJumpStitches;
- (void)		setShowJumpStitches:(BOOL) show;

- (NSPoint)		max;
- (NSPoint)		min;

- (NSSize)canvasSize;

@end
