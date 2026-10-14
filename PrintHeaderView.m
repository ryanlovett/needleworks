//
//  PrintHeaderView.m
//  Needle Works
//
//  Copyright 2026 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
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

#import "PrintHeaderView.h"
#import "PrintScaleAccessoryController.h"


@implementation PrintHeaderView

- (void)drawRect:(NSRect)rect {
	/* The check only makes sense when the design prints at actual size */
	if ([[NSUserDefaults standardUserDefaults] integerForKey:PESPrintScaleKey] != 0) {
		return;
	}

	/* Use the units of the Mac's measurement system: 50 mm for metric, 2
	 inches otherwise. Printer points are 1/72 inch. */
	CGFloat length;
	NSString *label;
	if ([[NSLocale currentLocale] usesMetricSystem]) {
		length = 50 * 72 / 25.4;
		label = NSLocalizedString(@"Should measure 50 mm", @"Printed under the metric scale check line");
	} else {
		length = 2 * 72;
		label = NSLocalizedString(@"Should measure 2 inches", @"Printed under the US scale check line");
	}

	CGFloat rightEdge = NSMaxX([self bounds]) - 17;
	CGFloat leftEdge = rightEdge - length;
	CGFloat lineY = 34;
	NSBezierPath *ruler = [NSBezierPath bezierPath];
	[ruler moveToPoint:NSMakePoint(leftEdge, lineY)];
	[ruler lineToPoint:NSMakePoint(rightEdge, lineY)];
	[ruler moveToPoint:NSMakePoint(leftEdge, lineY - 4)];
	[ruler lineToPoint:NSMakePoint(leftEdge, lineY + 4)];
	[ruler moveToPoint:NSMakePoint(rightEdge, lineY - 4)];
	[ruler lineToPoint:NSMakePoint(rightEdge, lineY + 4)];
	[ruler setLineWidth:0.75];
	[[NSColor blackColor] setStroke];
	[ruler stroke];

	NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeMini]],
								 NSForegroundColorAttributeName: [NSColor blackColor]};
	NSSize labelSize = [label sizeWithAttributes:attributes];
	[label drawAtPoint:NSMakePoint(rightEdge - labelSize.width, 14) withAttributes:attributes];
}

@end
