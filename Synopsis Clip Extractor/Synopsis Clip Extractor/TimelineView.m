//
//  TimelineView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/7/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "TimelineView.h"
#import <AVFoundation/AVFoundation.h>

@interface TimelineView()
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) NSUInteger numFrames;

@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) CGFloat magnification;

@property (nonatomic, assign) CGFloat zoomRangeMin;
@property (nonatomic, assign) CGFloat zoomRangeMax;

@property (nonatomic, assign) CGPoint currentMousePosition;
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
        
        [self recalculateUnits];
    }
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) magnifyWithEvent:(NSEvent *)event
{
    self.magnification -= event.magnification;
    self.magnification = MAX(0.001, self.magnification);
    self.magnification = MIN(1, self.magnification);
    
    NSLog(@"magnification: %f", self.magnification );
    
    [self recalculateUnits];
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

- (void) mouseMoved:(NSEvent *)event
{
    CGPoint locationInView = [self convertPoint:[event locationInWindow] fromView:nil];
    
    self.currentMousePosition = locationInView;
    
    CMTime currentTimelineTime = CMTimeMultiplyByFloat64(self.duration, [self timelineViewToMillis:locationInView.x]);

    [self recalculateUnits];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlayerTime" object:self userInfo:@{@"timelineTime" : [NSValue valueWithCMTime:currentTimelineTime]} ];
}

- (void) recalculateUnits
{
    self.numFrames = ceil(CMTimeGetSeconds(self.duration) / CMTimeGetSeconds(self.frameDuration));
    
    self.zoomRangeMin = 0.0 + self.scrollOrigin;
    self.zoomRangeMax = self.magnification + self.scrollOrigin;;
    
    [self setNeedsDisplay:YES];
}

- (CGFloat) millisToTimelineView:(CGFloat)millis
{
    return [self normalizedXtoScreenX:(millis/(CMTimeGetSeconds(self.duration) * 1000.0))];
}

- (CGFloat) timelineViewToMillis:(CGFloat)millis
{
    CGFloat timeline = [self screenXToNormalizedX:millis];
    return  timeline;
}

- (CGFloat) normalizedXtoScreenX:(float)x
{
    return map(x, self.zoomRangeMin, self.zoomRangeMax, self.bounds.origin.x, self.bounds.size.width, false);
}

- (CGFloat) screenXToNormalizedX:(float)x
{
    return map(x, self.bounds.origin.x, self.bounds.size.width, self.zoomRangeMin, self.zoomRangeMax, false);
}

- (CGFloat) frameDurationToTimelineView
{
    CGFloat duration = (CMTimeGetSeconds(self.frameDuration) * 1000.0)/(CMTimeGetSeconds(self.duration) * 1000.0);
    return map(duration, 0, self.magnification, 0.0, self.bounds.size.width, false);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self updateTrackingAreas];

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
        
        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);
        
        // Draw Frames
        [[NSColor grayColor] setFill];
        [[NSColor grayColor] setStroke];
        if(self.magnification < 0.07)
        {
            for(int i = 0; i < self.numFrames; i++)
            {
                float screenX = [self millisToTimelineView:(i * frameDurationInMS)];
                if([self coord:screenX duration:0 inRect:clippedDirtyRect])
                {
                    CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                    CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.95);
                    
                    [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                    if(self.magnification < 0.07/15.0)
                        [self drawLabel:i atPoint:bottom inContext:context];
                }
            }
        }
        
        [[NSColor yellowColor] setFill];
        [[NSColor yellowColor] setStroke];
        if(self.magnification < 0.5)
        {
            for(int i = 0; i < numSeconds; i++)
            {
                float screenX = [self millisToTimelineView:(i * 1000.0)];
                if([self coord:screenX duration:0 inRect:clippedDirtyRect])
                {
                    CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                    CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.9);
                    
                    [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                    if(self.magnification < 0.15)
                        [self drawLabel:i atPoint:bottom inContext:context];
                }
            }
        }
        // Minutes
        [[NSColor orangeColor] setFill];
        [[NSColor orangeColor] setStroke];
        for(int i = 0; i < numMinutes; i++)
        {
            float screenX = [self millisToTimelineView:(i * 1000.0 * 60)];
            if([self coord:screenX duration:0 inRect:clippedDirtyRect])
            {
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.85);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                [self drawLabel:i atPoint:bottom inContext:context];
            }
        }
        
        // Hours
        [[NSColor redColor] setFill];
        [[NSColor redColor] setStroke];
        for(int i = 0; i < numHours; i++)
        {
            float screenX = [self millisToTimelineView:(i * 1000.0 * 60 * 60)];
            if([self coord:screenX duration:0 inRect:clippedDirtyRect])
            {
                CGPoint top = CGPointMake(screenX, clippedDirtyRect.size.height);
                CGPoint bottom = CGPointMake(top.x, clippedDirtyRect.size.height * 0.8);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
                [self drawLabel:i atPoint:bottom inContext:context];
            }
        }


        CGFloat frameDuration = [self frameDurationToTimelineView];
        for(int i = 0; i < self.interestingTimeRangesArray.count; i++)
        {
            CMTimeRange currentRange = [(NSValue*)self.interestingTimeRangesArray[i] CMTimeRangeValue];
            
            float screenX = [self millisToTimelineView:((1000.0 * CMTimeGetSeconds(currentRange.start)) )];
            
            if([self coord:screenX duration:frameDuration inRect:clippedDirtyRect])
            {
                NSArray* infoTracks = self.interestingPointsArray[i];
                NSUInteger trackCount = infoTracks.count;
                
                CGFloat currentHue = 0;
                CGFloat hueSlice = 1.0 / trackCount;

                NSUInteger currentTrack = 0;
                CGFloat trackHeight =  clippedDirtyRect.size.height;
                trackHeight /= (CGFloat)trackCount;
                
                for(NSNumber* trackValue in infoTracks)
                {
                    NSColor* trackColor = [NSColor colorWithHue:currentHue saturation:0.5 brightness:1.0 alpha:1];

                    [trackColor setFill];

                    CGPoint top = CGPointMake(screenX,  (trackHeight * currentTrack) );//+ [trackValue floatValue] + 10);
                    CGPoint bottom = CGPointMake(top.x, (trackHeight * currentTrack) - (trackHeight * [trackValue floatValue]) ) ;
                    
                    NSRect r = NSMakeRect(top.x, top.y, frameDuration, top.y - bottom.y);
                    
                    NSRectFill(r);
                    
                    currentHue += hueSlice;
                    currentTrack++;
                }
            }
        }

        // Draw current time line
        [[NSColor whiteColor] setFill];
        [[NSColor whiteColor] setStroke];
        CGPoint top = CGPointMake(self.currentMousePosition.x,  self.bounds.size.height);
        CGPoint bottom = CGPointMake(self.currentMousePosition.x,  0);;
        [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
    }
}

- (BOOL) coord:(float)screenX duration:(CGFloat)duration inRect:(CGRect)clippedDirtyRect
{
    return ((screenX + duration + FLT_EPSILON) >= (clippedDirtyRect.origin.x) && (screenX - duration - FLT_EPSILON) <= (clippedDirtyRect.size.width));
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


-(void)updateTrackingAreas
{
    for(NSTrackingArea* trackingArea in self.trackingAreas)
    {
        [self removeTrackingArea:trackingArea];
    }
    
    int opts = (NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingAssumeInside | NSTrackingInVisibleRect);
    NSTrackingArea* trackingArea = [ [NSTrackingArea alloc] initWithRect:[self bounds]
                                                                 options:opts
                                                                   owner:self
                                                                userInfo:nil];
    [self addTrackingArea:trackingArea];
}

@end
