//
//  PrintScaleAccessoryController.m
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

#import "PrintScaleAccessoryController.h"

NSString * const PESPrintScaleKey = @"printScale";


@implementation PrintScaleAccessoryController

- (NSArray<NSString *> *)scaleTitles {
	return @[NSLocalizedString(@"Actual Size", @"Print scale: print the design at its real size"),
			 NSLocalizedString(@"Fit to Page", @"Print scale: scale the design to fit the page")];
}

- (void)loadView {
	NSTextField *label = [NSTextField labelWithString:NSLocalizedString(@"Scale:", @"Print panel label for the print scale")];
	NSPopUpButton *popUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[popUp addItemsWithTitles:[self scaleTitles]];
	[popUp bind:NSSelectedIndexBinding toObject:self withKeyPath:@"printScale" options:nil];

	NSStackView *stack = [NSStackView stackViewWithViews:@[label, popUp]];
	[stack setEdgeInsets:NSEdgeInsetsMake(8, 20, 8, 20)];
	[stack setFrameSize:[stack fittingSize]];
	[self setView:stack];
}

- (NSInteger)printScale {
	return [[NSUserDefaults standardUserDefaults] integerForKey:PESPrintScaleKey];
}

- (void)setPrintScale:(NSInteger)printScale {
	[[NSUserDefaults standardUserDefaults] setInteger:printScale forKey:PESPrintScaleKey];
}

#pragma mark NSPrintPanelAccessorizing

- (NSArray<NSDictionary<NSPrintPanelAccessorySummaryKey, NSString *> *> *)localizedSummaryItems {
	NSArray *titles = [self scaleTitles];
	NSInteger scale = MIN(MAX([self printScale], 0), (NSInteger)[titles count] - 1);
	return @[@{NSPrintPanelAccessorySummaryItemNameKey: NSLocalizedString(@"Scale", @"Print panel summary item name"),
			   NSPrintPanelAccessorySummaryItemDescriptionKey: titles[scale]}];
}

- (NSSet<NSString *> *)keyPathsForValuesAffectingPreview {
	return [NSSet setWithObject:@"printScale"];
}

@end
