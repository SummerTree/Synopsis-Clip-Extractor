//
//  KeyframeView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/4/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "KeyframeView.h"

@interface KeyframeView ()

@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CGFloat magnification;

// Scaled units
@property (nonatomic, assign) CGFloat frameTickInPixels;
@property (nonatomic, assign) CGFloat frameDurationInPixels;
@property (nonatomic, assign) CGFloat totalDurationInPixels;

@end

@implementation KeyframeView

- (void) awakeFromNib
{
    self.duration = CMTimeMakeWithSeconds(5, 600);
    self.frameDuration = CMTimeMake(30,1);
    self.magnification = 1.0;
    
    [self recalculateUnits];
}

- (void) magnifyWithEvent:(NSEvent *)event
{
    self.magnification += event.magnification;
    self.magnification = MAX(0.1, self.magnification);
    self.magnification = MIN(10, self.magnification);
    
    
    [self recalculateUnits];
    
//    NSSize scale = NSMakeSize(self.scale.width + event.magnification, 1.0);
//    [self setScale:scale];
}

- (void) scrollWheel:(NSEvent *)event
{
    if(self.bounds.size.width < self.totalDurationInPixels)
    {
        self.scrollOrigin -= event.deltaX;
        self.scrollOrigin = MAX(self.scrollOrigin, 0);
        self.scrollOrigin = MIN(self.scrollOrigin, self.totalDurationInPixels - self.bounds.size.width);
    }
    
    [self setNeedsDisplay:YES];
}

- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration
{
    self.frameDuration = frameDuration;
    self.duration = duration;
    
    [self recalculateUnits];
}

- (void) recalculateUnits
{
    self.frameTickInPixels = 1.0 * self.magnification;
    self.frameDurationInPixels = self.frameTickInPixels * self.frameDuration.value;
    self.totalDurationInPixels = self.frameTickInPixels * self.duration.value;
    
    NSLog(@"m %f ftp %f, fdp %f, tdp %f", self.magnification, self.frameTickInPixels, self.frameDurationInPixels, self.totalDurationInPixels);

    [self setNeedsDisplay:YES];
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
    
    // Unit
    
    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];

        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);

        for(NSUInteger i = 0; i < clippedDirtyRect.size.width + self.frameDurationInPixels; i ++)
        {
            
            // Draw tick Boundaries
            [[NSColor blackColor] setStroke];
            if( i % (int)round(self.frameTickInPixels) == 0)
            {
                CGFloat x = i - fmod(self.scrollOrigin, self.frameTickInPixels);
                
                if(x  >= self.totalDurationInPixels)
                    break;
                
                NSPoint p1 = NSMakePoint(x, self.bounds.size.height);
                NSPoint p2 = NSMakePoint(x, self.bounds.size.height * 0.75);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            }
            
            // Draw Frame Boundaries
            [[NSColor lightGrayColor] setStroke];
            [[NSColor lightGrayColor] setFill];
            if( i % (int)round(self.frameDurationInPixels) == 0)
            {
                CGFloat x = i - fmod(self.scrollOrigin, self.frameDurationInPixels);
                
                if(x  >= self.totalDurationInPixels)
                    break;
                
                NSPoint p1 = NSMakePoint(x, self.bounds.size.height);
                NSPoint p2 = NSMakePoint(x, self.bounds.size.height * 0.5);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
                
                NSString* label = [NSString stringWithFormat:@"f %i", (int)round((x + self.scrollOrigin)/self.frameTickInPixels) ];
                
                CGContextSetLineWidth(context, 2.0);
                CGContextSelectFont(context, "Helvetica", 8, kCGEncodingMacRoman);
                CGContextSetCharacterSpacing(context, 1.7);
                CGContextSetTextDrawingMode(context, kCGTextFill);
                CGContextShowTextAtPoint(context, p1.x, p2.y -10, [label cStringUsingEncoding:NSASCIIStringEncoding], label.length);
            }
            
            // Draw Second Boundaries
            [[NSColor yellowColor] setStroke];
            [[NSColor yellowColor] setFill];
            if( i % (int)round(self.frameDurationInPixels * self.frameDuration.value) == 0)
            {
                CGFloat x = i - fmod(self.scrollOrigin, self.frameDurationInPixels * self.frameDuration.value );
                
                if(x  >= self.totalDurationInPixels)
                    break;
                
                NSPoint p1 = NSMakePoint(x, 0);
                NSPoint p2 = NSMakePoint(x, self.bounds.size.height);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
                
                
                NSString* label = [NSString stringWithFormat:@"s %i", (int)round((x + self.scrollOrigin)/self.frameTickInPixels) ];
                
                CGContextSetLineWidth(context, 2.0);
                CGContextSelectFont(context, "Helvetica", 8, kCGEncodingMacRoman);
                CGContextSetCharacterSpacing(context, 1.7);
                CGContextSetTextDrawingMode(context, kCGTextFill);
                CGContextShowTextAtPoint(context, p1.x, p2.y * 0.25 - 4, [label cStringUsingEncoding:NSASCIIStringEncoding], label.length);
            }

            
        }

    }
}

static const NSSize unitSize = {1.0, 1.0};

// Returns the scale of the receiver's coordinate system, relative to the window's base coordinate system.
- (NSSize)scale;
{
    return [self convertSize:unitSize toView:nil];
}

// Sets the scale in absolute terms.
- (void)setScale:(NSSize)newScale;
{
    [self resetScaling]; // First, match our scaling to the window's coordinate system
    [self scaleUnitSquareToSize:newScale]; // Then, set the scale.
    [self setNeedsDisplay:YES]; // Finally, mark the view as needing to be redrawn
}

// Makes the scaling of the receiver equal to the window's base coordinate system.
- (void)resetScaling;
{
    [self scaleUnitSquareToSize:[self convertSize:unitSize fromView:nil]];
}

@end
