#!/bin/sh
#
# Makes AppIcon.icns, the app icon, with IconGenerator.swift, and keeps a
# 1024-pixel copy to look at in icon-1024.png. The same seed always gives
# the same icon; another seed lays the stitches out a little differently.
#
# usage: Icon/make-icon.sh [seed]

set -e
cd "$(dirname "$0")"

FONT=CinzelDecorative-Bold.ttf
SEED=${1:-1}
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

# A clean environment, so tools such as conda can't change the build, and
# for the same macOS as the app.
env -i PATH=/usr/bin:/bin HOME="$HOME" xcrun swiftc -O -target "$(uname -m)-apple-macos12.0" \
	-o "$BUILD/IconGenerator" -parse-as-library IconGenerator.swift ../NeedleWorksKit/*.swift

"$BUILD/IconGenerator" "$FONT" "$BUILD/AppIcon.iconset" "$SEED"
iconutil -c icns -o ../AppIcon.icns "$BUILD/AppIcon.iconset"
cp "$BUILD/AppIcon.iconset/icon_512x512@2x.png" icon-1024.png
echo "Made AppIcon.icns and Icon/icon-1024.png (seed $SEED)"
