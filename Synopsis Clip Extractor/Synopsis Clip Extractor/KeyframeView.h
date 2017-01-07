//
//  KeyframeView.h
//  Synopsis Clip Extractor
//
//  Created by vade on 1/4/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CoreMedia.h>

@interface KeyframeView : NSView

- (void) setFrameFromDuration:(CMTime)duration andFrameDuration:(CMTime)frameDuration;

@property (copy) NSArray* editPoints;

@end
