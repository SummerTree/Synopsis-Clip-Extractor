//
//  KeyframeView.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/4/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "KeyframeView.h"

@interface KeyframeView ()

@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CGFloat magnification;

// Scaled units
@property (nonatomic, assign) NSUInteger frameTickInPixels;
@property (nonatomic, assign) NSUInteger frameDurationInPixels;
@property (nonatomic, assign) NSUInteger totalDurationInPixels;

@end

@implementation KeyframeView

- (void) awakeFromNib
{
    self.duration = CMTimeMakeWithSeconds(5, 600);
    self.frameDuration = CMTimeMake(30,1);
    self.magnification = 1.0;
    
    [self recalculateUnits];
}

- (void) updateScrollOrigin:(CGFloat)amount
{
    self.scrollOrigin -= amount;
    self.scrollOrigin = MAX(self.scrollOrigin, 0);
    self.scrollOrigin = MIN(self.scrollOrigin, (self.totalDurationInPixels * self.magnification) - self.bounds.size.width);
    [self setNeedsDisplay:YES];

}

- (void) magnifyWithEvent:(NSEvent *)event
{
    self.magnification += event.magnification;
    self.magnification = MAX(0.001, self.magnification);
    self.magnification = MIN(10, self.magnification);
    
//    NSPoint pointInView = [self convertPoint:event.locationInWindow fromView:nil];
//    NSLog(@"pointInView: %f", pointInView.x );
//    [self updateScrollOrigin: ( -pointInView.x )];
    
    [self recalculateUnits];
    
//    NSSize scale = NSMakeSize(self.scale.width + event.magnification, 1.0);
//    [self setScale:scale];
}

- (void) scrollWheel:(NSEvent *)event
{
    if(self.bounds.size.width < self.totalDurationInPixels)
    {
        [self updateScrollOrigin:event.deltaX];
    }
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

const double factor = 10.0;
- (void) recalculateUnits
{
    self.frameTickInPixels = (1.0);
    self.frameDurationInPixels = (self.frameTickInPixels * self.frameDuration.value );
    self.totalDurationInPixels = (self.frameTickInPixels * self.duration.value);
    
    NSLog(@"m %f ftp %lu, fdp %lu, tdp %lu", self.magnification, (unsigned long)self.frameTickInPixels, (unsigned long)self.frameDurationInPixels, (unsigned long)self.totalDurationInPixels);

    [self setNeedsDisplay:YES];
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) drawLabel:(NSString*)l atPoint:(CGPoint)p1 atTickScale:(CGFloat)scale inContext:(CGContextRef)context magnification:(float)mag
{
    if(self.magnification >= mag)
    {
//        NSString* label = [NSString stringWithFormat:l, (int)round(p1.x /scale) ];
        
        CGContextSetLineWidth(context, 2.0);
        CGContextSelectFont(context, "Helvetica", 8, kCGEncodingMacRoman);
        CGContextSetCharacterSpacing(context, 1.7);
        CGContextSetTextDrawingMode(context, kCGTextFill);
        CGContextShowTextAtPoint(context, p1.x, p1.y -10, [l cStringUsingEncoding:NSASCIIStringEncoding], l.length);
    }
}

- (void) drawTickNumber:(NSUInteger)i withTransform:(CGAffineTransform)transform withColor:(NSColor*)color atTickScale:(NSUInteger)scale height:(CGFloat)height inContext:(CGContextRef)context maxTickMag:(float)tickMag label:(NSString*)label maxLabelMag:(float)labelMag
{
    if(self.magnification >= tickMag)
    {
        // Draw Frame Boundaries
        [color setStroke];
        [color setFill];
        if( i % scale == 0)
        {
            CGPoint x = CGPointMake(i, 0);

            x = CGPointApplyAffineTransform(x, transform);

//            CGFloat x = i - fmod(self.scrollOrigin, scale);            
//            if(x.x <= self.totalDurationInPixels)
            {
                NSPoint p1 = NSMakePoint(x.x, self.bounds.size.height);
                NSPoint p2 = NSMakePoint(x.x, self.bounds.size.height * height);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
                
                if(label)
                    [self drawLabel:[NSString stringWithFormat:label, i/scale] atPoint:p2 atTickScale:scale inContext:context magnification:labelMag];
            }
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    const NSRect *rects;
    NSInteger count;

    [self getRectsBeingDrawn:&rects count:&count];
    
    // Unit calculations
    NSUInteger second = (self.frameDurationInPixels * self.frameDuration.value );
    NSUInteger minute = (second * 60);
    NSUInteger hour = (minute * 60);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    transform = CGAffineTransformTranslate(transform, -self.scrollOrigin, 0.0);
    transform = CGAffineTransformScale(transform, self.magnification, 1.0);
    
    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];

        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);
        
        NSRect transformedDirtyRect = (NSRect)CGRectApplyAffineTransform((CGRect)clippedDirtyRect, transform);
        
        NSLog(@"transformedDirtyRect %@", NSStringFromRect(transformedDirtyRect));
        
        for(NSUInteger i = 0; i < clippedDirtyRect.size.width; i ++)
        {
            // Draw Tick
            [self drawTickNumber:i withTransform:transform withColor:[NSColor blackColor] atTickScale:self.frameTickInPixels height:0.9 inContext:context maxTickMag:2.0 label:nil maxLabelMag:0];

            // Draw Frame
            [self drawTickNumber:i withTransform:transform  withColor:[NSColor lightGrayColor] atTickScale:self.frameDurationInPixels height:0.8 inContext:context maxTickMag:0.25 label:@"f %i" maxLabelMag:1.5];

            // Draw Seconds
            [self drawTickNumber:i withTransform:transform  withColor:[NSColor yellowColor] atTickScale:second height:0.7 inContext:context maxTickMag:0.01 label:@"s %i" maxLabelMag:0.05];

            // Draw Minutes
            [self drawTickNumber:i withTransform:transform  withColor:[NSColor redColor] atTickScale:minute height:0.6 inContext:context maxTickMag:0 label:@"m %i" maxLabelMag:0.0];

            // Draw Hour
            [self drawTickNumber:i withTransform:transform  withColor:[NSColor greenColor] atTickScale:hour height:0.5 inContext:context maxTickMag:0 label:@"h %i" maxLabelMag:0.0];
        }
    }
}

@end
