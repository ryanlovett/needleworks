//
//  SettingsWindowController.m
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

#import "SettingsWindowController.h"
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>

NSString * const PESStitchStyleKey = @"stitchStyle";
NSString * const PESFabricTextureKey = @"fabricTexture";

NSArray<NSString *> *PESStitchStyleTitles(void) {
	return @[NSLocalizedString(@"Plain", @"Stitch style: lines"),
			 NSLocalizedString(@"Shaded", @"Stitch style: shaded thread"),
			 NSLocalizedString(@"Realistic", @"Stitch style: realistic thread")];
}


@implementation SettingsWindowController

- (instancetype)init {
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSZeroRect
												   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
													 backing:NSBackingStoreBuffered
													   defer:YES];
	[window setTitle:NSLocalizedString(@"Settings", @"Settings window title")];
	self = [super initWithWindow:window];
	if (self) {
		[self buildContent];
		[window center];
	}
	return self;
}

- (void)buildContent {
	NSTextField *label = [NSTextField labelWithString:NSLocalizedString(@"Stitch style:", @"Settings label for the stitch style")];

	NSPopUpButton *popUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[popUp setAutoenablesItems:NO];
	NSArray *titles = PESStitchStyleTitles();
	for (NSUInteger style = 0; style < [titles count]; style++) {
		[popUp addItemWithTitle:titles[style]];
		[[popUp lastItem] setEnabled:[PESRenderer canDrawStitchStyle:(PESStitchStyle)style]];
	}
	[popUp bind:NSSelectedIndexBinding
	   toObject:[NSUserDefaultsController sharedUserDefaultsController]
	withKeyPath:[@"values." stringByAppendingString:PESStitchStyleKey]
		options:nil];

	NSTextField *note = [NSTextField wrappingLabelWithString:NSLocalizedString(@"Windows use this style unless you choose another for a window from View > Stitch Style.", @"Settings note under the stitch style")];
	[note setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[note setTextColor:[NSColor secondaryLabelColor]];
	[note setPreferredMaxLayoutWidth:260];
	[[[note widthAnchor] constraintEqualToConstant:260] setActive:YES];

	NSGridView *grid = [NSGridView gridViewWithViews:@[@[label, popUp],
													   @[[NSGridCell emptyContentView], note]]];
	[grid setRowSpacing:6];
	[[grid columnAtIndex:0] setXPlacement:NSGridCellPlacementTrailing];
	[[grid rowAtIndex:0] setYPlacement:NSGridCellPlacementCenter];
	[grid setTranslatesAutoresizingMaskIntoConstraints:NO];

	NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
	[content addSubview:grid];
	[NSLayoutConstraint activateConstraints:@[
		[[grid leadingAnchor] constraintEqualToAnchor:[content leadingAnchor] constant:20],
		[[grid trailingAnchor] constraintEqualToAnchor:[content trailingAnchor] constant:-20],
		[[grid topAnchor] constraintEqualToAnchor:[content topAnchor] constant:20],
		[[grid bottomAnchor] constraintEqualToAnchor:[content bottomAnchor] constant:-20],
	]];
	[[self window] setContentView:content];
	[[self window] setContentSize:[content fittingSize]];
}

@end
