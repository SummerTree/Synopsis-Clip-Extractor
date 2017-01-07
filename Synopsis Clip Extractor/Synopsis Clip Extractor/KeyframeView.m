//
//  KeyframeView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/4/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "KeyframeView.h"

@interface KeyframeView ()

@property (assign) CGFloat scrollOrigin;
@property (assign) CMTime frameDuration;
@property (assign) CMTime duration;
@end

@implementation KeyframeView

- (void) awakeFromNib
{
    self.duration = CMTimeMake(6000, 600);
    self.frameDuration = CMTimeMake(30,1);
}

- (void) magnifyWithEvent:(NSEvent *)event
{
    NSLog(@"magnifyWithEvent %@", event);
}

- (void) scrollWheel:(NSEvent *)event
{
    if(self.bounds.size.width < self.duration.value)
    {
        self.scrollOrigin += event.deltaX;
        self.scrollOrigin = MAX(self.scrollOrigin, 0);
        self.scrollOrigin = MIN(self.scrollOrigin, self.duration.value);
        [self setNeedsDisplay:YES];
    }
}

- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration
{
    self.frameDuration = frameDuration;
    self.duration = duration;
}

- (BOOL) isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {

    [super drawRect:dirtyRect];
    
    // Drawing code here.
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    const NSRect *rects;
    NSInteger count;

    [self getRectsBeingDrawn:&rects count:&count];

    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];

        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);

        for(NSUInteger i = 0; i < clippedDirtyRect.size.width + self.frameDuration.value; i += self.frameDuration.value)
        {
            [[NSColor lightGrayColor] setStroke];
            
            int delta = fmod(self.scrollOrigin, self.frameDuration.value);
            int floor = (int)floorf(delta);
            
            CGFloat x = i  - fmod(self.scrollOrigin, self.frameDuration.value);
            
            if(x > self.duration.value)
                break;
            
            [NSBezierPath strokeLineFromPoint:NSMakePoint(x, 0) toPoint:NSMakePoint(x, [self bounds].size.height)];
            
            [[NSColor whiteColor] setFill];

            NSString* label = [NSString stringWithFormat:@"%i", (int)floorf(x + self.scrollOrigin)];
            
            CGContextSetLineWidth(context, 2.0);
            CGContextSelectFont(context, "Helvetica", 8, kCGEncodingMacRoman);
            CGContextSetCharacterSpacing(context, 1.7);
            CGContextSetTextDrawingMode(context, kCGTextFill);
            CGContextShowTextAtPoint(context, x, 50, [label cStringUsingEncoding:NSASCIIStringEncoding], label.length);
        }

        [[NSColor lightGrayColor] setFill];
    }
}

@end
