//
//  PlayerView.h
//  Synopsis Clip Extractor
//
//  Created by vade on 1/11/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface PlayerView : NSView
- (void) setCurrentPlayerAsset:(AVURLAsset*)asset;
- (void) setCurrentTime:(CMTime)time;
@end
