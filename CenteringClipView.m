//
//  CenteringClipView.m
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

#import "CenteringClipView.h"
#import "DesignView.h"
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>


@implementation CenteringClipView

- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {
	NSRect constrained = [super constrainBoundsRect:proposedBounds];
	NSRect documentFrame = [[self documentView] frame];

	/* Along each axis where the document fits, center it in the visible area */
	if (NSWidth(proposedBounds) > NSWidth(documentFrame)) {
		constrained.origin.x = NSMidX(documentFrame) - NSWidth(proposedBounds) / 2;
	}
	if (NSHeight(proposedBounds) > NSHeight(documentFrame)) {
		constrained.origin.y = NSMidY(documentFrame) - NSHeight(proposedBounds) / 2;
	}

	return constrained;
}

/* Around the design, show the same woven fabric as under it, lined up with
 the design so the two join without a seam */
- (void)drawRect:(NSRect)dirtyRect {
	DesignView *designView = (DesignView *)[self documentView];
	PESDocument *doc = [designView isKindOfClass:[DesignView class]] ? [designView delegate] : nil;
	if (![doc showsFabricTexture]) {
		[super drawRect:dirtyRect];
		return;
	}

	/* Draw in the design's coordinates */
	NSPoint origin = [self convertPoint:NSZeroPoint fromView:designView];
	NSPoint unitX = [self convertPoint:NSMakePoint(1, 0) fromView:designView];
	NSPoint unitY = [self convertPoint:NSMakePoint(0, 1) fromView:designView];
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform setTransformStruct:(NSAffineTransformStruct){
		unitX.x - origin.x, unitX.y - origin.y, unitY.x - origin.x, unitY.y - origin.y, origin.x, origin.y}];

	[NSGraphicsContext saveGraphicsState];
	[transform concat];
	[PESRenderer drawFabricColor:[doc fabricColor] texture:YES inRect:[self convertRect:dirtyRect toView:designView]];
	[NSGraphicsContext restoreGraphicsState];
}

@end
