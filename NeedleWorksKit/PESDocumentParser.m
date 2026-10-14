//
//  PESDocumentParser.m
//  NeedleWorksKit
//

#import "PESDocumentParser.h"
#import "StitchBlock.h"

@implementation PESDocumentParser {
	NSMutableArray<StitchBlock *> *_stitchBlocks;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)outError {
	self = [super init];
	if (!self) {
		return nil;
	}

	_stitchBlocks = [[NSMutableArray alloc] init];

	unsigned char b[4];
	int i, *colors;
	NSUInteger ptr;
	int32_t pecstart;

	NSData *pesData = [NSData dataWithContentsOfURL:url];

	if (pesData == nil) {
		return nil;
	}

	const unsigned char *pesBytes = [pesData bytes];
	NSUInteger length = [pesData length];

	if (length < 12 || strncmp("#PES", (const char *)pesBytes, 4)) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
		}
		return nil;
	}

	/* The value at 8 is an int representing pecstart */
	NSRange startRange;
	startRange.location = 8;
	startRange.length = 4;
	[pesData getBytes:b range:startRange];

	pecstart = [self readInt32:b];

	/* The PEC header (including the color list) runs up to the stitches at
	 * pecstart + 532, so make sure the file is at least that long. */
	if (pecstart < 0 || (NSUInteger)pecstart + 532 > length) {
		if (outError != NULL) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		}
		return nil;
	}

	/* The 24-bit value at pecstart + 514 is the offset of the thumbnail
	 * graphics, which immediately follow the stitches. Use it to bound the
	 * stitch data when it is plausible; otherwise fall back to the file
	 * length and rely on the end marker. */
	NSUInteger stitchStart = (NSUInteger)pecstart + 532;
	NSUInteger graphicsOffset = pesBytes[pecstart + 514] | (pesBytes[pecstart + 515] << 8) | (pesBytes[pecstart + 516] << 16);
	NSUInteger stitchEnd = (NSUInteger)pecstart + 513 + graphicsOffset;
	if (stitchEnd <= stitchStart || stitchEnd > length) {
		stitchEnd = length;
	}

	/* Move to pecstart + 48 */
	ptr = pecstart + 48;

	/* Fetch the number of colors in our document. The stored value is the
	 * number of colors minus one, and 0xFF means there are no colors. */
	unsigned char storedColors = pesBytes[ptr++];
	_numColors = (storedColors == 0xFF) ? 0 : storedColors + 1;
	_numColorChanges = 0;

	_numStitches = 0;
	int numBlockStitches = 0;

	/* Allocate a list of colors (integers) */
	colors = malloc(sizeof(int) * MAX(_numColors, 1));
	/* Walk our byte array and fetch each color */
	for (i = 0; i < _numColors; i += 1) {
		colors[i] = pesBytes[ptr++];
	}

	/* Move to stitches */
	ptr = stitchStart;

	unsigned char cmd;
	BOOL jumpStitch;
	int colorNum = -1;
	NSPoint prev = NSZeroPoint, delta = NSZeroPoint, tmpPoint;
	NSBezierPath *tempStitches = [NSBezierPath bezierPath];
	NSBezierPath *tempStitchesAndJumps = [NSBezierPath bezierPath];

	/* Stop at the end marker (0xFF), or if the stitch data runs out */
	while (ptr < stitchEnd) {
		cmd = pesBytes[ptr];

		if (cmd == 0xFF) {
			break;
		}
		// color switch (0xFE plus two more bytes), start a new block
		else if (cmd == 0xFE) {
			_numColorChanges += 1;

			colorNum = [self addBlockWithStitches:tempStitches
								  stitchesAndJumps:tempStitchesAndJumps
									   numStitches:numBlockStitches
										colorNum:colorNum
										  colors:colors];

			/* Start a new stitch */
			tempStitches = [NSBezierPath bezierPath];
			tempStitchesAndJumps = [NSBezierPath bezierPath];
			numBlockStitches = 0;

			ptr += 3;
		} else {
			jumpStitch = FALSE;
			if (![self readCoordinate:&delta.x bytes:pesBytes ptr:&ptr end:stitchEnd jump:&jumpStitch] ||
				![self readCoordinate:&delta.y bytes:pesBytes ptr:&ptr end:stitchEnd jump:&jumpStitch]) {
				/* The stitch data was cut off mid-stitch */
				break;
			}

			tmpPoint.x = prev.x + delta.x;
			tmpPoint.y = prev.y + delta.y;

			if (numBlockStitches == 0) {
				/* Start here */
				[tempStitches moveToPoint:tmpPoint];
				[tempStitchesAndJumps moveToPoint:tmpPoint];
			} else if (jumpStitch) {
				/* then draw a line to here for the other stitches */
				[tempStitches moveToPoint:tmpPoint];
				[tempStitchesAndJumps lineToPoint:tmpPoint];
			} else {
				/* then draw a line to here for the other stitches */
				[tempStitches lineToPoint:tmpPoint];
				[tempStitchesAndJumps lineToPoint:tmpPoint];
			}

			/* Stitches in our block */
			numBlockStitches += 1;
			/* Stitches in our design */
			_numStitches += 1;

			prev.x += delta.x;
			prev.y += delta.y;
			if (prev.x > _maxPoint.x) {
				_maxPoint.x = prev.x;
			} else if (prev.x < _minPoint.x) {
				_minPoint.x = prev.x;
			}
			if (prev.y > _maxPoint.y) {
				_maxPoint.y = prev.y;
			} else if (prev.y < _minPoint.y) {
				_minPoint.y = prev.y;
			}
		}
	}

	/* Save the last block, unless the design has no stitches at all */
	if (numBlockStitches > 0 || [_stitchBlocks count] > 0) {
		[self addBlockWithStitches:tempStitches
			  stitchesAndJumps:tempStitchesAndJumps
				   numStitches:numBlockStitches
					colorNum:colorNum
					  colors:colors];
	}

	free(colors);

	// Determine the physical size of our design
	CGFloat w = _maxPoint.x - _minPoint.x;
	CGFloat h = _maxPoint.y - _minPoint.y;
	/* Show the size in the user's preferred units first, with the other
	 units in parentheses */
	NSString *inches = [NSString stringWithFormat:@"%.2f\" x %.2f\"", w / 254, h / 254];
	NSString *millimeters = [NSString stringWithFormat:@"%.0f mm x %.0f mm", w / 10, h / 10];
	if ([[NSLocale currentLocale] usesMetricSystem]) {
		_designSize = [NSString stringWithFormat:@"%@ (%@)", millimeters, inches];
	} else {
		_designSize = [NSString stringWithFormat:@"%@ (%@)", inches, millimeters];
	}

	return self;
}

- (int32_t)readInt32:(unsigned char *)bytes {
	return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
}

/* Read one stitch coordinate delta. A coordinate is either one byte (7-bit
 * signed) or, when the high bit is set, two bytes holding a 12-bit signed
 * value whose flag bits mark a trim (0x20) or jump (0x10). Returns NO if the
 * stitch data ends first. */
- (BOOL)readCoordinate:(CGFloat *)value bytes:(const unsigned char *)bytes ptr:(NSUInteger *)ptr end:(NSUInteger)end jump:(BOOL *)jump {
	if (*ptr >= end) {
		return NO;
	}
	int u = bytes[(*ptr)++];

	if ((u & 0x80) == 0x80) {
		if (*ptr >= end) {
			return NO;
		}
		if ((u & 0x30) != 0) {
			*jump = YES;
		}
		u = ((u & 0x0F) << 8) + bytes[(*ptr)++];
		if ((u & 0x800) == 0x800) {
			u -= 0x1000;
		}
	} else if (u > 63) {
		u -= 128;
	}

	*value = u;
	return YES;
}

/* Save a finished block of stitches with the next thread color, and return
 * the index of the color used. Malformed files can have more color changes
 * than colors, so the last color is reused. */
- (int)addBlockWithStitches:(NSBezierPath *)stitches
		   stitchesAndJumps:(NSBezierPath *)stitchesAndJumps
				numStitches:(int)numStitches
				   colorNum:(int)colorNum
					 colors:(const int *)colors {
	StitchBlock *block = [[StitchBlock alloc] init];
	[block setStitches:stitches];
	[block setStitchesAndJumps:stitchesAndJumps];
	[block setNumStitches:numStitches];

	if (_numColors > 0) {
		colorNum = MIN(colorNum + 1, (int)_numColors - 1);
		[block setColorIndex:colors[colorNum]];
	}

	[self addStitchBlock:block];
	return colorNum;
}

- (void)addStitchBlock:(StitchBlock *)block {
	[_stitchBlocks addObject:block];
}

- (NSArray<StitchBlock *> *)stitchBlocks {
	return _stitchBlocks;
}

@end
