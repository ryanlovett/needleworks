//
//  StitchBlock.h
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


@interface StitchBlock : NSObject {
	NSColor *color;
	
	// You cannot modify the type of the path element so we can't change
	// lineto to moveto or vice versa. We just create both to save time.
    NSBezierPath *stitches;
	NSBezierPath *stitchesAndJumps;
	
	NSUInteger colorIndex;
	NSUInteger numStitches;
}

// properties
@property (copy) NSColor *color;
@property (copy) NSBezierPath *stitches;
@property (copy) NSBezierPath *stitchesAndJumps;
@property (assign) NSUInteger colorIndex;
@property (assign) NSUInteger numStitches;

// The thread's name and Brother thread number, e.g. "Prussian Blue (7)",
// or nil if the color index isn't in the PEC palette.
@property (readonly) NSString *threadName;

- (void) drawWithSelection:(BOOL)selected Jumps:(BOOL)jumps Width:(CGFloat)lineWidth;
- (void) scale:(CGFloat)factor;

@end
