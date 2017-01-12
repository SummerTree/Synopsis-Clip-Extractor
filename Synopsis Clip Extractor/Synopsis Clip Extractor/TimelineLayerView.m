//
//  TimelineView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/7/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "TimelineLayerView.h"
#import <AVFoundation/AVFoundation.h>
#import "TimelineTrackLayer.h"
#import "TimelineTrackPlayheadLayer.h"

@interface TimelineLayerView()
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) NSUInteger numFrames;

@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) CGFloat magnification;

@property (nonatomic, assign) CGFloat zoomRangeMin;
@property (nonatomic, assign) CGFloat zoomRangeMax;

@property (nonatomic, assign) CGPoint currentMousePosition;

// Layer
@property (nonatomic, strong) CAScrollLayer* scrollLayer;
@property (nonatomic, strong) TimelineTrackPlayheadLayer* playheadLayer;
@property (nonatomic, strong) NSArray<TimelineTrackLayer*>* timeTracks;
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


@implementation TimelineLayerView

- (BOOL) wantsLayer
{
    return YES;
}

- (BOOL) wantsUpdateLayer
{
    return YES;
}

- (void) awakeFromNib
{
    self.layer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
    
    NSDictionary* actions = @{@"frame" : [NSNull null], @"position" : [NSNull null], @"frameSize" : [NSNull null], @"frameOrigin" : [NSNull null], @"bounds" : [NSNull null]};
    
    self.playheadLayer = [TimelineTrackPlayheadLayer layer];
    self.playheadLayer.bounds = CGRectMake(0, 0, 1, self.bounds.size.height);
    
    self.scrollLayer = [CAScrollLayer layer];
    self.scrollLayer.scrollMode = kCAScrollHorizontally;
    self.scrollLayer.frame = self.bounds;
    self.scrollLayer.actions = actions;
    self.scrollLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;
    
    TimelineTrackLayer* secondsLayer = [TimelineTrackLayer layer];
    secondsLayer.instanceColor = [NSColor yellowColor].CGColor;
    secondsLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    secondsLayer.tickInterval = CMTimeMakeWithSeconds(1, 600);
    secondsLayer.tickHeight = 15;
    
    TimelineTrackLayer* minutesLayer = [TimelineTrackLayer layer];
    minutesLayer.instanceColor = [NSColor orangeColor].CGColor;
    minutesLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    minutesLayer.tickInterval = CMTimeMakeWithSeconds(60, 600);
    minutesLayer.tickHeight = 30;
    
    TimelineTrackLayer* hoursLayer = [TimelineTrackLayer layer];
    hoursLayer.instanceColor = [NSColor redColor].CGColor;
    hoursLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    hoursLayer.tickInterval = CMTimeMakeWithSeconds(60 * 60, 600);
    hoursLayer.tickHeight = 45;
    
    
    self.duration = CMTimeMakeWithSeconds(60 * 120, 600);
    self.frameDuration = CMTimeMake(1,30);
    self.magnification = 1.0;
    
    self.zoomRangeMax = 1.0;//self.bounds.size.width;
    self.zoomRangeMin = 0.0;
    
    [self recalculateUnits];
    
    self.timeTracks = @[secondsLayer,minutesLayer, hoursLayer,];
    
    [self.scrollLayer addSublayer:secondsLayer];
    [self.scrollLayer insertSublayer:minutesLayer above:secondsLayer];
    [self.scrollLayer insertSublayer:hoursLayer above:minutesLayer];
    
    [self.layer addSublayer:self.scrollLayer];
    [self.layer insertSublayer:self.playheadLayer above:self.scrollLayer];
    
    self.layer.backgroundColor = [NSColor darkGrayColor].CGColor;
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
        self.scrollOrigin -= event.deltaX;// / self.bounds.size.width;
        //        self.scrollOrigin = MAX(self.scrollOrigin, 0);
        //    self.scrollOrigin = MIN(self.scrollOrigin, (self.totalDurationInFrames * self.magnification) - self.bounds.size.width);
        [self recalculateUnits];
    }
}

- (void) mouseMoved:(NSEvent *)event
{
    CGPoint locationInView = [self convertPoint:[event locationInWindow] fromView:nil];
    
    self.currentMousePosition = locationInView;
    
    CMTime currentTimelineTime = CMTimeMultiplyByFloat64(self.duration, [self timelineViewToMillis:locationInView.x]);
    
    CGFloat verticalCenter = self.bounds.size.height * 0.5;
    self.playheadLayer.position = CGPointMake(self.currentMousePosition.x, verticalCenter);
    [self.playheadLayer setCurrentTimeDisplay:currentTimelineTime];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlayerTime" object:self userInfo:@{@"timelineTime" : [NSValue valueWithCMTime:currentTimelineTime]} ];
}

- (void) recalculateUnits
{
    self.numFrames = ceil(CMTimeGetSeconds(self.duration) / CMTimeGetSeconds(self.frameDuration));
    
    self.zoomRangeMin = 0.0 + self.scrollOrigin;
    self.zoomRangeMax = self.magnification + self.scrollOrigin;;
    
    
    [self setNeedsDisplay:YES];
    [self updateLayer];
}


- (CGFloat) timelineViewToMillis:(float)x
{
    return map(x, self.bounds.origin.x, self.bounds.size.width, self.zoomRangeMin, self.zoomRangeMax, false);
}

- (CGFloat) frameDurationToTimelineView
{
    CGFloat duration = (CMTimeGetSeconds(self.frameDuration) * 1000.0)/(CMTimeGetSeconds(self.duration) * 1000.0);
    return map(duration, 0, self.magnification, 0.0, self.bounds.size.width, false);
}

- (void) updateLayer
{
    CGFloat verticalCenter = self.bounds.size.height * 0.5;
    CGFloat horizontalCenter = self.bounds.size.width * 0.5;
    self.playheadLayer.bounds = CGRectMake(0, 0, 1, self.bounds.size.height);
    self.playheadLayer.position = CGPointMake(self.currentMousePosition.x, verticalCenter);
    
    for(TimelineTrackLayer* track in self.timeTracks)
    {
        //        track.bounds = CGRectMake(0, verticalCenter, self.bounds.size.width, self.bounds.size.height);
        //        track.position = CGPointMake(horizontalCenter, verticalCenter);
        track.totalDuration = self.duration;
        track.magnification = self.magnification;
        //        track.scrollOffset = self.scrollOrigin;
        [track recalculate];
    }
    
    //    self.scrollLayer.frame = self.bounds;
    [self.scrollLayer scrollToPoint:CGPointMake(self.scrollOrigin, 0)];
    
    //    NSLog(@"scroll: %f", self.scrollOrigin);
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
