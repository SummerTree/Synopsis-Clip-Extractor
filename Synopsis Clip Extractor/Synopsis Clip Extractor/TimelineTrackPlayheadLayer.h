//
//  TimelineTrackPlayheadLayer.h
//  Synopsis Clip Extractor
//
//  Created by vade on 1/12/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>

@interface TimelineTrackPlayheadLayer : CALayer
- (void) setCurrentTimeDisplay:(CMTime)time;
@end
