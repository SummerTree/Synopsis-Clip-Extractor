//
//  PlayerView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/11/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "PlayerView.h"

@interface PlayerView ()
@property (strong) AVURLAsset* playerAsset;
@property (strong) AVPlayerItem* playerItem;
@property (strong) AVPlayer* player;
@property (strong) AVPlayerLayer* playerLayer;
@end

@implementation PlayerView


- (instancetype) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        [self commonInit];
    }
    return self;
}

- (void) awakeFromNib
{
    [self commonInit];
}

- (void) commonInit
{
    self.wantsLayer = YES;
    
    self.layer.backgroundColor = [NSColor blackColor].CGColor;
    
    self.player = [[AVPlayer alloc] init];
    self.playerLayer = [[AVPlayerLayer alloc] init];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    self.playerLayer.frame = self.layer.bounds;
    self.playerLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    
    [self.layer addSublayer:self.playerLayer];
}

- (void) setCurrentTime:(CMTime)time
{
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void) setCurrentPlayerAsset:(AVURLAsset *)asset
{
    self.playerAsset = asset;

    self.playerItem = [AVPlayerItem playerItemWithAsset:self.playerAsset];
    
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    self.playerLayer.player = self.player;
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void) updateLayer
{
    self.playerLayer.frame = self.layer.bounds;
}

@end
