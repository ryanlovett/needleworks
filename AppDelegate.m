//
//  AppDelegate.m
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

#import "AppDelegate.h"

@implementation AppDelegate

- (id)init {
	self = [super init];
	//NSLog(@"AppDelegate::init\n");
	
	// Our application's shared color panel
	NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
	// We set the mode to custom color lists
	//[colorPanel setMode:NSColorListModeColorPanel];
	[colorPanel setMode:NSColorPanelModeWheel];
/*	
	// The paths to our .clr files in Needle Works.app/Contents/Resources/
	NSArray *colorPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"clr" inDirectory:nil];
	NSEnumerator *colorPathIter;
	NSColorList *colorList;
	
	NSArray *colorNames;
	NSEnumerator *colorNameIter;
	NSString *path, *pathBasename, *colorStr;
	
	colorPathIter = [colorPaths objectEnumerator];
	while (path = [colorPathIter nextObject]) {
		pathBasename = [path lastPathComponent];
		//colorList = [[NSColorList alloc] initWithName:[pathBasename substringToIndex:([pathBasename length] - 4)] fromFile:path];
		colorList = [[NSColorList alloc] initWithName:[pathBasename stringByDeletingPathExtension] fromFile:path];
		if (colorList != nil) {
			[colorPanel attachColorList:colorList];
			colorNames = [colorList allKeys];
			colorNameIter = [colorNames objectEnumerator];
			while (colorStr = [colorNameIter nextObject]) {
				//NSLog(colorStr);
			}
			[colorLists addObject:colorList];
		} else {
			NSLog(@"Cannot find %s color list\n", [path lastPathComponent]);
		}		
	}
*/
	return self;
}

/* Don't open a blank window when the application starts */
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

/* Investigate using applicationShouldHandleReopen:hasVisibleWindows: for 
   displaying an Open File sheet so that the user is given some feedback
   when launching the program. */
   

@end
