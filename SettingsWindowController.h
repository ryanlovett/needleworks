//
//  SettingsWindowController.h
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

#import <Cocoa/Cocoa.h>

/* The user defaults key for the stitch style new windows use (a
 PESStitchStyle). Each window can choose its own from View > Stitch Style. */
extern NSString * const PESStitchStyleKey;

/* The user defaults key for whether stitches are drawn on a woven fabric
 texture; View > Show Fabric Texture changes it */
extern NSString * const PESFabricTextureKey;

/* The user defaults key for the fabric color new windows use. Each window can
 choose its own from the toolbar. */
extern NSString * const PESFabricColorKey;

/* The fabric color in Settings, and changing it */
NSColor *PESDefaultFabricColor(void);
void PESSetDefaultFabricColor(NSColor *color);

/* The names of the stitch styles, in PESStitchStyle order */
NSArray<NSString *> *PESStitchStyleTitles(void);

/* The Settings window */
@interface SettingsWindowController : NSWindowController

@end
