//
//  TimelineView.h
//  Synopsis Clip Extractor
//
//  Created by vade on 1/7/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>

@interface TimelineView : NSView
- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration;

@end
