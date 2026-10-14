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

/* The PEC thread palette, indexed from 1: Brother thread names, thread
 numbers (0 if none) and colors. The colors are those of the BuzzEdit color
 list, which agree with the palette libpes verified against a Brother Innovis
 955 (https://github.com/frno7/libpes). */
static const struct {
	const char *name;
	int number;
	unsigned char r, g, b;
} PECThreads[] = {
	{ "Prussian Blue",       7,  26,  10, 148 },
	{ "Blue",              405,  15, 117, 255 },
	{ "Teal Green",        534,   0, 147,  76 },
	{ "Corn Flower Blue",   70, 186, 189, 254 },
	{ "Red",               800, 236,   0,   0 },
	{ "Reddish Brown",     337, 228, 153,  90 },
	{ "Magenta",           620, 204,  72, 171 },
	{ "Light Lilac",       810, 253, 196, 250 },
	{ "Lilac",             612, 221, 132, 205 },
	{ "Mint Green",        502, 107, 221, 138 },
	{ "Deep Gold",         214, 228, 169,  69 },
	{ "Orange",            208, 255, 189,  69 },
	{ "Yellow",            205, 255, 230,   0 },
	{ "Lime Green",        513, 108, 217,   0 },
	{ "Brass",             328, 193, 169,  65 },
	{ "Silver",              5, 181, 173, 151 },
	{ "Russet Brown",      330, 186, 156,  95 },
	{ "Cream Brown",        10, 250, 245, 158 },
	{ "Pewter",            704, 128, 128, 128 },
	{ "Black",             900,   0,   0,   0 },
	{ "Ultramarine",       406,   0,  28, 223 },
	{ "Royal Purple",      869, 223,   0, 184 },
	{ "Dark Gray",         707,  98,  98,  98 },
	{ "Dark Brown",         58, 105,  38,  13 },
	{ "Deep Rose",          86, 255,   0,  96 },
	{ "Light Brown",       323, 191, 130,   0 },
	{ "Salmon Pink",        79, 243, 145, 120 },
	{ "Vermilion",          30, 255, 104,   5 },
	{ "White",               1, 240, 240, 240 },
	{ "Violet",            613, 200,  50, 205 },
	{ "Seacrest",          542, 176, 191, 155 },
	{ "Sky Blue",           19, 101, 191, 235 },
	{ "Pumpkin",           126, 255, 186,   4 },
	{ "Cream Yellow",      812, 255, 240, 108 },
	{ "Khaki",             348, 254, 202,  21 },
	{ "Clay Brown",        339, 243, 129,   1 },
	{ "Leaf Green",        509,  55, 169,  35 },
	{ "Peacock Blue",      415,  35,  70,  95 },
	{ "Gray",              817, 166, 166, 149 },
	{ "Warm Gray",         399, 206, 191, 166 },
	{ "Dark Olive",        517, 150, 170,   2 },
	{ "Linen",             307, 255, 227, 198 },
	{ "Pink",               85, 255, 153, 215 },
	{ "Deep Green",        808,   0, 112,   4 },
	{ "Lavender",          804, 237, 204, 251 },
	{ "Wisteria Violet",   607, 192, 137, 216 },
	{ "Beige",             843, 231, 217, 180 },
	{ "Carmine",           807, 233,  14, 134 },
	{ "Amber Red",         333, 207, 104,  41 },
	{ "Olive Green",       519,  64, 134,  21 },
	{ "Dark Fuschia",      107, 219,  23, 151 },
	{ "Tangerine",         209, 255, 167,   4 },
	{ "Light Blue",         17, 185, 255, 255 },
	{ "Emerald Green",     507,  34, 137,  39 },
	{ "Purple",            614, 182,  18, 205 },
	{ "Moss Green",        515,   0, 170,   0 },
	{ "Flesh Pink",        124, 254, 169, 220 },
	{ "Harvest Gold",      206, 254, 213,  16 },
	{ "Electric Blue",     420,   0, 151, 223 },
	{ "Lemon Yellow",      202, 255, 255, 132 },
	{ "Fresh Green",        27, 207, 231, 116 },
	{ "Applique Material",   0, 255, 200, 100 },
	{ "Applique Position",   0, 255, 200, 150 },
	{ "Applique",            0, 255, 200, 200 },
};

static const NSUInteger PECThreadCount = sizeof(PECThreads) / sizeof(PECThreads[0]);

- (void) setColorIndex:(NSUInteger) index {
	colorIndex = index;

	if (colorIndex >= 1 && colorIndex <= PECThreadCount) {
		[self setColor:[NSColor colorWithSRGBRed:PECThreads[colorIndex - 1].r / 255.0
										   green:PECThreads[colorIndex - 1].g / 255.0
											blue:PECThreads[colorIndex - 1].b / 255.0
										   alpha:1.0]];
	} else {
		[self setColor:[NSColor blackColor]];
	}
}

- (NSString *) threadName {
	if (colorIndex < 1 || colorIndex > PECThreadCount) {
		return nil;
	}

	NSString *name = [NSString stringWithUTF8String:PECThreads[colorIndex - 1].name];
	int number = PECThreads[colorIndex - 1].number;
	return (number > 0) ? [NSString stringWithFormat:@"%@ (%d)", name, number] : name;
}

- (NSUInteger) colorIndex {
	return colorIndex;
}

- (void) drawWithSelection:(BOOL) selected Jumps:(BOOL) jumps Width:(CGFloat)lineWidth {
	NSBezierPath* path;
	
	path = (jumps) ? [self stitchesAndJumps] : [self stitches];
	
	/* Set the color we're about to stroke with */
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
