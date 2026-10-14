//
//  InspectorPanelController.m
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

#import "InspectorPanelController.h"
#import "PESDocument.h"


static void *ActiveDocumentContext = &ActiveDocumentContext;

@implementation InspectorPanelController

@synthesize inspectedDocument;


- (id) init {
    return [super initWithWindowNibName:@"InspectorPanel"];
}
 

/*
 inspectedDocument is a KVO-compliant property, which this method manages.
 Anytime we hear about the mainWindow, or the mainWindow's document change, we
 check to see what changed. Note that activeDocumentChanged doesn't mean
 document contents changed, but rather we have a new active document.
 */
- (void) activeDocumentChanged {
	//NSLog(@"InspectorPanelController::activeDocumentChanged\n");
	//NSLog([self.inspectedDocument class]);
    id mainDocument = [[[NSApp mainWindow] windowController] document];
	
	/* If there is no main document, there should be nothing for the panel to
	 * inspect. The panel will then reflect disabled controls. */
	if (mainDocument == nil) {
		//NSLog(@"mainDocument == nil");
		self.inspectedDocument = nil;
	}//*/
	
	/* If the main document was switched ... */
    if (mainDocument != self.inspectedDocument && [mainDocument isKindOfClass:[PESDocument class]]) {
		/* ... and we had been looking at another main document... */
		if (self.inspectedDocument) {
			/* finish doing stuff with it */
			//NSLog(@"finished with inspected document");
			[documentObjectController commitEditing];
		}
		//self.inspectedDocument = (mainDocument && [mainDocument isKindOfClass:[PESDocument class]]) ? mainDocument : nil;   
		if (mainDocument) {
			if ([mainDocument isKindOfClass:[PESDocument class]]) {
				//NSLog(@"mainDocument is PESDocument");
				self.inspectedDocument = mainDocument;
			} else {
				//NSLog(@"mainDocument is not PESDocument");
				self.inspectedDocument = nil;
			}
		} else {
			//NSLog(@"no mainDocument");
			self.inspectedDocument = nil;
		}
    }
}


/* KVO change notification: if the context is ActiveDocumentContext, this is a
 * notification that the value associated with the keypath we
 * observed ([NSApp].mainWindow.windowController.document) changed, hence the
 * active document changed. If the context is something else, pass it up the
 * chain. */
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	//NSLog(@"InspectorPanelController::observeValueForKeyPath\n");
    if (context == ActiveDocumentContext) {
		//NSLog(@"keyPath:"); NSLog(keyPath);
		[self activeDocumentChanged];
    } else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

/* When controls in the panel start editing, register it with the inspected
 * document. */
- (void) objectDidBeginEditing:(id)editor {
	//NSLog(@"InspectorPanelController::objectDidBeginEditing\n");
	if ([inspectedDocument isKindOfClass:[PESDocument class]]) {
		[inspectedDocument objectDidBeginEditing:editor];
	}
}

- (void) objectDidEndEditing:(id)editor {
	//NSLog(@"InspectorPanelController::objectDidEndEditing\n");
	if ([inspectedDocument isKindOfClass:[PESDocument class]]) {
		[inspectedDocument objectDidEndEditing:editor];
	}
}

/* We don't want to do any observing until the properties panel is brought
 * up. */
- (void) windowDidLoad {
	//NSLog(@"InspectorPanelController::windowDidLoad\n");
    /* Once the UI is loaded, we start observing the panel itself to commit
	 * editing when it becomes inactive (loses key state) */
    [[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(inspectorPanelDidResignKey:)
		name:NSWindowDidResignKeyNotification
		object:[self window]
	];
	
    /* Make sure we start inspecting the document that is currently active, and
	 * start observing changes */
    [self activeDocumentChanged];
    [NSApp
		addObserver:self
		forKeyPath:@"mainWindow.windowController.document"
		options:0
		context:ActiveDocumentContext
	];
	
	/* It's documented to do nothing, but still a good idea to invoke... */
    [super windowDidLoad];
}

/* Whenever the properties panel loses key status, we want to commit editing. */
- (void) inspectorPanelDidResignKey:(NSNotification *)notification {
	//NSLog(@"InspectorPanelController::inspectorPanelDidResignKey\n");
    [documentObjectController commitEditing];
}

/*
 Since we want the panel to toggle...
 Note that if the window is visible and key, we order it out; otherwise we make it key.
 */
- (void) toggleInspectorPanel:(id)sender {
	//NSLog(@"InspectorPanelController::toggleInspectorPanel\n");
    NSWindow *window = [self window];
    if ([window isVisible] && [window isKeyWindow]) {
		[window orderOut:sender];
    } else {
		[window makeKeyAndOrderFront:sender];
    }
}

/*
 validateMenuItem: is used to dynamically set attributes of menu items.
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem {
	//NSLog(@"InspectorPanelController::validateMenuItem\n");
    if ([menuItem action] == @selector(toggleInspectorPanel:)) {  
		// Correctly toggle the menu item for showing/hiding document properties
		// We call [self isWindowLoaded] first since it prevents [self window] from loading the nib
		
		NSString *menuTitle = nil;
		
		if (![self isWindowLoaded] || ![[self window] isVisible] || ![[self window] isKeyWindow]) {
			// the panel is not loaded, not visible, or not key
			menuTitle = NSLocalizedString(@"Show Design Information",
										  @"Title for menu item to show the document properties panel (should be the same as the initial menu item in the nib).");
 		} else {
			menuTitle = NSLocalizedString(@"Hide Design Information",
										  @"Title for menu item to hide the Inspector panel.");
		}
		[menuItem setTitleWithMnemonic:menuTitle];
    }
    return YES;
}

@end
