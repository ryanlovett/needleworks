//
//  DesignView.h
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

#import "DesignView.h"
#import "PESDocument.h"
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>

/* The largest image of the whole design the view keeps for redrawing and
 zooming, in pixels (48 MB). Beyond this zoom only part of the design is
 visible, and drawing just that part is fast. */
static const CGFloat DesignViewMaximumImagePixels = 12e6;

@implementation DesignView {
	/* The whole design drawn at the zoom it was last shown at, the area it
	 covers in design units, and the settings it was drawn with */
	NSImage *designImage;
	NSRect designImageRect;
	NSArray *designImageSettings;

	/* Images are drawn in the background, one at a time; each request has a
	 new number, so only the latest one is used */
	dispatch_queue_t renderQueue;
	NSUInteger renderNumber;
	NSRect requestedRect;
	NSArray *requestedSettings;

	BOOL liveMagnifying;
	CGFloat shownMagnification;
}

@synthesize delegate;

/* Everything besides the zoom that changes how the design looks */
- (NSArray *) drawingSettings {
	PESDocument *doc = [self delegate];
	return @[@([doc stitchStyle]), @([doc showJumpStitches]), @([doc lineWidth]), [doc fabricColor]];
}

/* Whether two areas cover the same pixels, allowing for rounding */
static BOOL SamePixels(CGContextRef context, NSRect a, NSRect b) {
	CGRect da = CGContextConvertRectToDeviceSpace(context, a);
	CGRect db = CGContextConvertRectToDeviceSpace(context, b);
	return fabs(CGRectGetMinX(da) - CGRectGetMinX(db)) < 0.01 && fabs(CGRectGetMinY(da) - CGRectGetMinY(db)) < 0.01 &&
		fabs(CGRectGetWidth(da) - CGRectGetWidth(db)) < 0.01 && fabs(CGRectGetHeight(da) - CGRectGetHeight(db)) < 0.01;
}

+ (NSImage *) imageOfStitchBlocks:(NSArray *)stitchBlocks settings:(NSArray *)settings rect:(NSRect)rect pixelRect:(CGRect)pixelRect {
	return [PESRenderer imageOfStitchBlocks:stitchBlocks
									  style:[settings[0] integerValue]
								fabricColor:settings[3]
								  lineWidth:[settings[2] doubleValue]
						   showJumpStitches:[settings[1] boolValue]
									   rect:rect
								 pixelsWide:(NSInteger)CGRectGetWidth(pixelRect)
								 pixelsHigh:(NSInteger)CGRectGetHeight(pixelRect)];
}

- (void) drawRect:(NSRect) rect {
	PESDocument* doc = [self delegate];
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	NSArray *settings = [self drawingSettings];

	/* The pixels the design covers at the current zoom, and the area those
	 whole pixels cover in design units, so an image of it lines up with the
	 screen's pixels */
	CGRect pixelRect = CGRectIntegral(CGContextConvertRectToDeviceSpace(context, [self bounds]));
	NSRect imageRect = CGContextConvertRectToUserSpace(context, pixelRect);
	BOOL imageFits = CGRectGetWidth(pixelRect) * CGRectGetHeight(pixelRect) <= DesignViewMaximumImagePixels;
	BOOL haveImage = designImage != nil && [designImageSettings isEqual:settings];

	if (haveImage && SamePixels(context, designImageRect, imageRect)) {
		[designImage drawInRect:designImageRect];
		return;
	}

	/* While zooming, scale the image last drawn; a sharp one is drawn when
	 the zoom settles */
	if (haveImage && (liveMagnifying || imageFits)) {
		[designImage drawInRect:designImageRect];
		if (!liveMagnifying && imageFits) {
			[self requestImageWithSettings:settings rect:imageRect pixelRect:pixelRect context:context];
		}
		return;
	}

	if (imageFits) {
		designImage = [DesignView imageOfStitchBlocks:[doc stitchBlocks] settings:settings rect:imageRect pixelRect:pixelRect];
		designImageRect = imageRect;
		designImageSettings = settings;
		[designImage drawInRect:designImageRect];
		return;
	}

	[PESRenderer drawStitchBlocks:[doc stitchBlocks]
							 style:[doc stitchStyle]
					   fabricColor:[doc fabricColor]
						 lineWidth:[doc lineWidth]
				  showJumpStitches:[doc showJumpStitches]
							inRect:rect];
}

/* Draws an image of the design in the background, then shows it */
- (void) requestImageWithSettings:(NSArray *)settings rect:(NSRect)rect pixelRect:(CGRect)pixelRect context:(CGContextRef)context {
	if ([requestedSettings isEqual:settings] && SamePixels(context, requestedRect, rect)) {
		return;
	}
	requestedRect = rect;
	requestedSettings = settings;

	if (renderQueue == nil) {
		renderQueue = dispatch_queue_create("org.spacecoaster.NeedleWorks.DesignView", DISPATCH_QUEUE_SERIAL);
	}
	NSUInteger number = ++renderNumber;
	NSArray *stitchBlocks = [[[self delegate] stitchBlocks] copy];
	__weak DesignView *weakSelf = self;
	dispatch_async(renderQueue, ^{
		/* Skip requests that a newer one has replaced */
		DesignView *view = weakSelf;
		if (view == nil || number != view->renderNumber) {
			return;
		}
		view = nil;
		NSImage *image = [DesignView imageOfStitchBlocks:stitchBlocks settings:settings rect:rect pixelRect:pixelRect];
		dispatch_async(dispatch_get_main_queue(), ^{
			DesignView *view = weakSelf;
			if (view == nil || number != view->renderNumber) {
				return;
			}
			view->designImage = image;
			view->designImageRect = rect;
			view->designImageSettings = settings;
			view->requestedSettings = nil;
			[view setNeedsDisplay:YES];
		});
	});
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSScrollViewWillStartLiveMagnifyNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSScrollViewDidEndLiveMagnifyNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
}

- (void) viewDidMoveToWindow {
	NSScrollView *scrollView = [self enclosingScrollView];
	if (scrollView != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willStartLiveMagnify:) name:NSScrollViewWillStartLiveMagnifyNotification object:scrollView];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEndLiveMagnify:) name:NSScrollViewDidEndLiveMagnifyNotification object:scrollView];

		/* Zooming changes the clip view's bounds */
		NSClipView *clipView = [scrollView contentView];
		[clipView setPostsBoundsChangedNotifications:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clipViewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:clipView];
	}
}

/* When the zoom changes, AppKit can scale what the view last drew without
 asking it to draw again, for example when a window is restored zoomed in.
 Redraw at the new zoom once AppKit's display pass is over. */
- (void) clipViewBoundsDidChange:(NSNotification *)notification {
	CGFloat magnification = [[self enclosingScrollView] magnification];
	if (magnification == shownMagnification || liveMagnifying) {
		return;
	}
	shownMagnification = magnification;

	__weak DesignView *weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf setNeedsDisplay:YES];
	});
}

/* Moving to a screen with a different resolution needs a new image */
- (void) viewDidChangeBackingProperties {
	[super viewDidChangeBackingProperties];
	[self setNeedsDisplay:YES];
}

- (void) willStartLiveMagnify:(NSNotification *)notification {
	liveMagnifying = YES;
}

- (void) didEndLiveMagnify:(NSNotification *)notification {
	liveMagnifying = NO;
	shownMagnification = [[self enclosingScrollView] magnification];

	/* AppKit redraws for the final zoom before telling us the gesture has
	 ended, so that redraw showed the scaled image. Ask for a sharp one once
	 AppKit's own display pass is over, or the request is lost. */
	__weak DesignView *weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf setNeedsDisplay:YES];
	});
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
