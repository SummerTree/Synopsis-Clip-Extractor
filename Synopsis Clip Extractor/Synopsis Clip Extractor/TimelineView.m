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
    self.duration = CMTimeMakeWithSeconds(60 * 120, 600);
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
    
    NSLog(@"magnification: %f", self.magnification );
    
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
    
    CGFloat frameDurationInMS = CMTimeGetSeconds(self.frameDuration) * 1000.0;
    NSUInteger numSeconds = floor(CMTimeGetSeconds(self.duration));
    NSUInteger numMinutes = floor(numSeconds/60.0);
    NSUInteger numHours = floor(numMinutes/60.0);

    // Unit calculations
    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];
        
        NSLog(@"Drawing Rect: %@", NSStringFromRect(clippedDirtyRect));
        
        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);
        
        // Draw Frames
        if(self.magnification < 0.07)
        {
            for(int i = 0; i < self.numFrames; i++)
            {
                float screenX = [self millisToScreenX:(i * frameDurationInMS)];
                if([self coord:screenX inRect:clippedDirtyRect])
                {
                    [[NSColor lightGrayColor] setFill];
                    [[NSColor lightGrayColor] setStroke];

                    CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                    CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.9);
                    
                    [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                    if(self.magnification < 0.07/15.0)
                        [self drawLabel:i atPoint:bottom inContext:context];
                }
            }
        }
        
        if(self.magnification < 0.5)
        {
            for(int i = 0; i < numSeconds; i++)
            {
                float screenX = [self millisToScreenX:(i * 1000.0)];
                if([self coord:screenX inRect:clippedDirtyRect])
                {
                    [[NSColor yellowColor] setFill];
                    [[NSColor yellowColor] setStroke];
                    
                    CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                    CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.7);
                    
                    [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                    if(self.magnification < 0.15)
                        [self drawLabel:i atPoint:bottom inContext:context];
                }
            }
        }
        // Minutes
        for(int i = 0; i < numMinutes; i++)
        {
            float screenX = [self millisToScreenX:(i * 1000.0 * 60)];
            if([self coord:screenX inRect:clippedDirtyRect])
            {
                [[NSColor orangeColor] setFill];
                [[NSColor orangeColor] setStroke];
                
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.5);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                [self drawLabel:i atPoint:bottom inContext:context];
            }
        }
        
        // Hours
        for(int i = 0; i < numHours; i++)
        {
            float screenX = [self millisToScreenX:(i * 1000.0 * 60 * 60)];
            if([self coord:screenX inRect:clippedDirtyRect])
            {
                [[NSColor redColor] setFill];
                [[NSColor redColor] setStroke];
                
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.3);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                [self drawLabel:i atPoint:bottom inContext:context];
            }
        }

    }
}

- (BOOL) coord:(float)screenX inRect:(CGRect)clippedDirtyRect
{
    return (screenX > (clippedDirtyRect.origin.x - FLT_EPSILON) && screenX <= (clippedDirtyRect.size.width + FLT_EPSILON));
}

- (void) drawLabel:(NSUInteger)i atPoint:(CGPoint)point inContext:(CGContextRef) context
{
    CGContextSetLineWidth(context, 2.0);
    CGContextSelectFont(context, "Helvetica", 8, kCGEncodingMacRoman);
    CGContextSetCharacterSpacing(context, 1.7);
    CGContextSetTextDrawingMode(context, kCGTextFill);
    NSString* s = [NSString stringWithFormat:@"%lu", (unsigned long)i ];
    CGContextShowTextAtPoint(context, point.x, point.y -10, [s cStringUsingEncoding:NSASCIIStringEncoding], s.length);

}
@end
