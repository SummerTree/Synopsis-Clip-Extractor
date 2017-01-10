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
@property (nonatomic, assign) NSUInteger numFrames;

@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) CGFloat magnification;

@property (nonatomic, assign) CGFloat zoomRangeMin;
@property (nonatomic, assign) CGFloat zoomRangeMax;


@end


//check for division by zero???
//--------------------------------------------------
static inline CGFloat map(CGFloat value, CGFloat inputMin, CGFloat inputMax, CGFloat outputMin, CGFloat outputMax, bool clamp)
{
    if (fabs(inputMin - inputMax) < FLT_EPSILON)
    {
        return outputMin;
    }
    else
    {
        float outVal = ((value - inputMin) / (inputMax - inputMin) * (outputMax - outputMin) + outputMin);
        
        if( clamp )
        {
            if(outputMax < outputMin)
            {
                if( outVal < outputMax )outVal = outputMax;
                else if( outVal > outputMin )outVal = outputMin;
            }
            else
            {
                if( outVal > outputMax )outVal = outputMax;
                else if( outVal < outputMin )outVal = outputMin;
            }
        }
        return outVal;
    }
}



@implementation TimelineView

- (void) awakeFromNib
{
    self.duration = CMTimeMakeWithSeconds(60 * 5, 600);
    self.frameDuration = CMTimeMake(1,30);
    self.magnification = 1.0;
    
    self.zoomRangeMax = 1.0;//self.bounds.size.width;
    self.zoomRangeMin = 0.0;
    
    [self recalculateUnits];
}

- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration
{
    if(CMTIME_IS_VALID(frameDuration) && CMTIME_IS_VALID(duration))
    {
        self.frameDuration = frameDuration;
        self.duration = duration;
        
        [self setNeedsDisplay:YES];
    }
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) magnifyWithEvent:(NSEvent *)event
{
    self.magnification += event.magnification;
    self.magnification = MAX(0.001, self.magnification);
    self.magnification = MIN(10, self.magnification);
    
    //    NSPoint pointInView = [self convertPoint:event.locationInWindow fromView:nil];
    //    NSLog(@"pointInView: %f", pointInView.x );
    //    [self updateScrollOrigin: ( -pointInView.x )];
    
    [self recalculateUnits];
    
    //    NSSize scale = NSMakeSize(self.scale.width + event.magnification, 1.0);
    //    [self setScale:scale];
}

- (void) scrollWheel:(NSEvent *)event
{
//    if(self.bounds.size.width < self.totalDurationInPixels)
    {
        self.scrollOrigin -= event.deltaX / self.bounds.size.width;
        self.scrollOrigin = MAX(self.scrollOrigin, 0);
        //    self.scrollOrigin = MIN(self.scrollOrigin, (self.totalDurationInFrames * self.magnification) - self.bounds.size.width);
        [self recalculateUnits];
    }
}

- (void) updateScrollOrigin:(CGFloat)amount
{
    
}
- (void) recalculateUnits
{
    self.numFrames = ceil(CMTimeGetSeconds(self.duration) / CMTimeGetSeconds(self.frameDuration));
    
    self.zoomRangeMin = 0.0 + self.scrollOrigin;
    self.zoomRangeMax = self.magnification + self.scrollOrigin;;
    
//    self.durationInFrames = self.frameDuration.value * self.duration.value;
//    self.frameTickInPixels = (1.0);
//    self.frameDurationInPixels = (self.frameTickInPixels * self.frameDuration.value );
//    self.totalDurationInPixels = (self.frameTickInPixels * self.duration.value);
//    
//    NSLog(@"m %f ftp %lu, fdp %lu, tdp %lu", self.magnification, (unsigned long)self.frameTickInPixels, (unsigned long)self.frameDurationInPixels, (unsigned long)self.totalDurationInPixels);
    
    [self setNeedsDisplay:YES];
}


- (CGFloat) millisToScreenX:(CGFloat)millis
{
    return [self normalizedXtoScreenX:(millis/(CMTimeGetSeconds(self.duration) * 1000.0))];
}

- (float) normalizedXtoScreenX:(float)x
{
//    return normalizedXtoScreenX(x, getViewRange());
    return map(x, self.zoomRangeMin, self.zoomRangeMax, self.bounds.origin.x, self.bounds.size.width, false);
}

//float normalizedXtoScreenX(float x, ofRange inputRange){
//    return ofMap(x, inputRange.min, inputRange.max, getDrawRect().getMinX(), getDrawRect().getMaxX(), false);
//}


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
        
        // Draw Frames
        for(int i = 0; i < self.numFrames; i++)
        {
//            CGFloat frame = i
            float screenX = [self millisToScreenX:(i * CMTimeGetSeconds(self.frameDuration) * 1000.0)];
            if(screenX > clippedDirtyRect.origin.x && screenX < clippedDirtyRect.size.width)
            {
                [[NSColor lightGrayColor] setFill];
                [[NSColor lightGrayColor] setStroke];

                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.9);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
            }
        }
        
        for(int i = 0; i < floor(CMTimeGetSeconds(self.duration)); i++)
        {
            float screenX = [self millisToScreenX:(i * 1000.0)];
            if(screenX > clippedDirtyRect.origin.x && screenX < clippedDirtyRect.size.width)
            {
                [[NSColor yellowColor] setFill];
                [[NSColor yellowColor] setStroke];
                
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.8);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
            }
        }
        
        for(int i = 0; i < floor(CMTimeGetSeconds(self.duration)/60.0); i++)
        {
            float screenX = [self millisToScreenX:(i * 1000.0 * 60)];
            if(screenX > clippedDirtyRect.origin.x && screenX < clippedDirtyRect.size.width)
            {
                [[NSColor orangeColor] setFill];
                [[NSColor orangeColor] setStroke];
                
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.7);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
            }
        }

        
    }
}
@end
