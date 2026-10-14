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

	char buffer[4];
	unsigned char b[4];
	int ptr, i, *colors;
	int32_t pecstart;

	NSData *pesData = [NSData dataWithContentsOfURL:url];

	if (pesData == nil) {
		return nil;
	}

	const unsigned char *pesBytes = [pesData bytes];

	[pesData getBytes:buffer length:4];

	if (strncmp("#PES", buffer, 4)) {
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

	/* Move to pecstart + 48 */
	ptr = pecstart + 48;

	/* Fetch the number of colors in our document */
	_numColors = pesBytes[ptr++] + 1;
	_numColorChanges = 0;

	_numStitches = 0;
	int numBlockStitches = 0;

	/* Allocate a list of colors (integers) */
	colors = malloc(sizeof(int) * _numColors);
	/* Walk our byte array and fetch each color */
	for (i = 0; i < _numColors; i += 1) {
		colors[i] = pesBytes[ptr++];
	}

	/* Move to stitches */
	ptr = pecstart + 532;

	unsigned char val1, val2;
	BOOL stitchBlockDone = FALSE, jumpStitch;
	int colorNum = -1;
	NSPoint prev = NSZeroPoint, delta = NSZeroPoint, tmpPoint;
	NSBezierPath *tempStitches = [NSBezierPath bezierPath];
	NSBezierPath *tempStitchesAndJumps = [NSBezierPath bezierPath];
	StitchBlock *curBlock;

	while (!stitchBlockDone) {
		jumpStitch = FALSE;
		val1 = pesBytes[ptr++];
		val2 = pesBytes[ptr++];

		if (val1 == 255 && val2 == 0) {
			stitchBlockDone = TRUE;

			/* Allocate the last block */
			curBlock = [[StitchBlock alloc] init];

			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			[curBlock setStitchesAndJumps:tempStitchesAndJumps];

			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];

			/* Save our block */
			[self addStitchBlock:curBlock];
		}
		// color switch, start a new block
		else if (val1 == 254 && val2 == 176) {
			_numColorChanges += 1;

			/* Allocate a block */
			curBlock = [[StitchBlock alloc] init];

			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			[curBlock setStitchesAndJumps:tempStitchesAndJumps];

			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];

			/* Save our block */
			[self addStitchBlock:curBlock];

			/* Start a new stitch */
			tempStitches = [NSBezierPath bezierPath];
			tempStitchesAndJumps = [NSBezierPath bezierPath];
			_numStitches = 0;

			/* Skip a "useless" byte */
			ptr += 1;
		} else {
			delta = NSZeroPoint;

			if ((val1 & 0x80) == 0x80) {
				jumpStitch = TRUE;
				delta.x = ((val1 & 0xF) * 256) + val2;
				if (((int)delta.x & 0x800) == 0x800) {
					delta.x = (int)((int)delta.x | 0xFFFFF000);
				}
				val2 = pesBytes[ptr++];
			} else {
				delta.x = (int)val1;
				if (delta.x > 63) {
					delta.x -= 128;
				}
			}

			if ((val2 & 0x80) == 0x80) {
				jumpStitch = TRUE;
				delta.y = ((val2 & 0xF) * 256) + pesBytes[ptr++];
				if (((int)delta.y & 0x800) == 0x800) {
					delta.y = (int)((int)delta.y | 0xFFFFF000);
				}
			} else {
				delta.y = (int)val2;
				if (delta.y > 63) {
					delta.y -= 128;
				}
			}
			tmpPoint.x = prev.x + delta.x;
			tmpPoint.y = prev.y + delta.y;

			if (_numStitches == 0) {
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

	free(colors);

	// Determine the physical size of our design
	CGFloat w = _maxPoint.x - _minPoint.x;
	CGFloat h = _maxPoint.y - _minPoint.y;
	_designSize = [[NSString alloc] initWithFormat:@"%.2f\" x %.2f\" (%.0f mm x %.0f mm)",
			w / 254, h / 254, w / 10, h / 10];

	return self;
}

- (int32_t)readInt32:(unsigned char *)bytes {
	return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
}

- (void)addStitchBlock:(StitchBlock *)block {
	[_stitchBlocks addObject:block];
}

- (NSArray<StitchBlock *> *)stitchBlocks {
	return _stitchBlocks;
}

@end
