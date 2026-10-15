//
//  FabricColorPopUpButton.m
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


#import "FabricColorPopUpButton.h"

/* The tag of the item for a color that isn't one of the fabrics, and of
 Other… */
static const NSInteger FabricColorCustomTag = -1;
static const NSInteger FabricColorOtherTag = -2;

/* The pop-up the color panel is sending its changes to, if any */
static void *ColorPanelPopUp;

/* Common fabrics, in sRGB */
static NSArray<NSArray *> *FabricColors(void) {
	static NSArray *colors;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSColor *(^rgb)(CGFloat, CGFloat, CGFloat) = ^(CGFloat r, CGFloat g, CGFloat b) {
			return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1];
		};
		colors = @[@[NSLocalizedString(@"White", @"Fabric color"), rgb(1, 1, 1)],
				   @[NSLocalizedString(@"Natural", @"Fabric color: unbleached cotton or linen"), rgb(0.93, 0.89, 0.80)],
				   @[NSLocalizedString(@"Khaki", @"Fabric color"), rgb(0.76, 0.69, 0.53)],
				   @[NSLocalizedString(@"Heather Gray", @"Fabric color"), rgb(0.62, 0.62, 0.62)],
				   @[NSLocalizedString(@"Red", @"Fabric color"), rgb(0.70, 0.10, 0.12)],
				   @[NSLocalizedString(@"Forest Green", @"Fabric color"), rgb(0.13, 0.30, 0.20)],
				   @[NSLocalizedString(@"Denim", @"Fabric color"), rgb(0.27, 0.36, 0.50)],
				   @[NSLocalizedString(@"Navy", @"Fabric color"), rgb(0.13, 0.17, 0.30)],
				   @[NSLocalizedString(@"Black", @"Fabric color"), rgb(0.08, 0.08, 0.08)]];
	});
	return colors;
}

/* Whether two colors look the same */
static BOOL SameColor(NSColor *a, NSColor *b) {
	NSColor *ca = [a colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
	NSColor *cb = [b colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
	if (ca == nil || cb == nil) {
		return NO;
	}
	return fabs([ca redComponent] - [cb redComponent]) < 0.002 &&
		fabs([ca greenComponent] - [cb greenComponent]) < 0.002 &&
		fabs([ca blueComponent] - [cb blueComponent]) < 0.002;
}

static NSImage *Swatch(NSColor *color) {
	return [NSImage imageWithSize:NSMakeSize(16, 12) flipped:NO drawingHandler:^BOOL(NSRect rect) {
		NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:2.5 yRadius:2.5];
		[color setFill];
		[path fill];
		[[NSColor tertiaryLabelColor] setStroke];
		[path stroke];
		return YES;
	}];
}

@implementation FabricColorPopUpButton {
	NSColor *color;
}

- (instancetype)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag {
	self = [super initWithFrame:frameRect pullsDown:NO];
	if (self) {
		color = [NSColor whiteColor];
		[self buildMenu];
	}
	return self;
}

/* The color panel doesn't keep its target, so stop it sending to a pop-up
 that has gone */
- (void)dealloc {
	if (ColorPanelPopUp == (__bridge void *)self) {
		ColorPanelPopUp = NULL;
		[[NSColorPanel sharedColorPanel] setTarget:nil];
		[[NSColorPanel sharedColorPanel] setAction:NULL];
	}
}

- (NSColor *)color {
	return color;
}

- (void)setColor:(NSColor *)newColor {
	if ([newColor isEqual:color]) {
		return;
	}
	color = [newColor copy] ?: [NSColor whiteColor];
	[self buildMenu];
}

/* The fabrics, the color shown if it's none of them, and Other…. Each item
 sends its own action to the pop-up, which sends the pop-up's action once the
 color has changed. */
- (void)buildMenu {
	[self removeAllItems];
	NSMenu *menu = [self menu];
	NSMenuItem *selected = nil;

	for (NSArray *fabric in FabricColors()) {
		NSMenuItem *item = [menu addItemWithTitle:fabric[0] action:@selector(chooseItem:) keyEquivalent:@""];
		[item setTarget:self];
		[item setImage:Swatch(fabric[1])];
		[item setRepresentedObject:fabric[1]];
		if (selected == nil && SameColor(fabric[1], color)) {
			selected = item;
		}
	}
	if (selected == nil) {
		selected = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Custom", @"Fabric color chosen from the color panel") action:@selector(chooseItem:) keyEquivalent:@""];
		[selected setTarget:self];
		[selected setImage:Swatch(color)];
		[selected setRepresentedObject:color];
		[selected setTag:FabricColorCustomTag];
		[menu insertItem:selected atIndex:0];
		[menu insertItem:[NSMenuItem separatorItem] atIndex:1];
	}

	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *other = [menu addItemWithTitle:NSLocalizedString(@"Other…", @"Fabric color item that opens the color panel") action:@selector(chooseItem:) keyEquivalent:@""];
	[other setTarget:self];
	[other setTag:FabricColorOtherTag];

	[self selectItem:selected];
}

- (void)chooseItem:(NSMenuItem *)item {
	if ([item tag] == FabricColorOtherTag) {
		/* Show the color shown before Other… was chosen */
		[self buildMenu];
		NSColorPanel *panel = [NSColorPanel sharedColorPanel];
		[panel setShowsAlpha:NO];
		[panel setColor:color];
		[panel setTarget:self];
		ColorPanelPopUp = (__bridge void *)self;
		[panel setAction:@selector(colorPanelDidChange:)];
		[panel setContinuous:YES];
		[panel orderFront:self];
		return;
	}
	[self useColor:[item representedObject]];
}

- (void)colorPanelDidChange:(NSColorPanel *)panel {
	[self useColor:[[panel color] colorWithAlphaComponent:1]];
}

- (void)useColor:(NSColor *)newColor {
	if (newColor == nil || [newColor isEqual:color]) {
		return;
	}
	[self setColor:newColor];
	[self sendAction:[self action] to:[self target]];
}

@end
