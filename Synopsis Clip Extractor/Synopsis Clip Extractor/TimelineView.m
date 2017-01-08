//
//  TimelineView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/7/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "TimelineView.h"
@interface TimelineView()
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime duration;
@end

@implementation TimelineView

- (void) awakeFromNib
{
    self.enclosingScrollView.hasVerticalScroller = NO;
    self.enclosingScrollView.hasHorizontalScroller = YES;
    self.enclosingScrollView.scrollsDynamically = YES;
}

- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration
{
    if(CMTIME_IS_VALID(frameDuration) && CMTIME_IS_VALID(duration))
    {
        self.frameDuration = frameDuration;
        self.duration = duration;
        
        [self setBoundsSize:NSMakeSize(self.duration.value / self.frameDuration.value, self.bounds.size.height)];
        NSLog(@"size : %@", NSStringFromSize(self.bounds.size));
        [self setNeedsDisplay:YES];
    }
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
    
    // Unit calculations
    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];
        
        NSLog(@"Drawing Rect: %@", NSStringFromRect(clippedDirtyRect));
        
        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);
        
        for(NSUInteger i = 0; i < clippedDirtyRect.size.width ; i ++)
        {
            CGFloat x = (CGFloat)i + clippedDirtyRect.origin.x;
            
            // Draw tick Boundaries
            [[NSColor blackColor] setStroke];
            if( i % 2 == 0)
            {
                NSPoint p1 = NSMakePoint(x, clippedDirtyRect.size.height);
                NSPoint p2 = NSMakePoint(x, clippedDirtyRect.size.height * 0.5);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            }
        }
    }
}
@end
