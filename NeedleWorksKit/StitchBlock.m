//
//  StitchBlock.m
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

#import "StitchBlock.h"

@implementation StitchBlock

/* This color map comes from the Embroidery Reader code */
- (void) setColorIndex:(NSUInteger) index {
	colorIndex = index;
	r = 0; g = 0; b = 0;
	
	switch (colorIndex) {
		case 1:
			r = 14.0f; g = 31.0f; b = 124.0f;
			break;
		case 2:
			r = 10.0f; g = 85.0f; b = 163.0f;
			break;
		case 3:
			r = 48.0f; g = 135.0f; b = 119.0f;
			break;
		case 4:
			r = 75.0f; g = 107.0f; b = 175.0f;
			break;
		case 5:
			r = 237.0f; g = 23.0f; b = 31.0f;
			break;
		case 6:
			r = 209.0f; g = 92.0f; b = 0.0f;
			break;
		case 7:
			r = 145.0f; g = 54.0f; b = 151.0f;
			break;
		case 8:
			r = 228.0f; g = 154.0f; b = 203.0f;
			break;
		case 9:
			r = 145.0f; g = 95.0f; b = 172.0f;
			break;
		case 10:
			r = 157.0f; g = 214.0f; b = 125.0f;
			break;
		case 11:
			r = 232.0f; g = 169.0f; b = 0.0f;
			break;
		case 12:
			r = 254.0f; g = 186.0f; b = 53.0f;
			break;
		case 13:
			r = 255.0f; g = 255.0f; b = 0.0f;
			break;
		case 14:
			r = 112.0f; g = 188.0f; b = 31.0f;
			break;
		case 15:
			r = 145.0f; g = 95.0f; b = 172.0f;
			break;
		case 16:
			r = 168.0f; g = 168.0f; b = 168.0f;
			break;
		case 17:
			r = 123.0f; g = 111.0f; b = 0.0f;
			break;
		case 18:
			r = 255.0f; g = 255.0f; b = 179.0f;
			break;
		case 19:
			r = 79.0f; g = 85.0f; b = 86.0f;
			break;
		case 20:
			r = 0.0f; g = 0.0f; b = 0.0f;
			break;
		case 21:
			r = 11.0f; g = 61.0f; b = 145.0f;
			break;
		case 22:
			r = 119.0f; g = 1.0f; b = 118.0f;
			break;
		case 23:
			r = 41.0f; g = 49.0f; b = 51.0f;
			break;
		case 24:
			r = 42.0f; g = 19.0f; b = 1.0f;
			break;
		case 25:
			r = 246.0f; g = 74.0f; b = 138.0f;
			break;
		case 26:
			r = 178.0f; g = 118.0f; b = 36.0f;
			break;
		case 27:
			r = 252.0f; g = 187.0f; b = 196.0f;
			break;
		case 28:
			r = 254.0f; g = 55.0f; b = 15.0f;
			break;
		case 29:
			r = 240.0f; g = 240.0f; b = 240.0f;
			break;
		case 30:
			r = 106.0f; g = 28.0f; b = 138.0f;
			break;
		case 31:
			r = 168.0f; g = 221.0f; b = 196.0f;
			break;
		case 32:
			r = 37.0f; g = 132.0f; b = 187.0f;
			break;
		case 33:
			r = 254.0f; g = 179.0f; b = 67.0f;
			break;
		case 34:
			r = 255.0f; g = 240.0f; b = 141.0f;
			break;
		case 35:
			r = 208.0f; g = 166.0f; b = 96.0f;
			break;
		case 36:
			r = 209.0f; g = 84.0f; b = 0.0f;
			break;
		case 37:
			r = 102.0f; g = 186.0f; b = 73.0f;
			break;
		case 38:
			r = 19.0f; g = 74.0f; b = 70.0f;
			break;
		case 39:
			r = 135.0f; g = 135.0f; b = 135.0f;
			break;
		case 40:
			r = 216.0f; g = 202.0f; b = 198.0f;
			break;
		case 41:
			r = 67.0f; g = 86.0f; b = 7.0f;
			break;
		case 42:
			r = 254.0f; g = 227.0f; b = 197.0f;
			break;
		case 43:
			r = 249.0f; g = 147.0f; b = 188.0f;
			break;
		case 44:
			r = 0.0f; g = 56.0f; b = 34.0f;
			break;
		case 45:
			r = 178.0f; g = 175.0f; b = 212.0f;
			break;
		case 46:
			r = 104.0f; g = 106.0f; b = 176.0f;
			break;
		case 47:
			r = 239.0f; g = 227.0f; b = 185.0f;
			break;
		case 48:
			r = 247.0f; g = 56.0f; b = 102.0f;
			break;
		case 49:
			r = 181.0f; g = 76.0f; b = 100.0f;
			break;
		case 50:
			r = 19.0f; g = 43.0f; b = 26.0f;
			break;
		case 51:
			r = 199.0f; g = 1.0f; b = 85.0f;
			break;
		case 52:
			r = 254.0f; g = 158.0f; b = 50.0f;
			break;
		case 53:
			r = 168.0f; g = 222.0f; b = 235.0f;
			break;
		case 54:
			r = 0.0f; g = 103.0f; b = 26.0f;
			break;
		case 55:
			r = 78.0f; g = 41.0f; b = 144.0f;
			break;
		case 56:
			r = 47.0f; g = 126.0f; b = 32.0f;
			break;
		case 57:
			r = 253.0f; g = 217.0f; b = 222.0f;
			break;
		case 58:
			r = 255.0f; g = 217.0f; b = 17.0f;
			break;
		case 59:
			r = 9.0f; g = 91.0f; b = 166.0f;
			break;
		case 60:
			r = 240.0f; g = 249.0f; b = 112.0f;
			break;
		case 61:
			r = 227.0f; g = 243.0f; b = 91.0f;
			break;
		case 62:
			r = 255.0f; g = 200.0f; b = 100.0f;
			break;
		case 63:
			r = 255.0f; g = 200.0f; b = 150.0f;
			break;
		case 64:
			r = 255.0f; g = 200.0f; b = 200.0f;
			break;
		default:
			r = 1.0f; g = 1.0f; b = 1.0f;
			break;
	}
	
	[self setColor:[NSColor colorWithCalibratedRed:r/255 green:g/255 blue:b/255 alpha: 1.0f]];
}

- (NSUInteger) colorIndex {
	return colorIndex;
}

- (void) drawWithSelection:(BOOL) selected Jumps:(BOOL) jumps Width:(CGFloat)lineWidth {
	NSBezierPath* path;
	
	path = (jumps) ? [self stitchesAndJumps] : [self stitches];
	
	/* Set the color we're about to stroke with */
	//[[NSColor colorWithCalibratedRed:r/255 green:g/255 blue:b/255 alpha: 1.0f] setStroke];
	[color setStroke];
	
	/* testing */
	[path setLineCapStyle:NSLineCapStyleRound];
	[path setLineJoinStyle:NSLineJoinStyleRound];
	
	/* Users can set the line width dynamically */
	[path setLineWidth:lineWidth];
	
	/* Draw the line */
	[path stroke];
	
	/* Draw a box around a stitch block for debugging purposes *
	 NSColor* black = [NSColor redColor];
	 [black setStroke];
	 [[NSBezierPath bezierPathWithRect:[path bounds]] stroke];
	 //*/
}

- (void) scale:(CGFloat)factor {
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform scaleBy:factor];
	[stitches transformUsingAffineTransform:transform];
	[stitchesAndJumps transformUsingAffineTransform:transform];
}

/*
 Accessor methods
 */ 
@synthesize color;
@synthesize stitches;
@synthesize stitchesAndJumps;
@synthesize numStitches;

@end
