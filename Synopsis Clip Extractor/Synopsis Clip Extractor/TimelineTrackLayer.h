//
//  TimelineTrackLayer.h
//  Synopsis Clip Extractor
//
//  Created by vade on 1/12/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>

@interface TimelineTrackLayer : CAReplicatorLayer

@property (nonatomic, assign) CMTime tickInterval;
@property (nonatomic, assign) CMTime totalDuration;
@property (nonatomic, assign) CGFloat tickHeight;
@property (nonatomic, assign) CGFloat magnification;
@property (nonatomic, assign) CGFloat scrollOffset;
- (void) recalculate;

@end
