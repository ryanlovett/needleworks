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
#import "InspectorPanelController.h"
#import "SettingsWindowController.h"
#import <NeedleWorksKit/NeedleWorksKit-Swift.h>

@implementation AppDelegate {
	SettingsWindowController *settingsWindowController;
}

+ (void)initialize {
	if (self == [AppDelegate class]) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:@{PESStitchStyleKey: @(PESStitchStylePlain),
																   PESFabricTextureKey: @YES}];
	}
}

- (id)init {
	self = [super init];
	//NSLog(@"AppDelegate::init\n");
	
	// Our application's shared color panel
	NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
	// We set the mode to custom color lists
	//[colorPanel setMode:NSColorListModeColorPanel];
	[colorPanel setMode:NSColorPanelModeWheel];
	return self;
}

- (IBAction)toggleInspectorPanel:(id)sender {
	[[self inspectorPanelController] toggleInspectorPanel:sender];
}

- (IBAction)toggleFabricTexture:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:![defaults boolForKey:PESFabricTextureKey] forKey:PESFabricTextureKey];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ([menuItem action] == @selector(toggleFabricTexture:)) {
		BOOL shown = [[NSUserDefaults standardUserDefaults] boolForKey:PESFabricTextureKey];
		[menuItem setState:shown ? NSControlStateValueOn : NSControlStateValueOff];
	}
	return YES;
}

- (IBAction)showSettings:(id)sender {
	if (settingsWindowController == nil) {
		settingsWindowController = [[SettingsWindowController alloc] init];
	}
	[settingsWindowController showWindow:sender];
}

/* Don't open a blank window when the application starts */
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	return NO;
}

/* Investigate using applicationShouldHandleReopen:hasVisibleWindows: for 
   displaying an Open File sheet so that the user is given some feedback
   when launching the program. */
   

@end
