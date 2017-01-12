//
//  TimelineTrackPlayheadLayer.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/12/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "TimelineTrackPlayheadLayer.h"
#import <Quartz/Quartz.h>
#import <Cocoa/Cocoa.h>

@interface TimelineTrackPlayheadLayer ()
@property (nonatomic, strong) CATextLayer* timeLabel;
@end

@implementation TimelineTrackPlayheadLayer

- (id) init
{
    self = [super init];
    if(self)
    {
        NSDictionary* actions = @{@"frame" : [NSNull null], @"position" : [NSNull null], @"frameSize" : [NSNull null], @"frameOrigin" : [NSNull null], @"bounds" : [NSNull null]};
        self.actions = actions;
        self.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        self.backgroundColor = [NSColor whiteColor].CGColor;
        self.masksToBounds = NO;
//        self.shadowOpacity = 0.7;
        
        self.timeLabel = [CATextLayer layer];
        self.timeLabel.string = @"TEST";
        self.timeLabel.wrapped = NO;
        self.timeLabel.truncationMode = kCATruncationNone;
        self.timeLabel.alignmentMode = kCAAlignmentCenter;
        self.timeLabel.bounds = CGRectMake(0, 0, 100, 15.);
        self.timeLabel.anchorPoint = CGPointMake(0.5, 0.5);
        self.timeLabel.fontSize = 12.0;
        self.timeLabel.backgroundColor = [NSColor lightGrayColor].CGColor;
        self.timeLabel.cornerRadius = 3.0;
        self.timeLabel.allowsFontSubpixelQuantization = YES;
        self.timeLabel.foregroundColor = [NSColor blackColor].CGColor;
//        self.timeLabel.shouldRasterize = YES;
        self.timeLabel.contentsScale = [[NSScreen mainScreen] backingScaleFactor];

        [self addSublayer:self.timeLabel];
        
    }
    return self;
}

- (void) setCurrentTimeDisplay:(CMTime)time
{
    self.timeLabel.string = [NSString stringWithFormat:@"%.2f", CMTimeGetSeconds(time)];
}

- (void) layoutSublayers
{
    [super layoutSublayers];
    self.timeLabel.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));

//    self.timeLabel.bounds = CGRectMake(0, 0, 100, 24);
}

@end
