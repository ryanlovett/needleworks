#!/bin/sh
#
# Makes the sample designs, Needle Works.pes, Peace.pes and Flower.pes,
# with DesignGenerator.swift. They come out the same every time.
#
# usage: Designs/make-designs.sh

set -e
cd "$(dirname "$0")"

BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

# A clean environment, so tools such as conda can't change the build
env -i PATH=/usr/bin:/bin HOME="$HOME" xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" \
	-o "$BUILD/DesignGenerator" -parse-as-library DesignGenerator.swift ../Icon/Satin.swift

"$BUILD/DesignGenerator" ../Icon/CinzelDecorative-Bold.ttf .
