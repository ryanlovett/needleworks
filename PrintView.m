//
//  PrintView.h
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

#import "PrintView.h"
#import "StitchBlock.h"
#import "PESDocument.h"

@implementation PrintView

@synthesize delegate;

- (void) drawRect:(NSRect) rect {
	PESDocument* doc = [self delegate];
	
	NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
	
	// Get our list of stitch blocks
	NSArray*		drawList = [doc stitchBlocks];
	NSEnumerator*	iter;
	StitchBlock*	stitchblock;
	
	//NSLog(@"PrintView::drawRect: rect: %f x %f @ (%f, %f)",
	//	  rect.size.width, rect.size.height, rect.origin.x, rect.origin.y);
	//NSLog(@"PrintView::drawRect: frame: %f x %f @ (%f, %f)",
	//	  [self frame].size.width, [self frame].size.height,
	//	  [self frame].origin.x, [self frame].origin.y);
	//NSLog(@"PrintView::drawRect: bounds: %f x %f @ (%f, %f)",
	//	  [self bounds].size.width, [self bounds].size.height,
	//	  [self bounds].origin.x, [self bounds].origin.y);
	
	// Draw all of the stitches
	iter = [drawList objectEnumerator];
	while(stitchblock = [iter nextObject]) {
		[currentContext saveGraphicsState];
		[stitchblock drawWithSelection:FALSE Jumps:[doc showJumpStitches] Width:[doc lineWidth]];
		[currentContext restoreGraphicsState];
	}	
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
