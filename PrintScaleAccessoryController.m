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


@implementation PrintScaleAccessoryController {
	NSTextField *_warningLabel;
	NSTextField *_lineWidthLabel;
}

- (NSString *)lineWidthText {
	return [NSString localizedStringWithFormat:NSLocalizedString(@"%.1f mm", @"Line width in millimetres"), [self lineWidth] / 10.0];
}

- (NSArray<NSString *> *)scaleTitles {
	return @[NSLocalizedString(@"Actual Size", @"Print scale: print the design at its real size"),
			 NSLocalizedString(@"Fit to Page", @"Print scale: scale the design to fit the page")];
}

- (void)loadView {
	NSTextField *label = [NSTextField labelWithString:NSLocalizedString(@"Scale:", @"Print panel label for the print scale")];
	NSPopUpButton *popUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	[popUp addItemsWithTitles:[self scaleTitles]];
	[popUp bind:NSSelectedIndexBinding toObject:self withKeyPath:@"printScale" options:nil];

	NSStackView *scaleRow = [NSStackView stackViewWithViews:@[label, popUp]];

	NSTextField *lineWidthTitle = [NSTextField labelWithString:NSLocalizedString(@"Line width:", @"Print panel label for the width of printed lines")];
	NSSlider *slider = [NSSlider sliderWithValue:[self lineWidth] minValue:1 maxValue:8 target:nil action:NULL];
	[slider setNumberOfTickMarks:8];
	[slider setAllowsTickMarkValuesOnly:YES];
	[[[slider widthAnchor] constraintEqualToConstant:120] setActive:YES];
	[slider bind:NSValueBinding toObject:self withKeyPath:@"lineWidth" options:nil];
	_lineWidthLabel = [NSTextField labelWithString:[self lineWidthText]];
	[_lineWidthLabel setTextColor:[NSColor secondaryLabelColor]];
	NSStackView *lineWidthRow = [NSStackView stackViewWithViews:@[lineWidthTitle, slider, _lineWidthLabel]];

	/* Size the warning with its text so the panel reserves room for it, then
	 show it only when it applies */
	_warningLabel = [NSTextField wrappingLabelWithString:[self warningText]];
	[_warningLabel setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[_warningLabel setTextColor:[NSColor systemRedColor]];
	[_warningLabel setPreferredMaxLayoutWidth:320];

	NSStackView *stack = [NSStackView stackViewWithViews:@[scaleRow, _warningLabel, lineWidthRow]];
	[stack setOrientation:NSUserInterfaceLayoutOrientationVertical];
	[stack setAlignment:NSLayoutAttributeLeading];
	[stack setEdgeInsets:NSEdgeInsetsMake(8, 20, 8, 20)];
	[stack setFrameSize:[stack fittingSize]];
	[self setView:stack];

	[self updateWarning];
}

- (NSString *)warningText {
	return NSLocalizedString(@"At actual size this design doesn't fit on the page and will be cut off. Try Landscape, a larger paper size, or Fit to Page.", @"Print panel warning when the design is larger than the printable area");
}

- (void)setDesignTooLarge:(BOOL)designTooLarge {
	_designTooLarge = designTooLarge;
	[self updateWarning];
}

- (void)updateWarning {
	[_warningLabel setStringValue:([self designTooLarge] ? [self warningText] : @"")];
}

- (NSInteger)printScale {
	return [[NSUserDefaults standardUserDefaults] integerForKey:PESPrintScaleKey];
}

- (void)setPrintScale:(NSInteger)printScale {
	[[NSUserDefaults standardUserDefaults] setInteger:printScale forKey:PESPrintScaleKey];
}

- (void)setLineWidth:(CGFloat)lineWidth {
	_lineWidth = lineWidth;
	[_lineWidthLabel setStringValue:[self lineWidthText]];
}

#pragma mark NSPrintPanelAccessorizing

- (NSArray<NSDictionary<NSPrintPanelAccessorySummaryKey, NSString *> *> *)localizedSummaryItems {
	NSArray *titles = [self scaleTitles];
	NSInteger scale = MIN(MAX([self printScale], 0), (NSInteger)[titles count] - 1);
	return @[@{NSPrintPanelAccessorySummaryItemNameKey: NSLocalizedString(@"Scale", @"Print panel summary item name"),
			   NSPrintPanelAccessorySummaryItemDescriptionKey: titles[scale]},
			 @{NSPrintPanelAccessorySummaryItemNameKey: NSLocalizedString(@"Line Width", @"Print panel summary item name"),
			   NSPrintPanelAccessorySummaryItemDescriptionKey: [self lineWidthText]}];
}

- (NSSet<NSString *> *)keyPathsForValuesAffectingPreview {
	return [NSSet setWithObjects:@"printScale", @"lineWidth", nil];
}

@end
