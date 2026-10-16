# The app icon

`AppIcon.icns`, in the folder above, is made by the files here: a navy N,
satin-stitched on linen in a wooden embroidery hoop. The thread and the
cloth are drawn by Needle Works' own Realistic renderer and fabric texture.

To make it again:

    Icon/make-icon.sh [seed]

This builds `IconGenerator.swift` with the satin stitches in `Satin.swift`
and NeedleWorksKit's sources, writes `AppIcon.icns`, and keeps a
1024-pixel copy in `icon-1024.png` to look at.
The same font and seed always give the same icon, byte for byte. Another
seed lays the stitches out a little differently. The icon was made with
seed 1.

## Changing it

The settings at the top of `IconGenerator.swift` are the letter, its
thread and fabric colors, the letter's size in design units (0.1 mm), the
stitch spacing, and the layout of the 1024-pixel canvas. The font is set
in `make-icon.sh`.

## How the stitches are placed

This is in `Satin.swift`, which the sample designs in `Designs` use too.

The letter's outline is rasterized at one cell per design unit. An exact
distance transform finds the middle of each stroke, and the smoothed
structure tensor of its gradient gives the direction across the stroke.
Stitches are seeded along the stroke middles, about 0.19 mm apart, each
running from edge to edge.

Where strokes join, and in serifs, that direction can run along a stroke
instead, so the stitch comes out far longer than the stroke is wide. Those
seeds, and any part of the letter still bare, are stitched along a short
line across the letter instead, turning as little as possible from the
stitches around them. That way serifs are stitched across their short
side, and there are no gaps. These fill stitches are sewn first, like
underlay, so the satin lies over them.

## The font

Cinzel Decorative Bold, by Natanael Gama, from Google Fonts. It's licensed
under the SIL Open Font License 1.1, in `OFL.txt`, which allows it to be
included here.
