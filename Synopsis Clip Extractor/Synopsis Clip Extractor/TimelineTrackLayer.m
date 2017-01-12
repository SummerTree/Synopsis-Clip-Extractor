//
//  TimelineTrackLayer.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/12/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "TimelineTrackLayer.h"

@interface TimelineTrackLayer ()
@property (nonatomic, strong) CALayer* tickLayer;
@end

@implementation TimelineTrackLayer

- (id) init
{
    self = [super init];
    if(self)
    {
        NSDictionary* actions = @{@"frame" : [NSNull null], @"position" : [NSNull null], @"frameSize" : [NSNull null], @"frameOrigin" : [NSNull null], @"bounds" : [NSNull null]};
        self.actions = actions;
        self.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;// | kCALayerMinXMargin | kCALayerMaxXMargin | kCALayerMinYMargin | kCALayerMaxYMargin;
        self.instanceDelay = 0;
        self.contentsScale = [[NSScreen mainScreen] backingScaleFactor];

//        self.shouldRasterize = YES;
        
        self.magnification = 1.0;
        self.tickHeight = 20;
        self.scrollOffset = 0.0;
        
        self.tickLayer = [CALayer layer];
        self.tickLayer.actions = actions;
        self.tickLayer.backgroundColor = [NSColor whiteColor].CGColor;
        self.tickLayer.bounds = CGRectMake(10, 1, 1, self.tickHeight);
        self.tickLayer.anchorPoint = CGPointMake(0.5, 1);
        self.tickLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMaxY(self.bounds));
        self.tickLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
      
        [self addSublayer:self.tickLayer];
    }
    return self;
}


- (void) recalculate
{
    self.tickLayer.position = CGPointMake(0.0, CGRectGetMaxY(self.bounds));
    self.tickLayer.bounds = CGRectMake(10, 1, 1, self.tickHeight);

    self.instanceCount = ceil(CMTimeGetSeconds(self.totalDuration) / CMTimeGetSeconds(self.tickInterval));

    [self intervalOffset: (self.bounds.size.width / (CGFloat) self.instanceCount) * 1.0/self.magnification ];
    
    [self setNeedsDisplay];
//    [self intervalOffset:10];
    
}

- (void) intervalOffset:(CGFloat)offset
{
    self.instanceTransform = CATransform3DMakeTranslation(offset, 0, 0);
}



@end
