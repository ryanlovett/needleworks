//
//  LegendPrintView.h
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

#import "LegendPrintView.h"
#import "StitchBlock.h"
#import "PESDocument.h"

@implementation LegendPrintView

@synthesize delegate;

- (void) drawRect:(NSRect) rect {
	PESDocument* doc = [self delegate];
	
	
	// Get our list of stitch blocks
	NSArray*		drawList = [doc stitchBlocks];
	NSEnumerator*	iter;
	StitchBlock*	stitchblock;
	
	//NSLog(@"LegendPrintView::drawRect: rect: %f x %f @ (%f, %f)",
	//	  rect.size.width, rect.size.height, rect.origin.x, rect.origin.y);
	
	
	NSString* colorKey;
	 
	CGFloat textHeight = 6;
	 
	// Determine where to start to draw the legend
	CGFloat x = textHeight;
	CGFloat y = 0;
	 
	CGFloat boxWidth = textHeight * 2;
	 
	NSPoint  p;
	NSColor *threadColor;
	NSColor *black = [NSColor blackColor];
	NSRect   box;
	 
	// Set our font and its attributes
	NSString *str;
	NSFont   *fnt = [NSFont systemFontOfSize:textHeight];
	NSMutableDictionary* attribs = [[NSMutableDictionary alloc] init];		
	[attribs setObject:black forKey:NSForegroundColorAttributeName];
	[attribs setObject:fnt forKey:NSFontAttributeName];
	 
	iter = [drawList objectEnumerator];
	while(stitchblock = [iter nextObject]) {
		// Fetch our stitch color, with a generic label for colors that
		// aren't in the PEC palette
		threadColor = [stitchblock color];
		colorKey = [stitchblock threadName];
		if (colorKey == nil) {
			colorKey = [NSString stringWithFormat:NSLocalizedString(@"Color %lu", @"Legend label for a thread color with no name"), (unsigned long)[stitchblock colorIndex]];
		}

		// Set where our legend entry starts
		p = NSMakePoint(x, y);

		// Draw our color block
		box = NSMakeRect(p.x, p.y + (textHeight/2 - 1), boxWidth, textHeight);
		[[NSColor blackColor] setStroke];
		[NSBezierPath strokeRect:box];
		[threadColor setFill];
		[NSBezierPath fillRect:box];
	
		// Set the color label
		str = colorKey;
		// Draw the label
		[str drawAtPoint:NSMakePoint(p.x + boxWidth + boxWidth/4, p.y) withAttributes:attribs];
	
		// Move to the next line
		y += textHeight * 1.5;
	}
	
	/*
	NSColor* blue = [NSColor blueColor];
	[blue setStroke];
	NSBezierPath* outline = [NSBezierPath bezierPathWithRect:[self frame]];
	[outline setLineWidth:3];
	[outline stroke];
	 */
}

/* http://developer.apple.com/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/chapter_8_section_7.html */
- (void) setFrameSize:(NSSize)newSize {
	
    [super setFrameSize:newSize];
	
    if ([self inLiveResize]) {
		// A change in size has required the view to be invalidated.
        NSRect rects[4];
        NSInteger count;
		
        [self getRectsExposedDuringLiveResize:rects count:&count];
		
        while (count-- > 0) {
            [self setNeedsDisplayInRect:rects[count]];
        }
    } else {
        [self setNeedsDisplay:YES];
    }
}

/* We want to draw with (0, 0) at the top left */
- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return YES;
}

@end
