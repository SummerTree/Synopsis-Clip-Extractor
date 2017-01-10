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
@property (nonatomic, assign) CGFloat frameTickInPixels;
@property (nonatomic, assign) CGFloat frameDurationInPixels;
@property (nonatomic, assign) CGFloat totalDurationInPixels;

@end

static inline double Mod(double x, double y)
{
    if (0. == y)
        return x;
    
    double m= x - y * floor(x/y);
    
    // handle boundary cases resulted from floating-point cut off:
    
    if (y > 0)              // modulo range: [0..y)
    {
        if (m>=y)           // Mod(-1e-16             , 360.    ): m= 360.
            return 0;
        
        if (m<0 )
        {
            if (y+m == y)
                return 0  ; // just in case...
            else
                return y+m; // Mod(106.81415022205296 , _TWO_PI ): m= -1.421e-14
        }
    }
    else                    // modulo range: (y..0]
    {
        if (m<=y)           // Mod(1e-16              , -360.   ): m= -360.
            return 0;
        
        if (m>0 )
        {
            if (y+m == y)
                return 0  ; // just in case...
            else
                return y+m; // Mod(-106.81415022205296, -_TWO_PI): m= 1.421e-14
        }
    }
    
    return m;
}


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

- (void) drawAtPoint:(CGPoint)x withColor:(NSColor*)color atTickScale:(CGFloat)scale height:(CGFloat)height inContext:(CGContextRef)context maxTickMag:(float)tickMag label:(NSString*)label maxLabelMag:(float)labelMag
{
    if(self.magnification >= tickMag)
    {
        // Draw Frame Boundaries
        [color setStroke];
        [color setFill];
        
//        if( i % scale == 0)
        
        float draw = Mod(x.x, scale);
        
        if( draw/self.magnification <=  FLT_EPSILON)
        {
//            CGPoint x = CGPointMake((CGFloat)i, 0);
//
//            x = CGPointApplyAffineTransform(x, transform);

            if(x.x <= self.totalDurationInPixels)
            {
                NSPoint p1 = NSMakePoint(x.x, self.bounds.size.height);
                NSPoint p2 = NSMakePoint(x.x, self.bounds.size.height * height);
                
                [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
                
//                if(label)
//                    [self drawLabel:[NSString stringWithFormat:label, i/scale] atPoint:p2 atTickScale:scale inContext:context magnification:labelMag];
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
    
//    CGFloat scrollAmount = fmod(self.scrollOrigin, self.bounds.size.width);
    
    CGAffineTransform scrollTransform = CGAffineTransformMakeTranslation(-self.scrollOrigin, 0.0);
    CGAffineTransform invScrollTransform = CGAffineTransformMakeTranslation(-self.scrollOrigin, 0.0);

    CGAffineTransform magTransform = CGAffineTransformMakeScale(self.magnification, 1.0);
    CGAffineTransform invMagTransform = CGAffineTransformMakeScale(1.0/self.magnification, 1.0);

    CGAffineTransform transform = CGAffineTransformConcat(scrollTransform, magTransform );
    CGAffineTransform invTransform = CGAffineTransformConcat(invScrollTransform, invMagTransform);
    
    CGRect totalTimeline = CGRectMake(0, 0, self.totalDurationInPixels, self.bounds.size.height);
    CGRect transformedTimeline = CGRectApplyAffineTransform(totalTimeline, transform);
    CGRect invTransformedTimeline = CGRectApplyAffineTransform(totalTimeline, invMagTransform);
    
    for(NSInteger i = 0; i < count; i++)
    {
        NSRect clippedDirtyRect = rects[i];
        
        // Rect that indicates our scrolled coordinate system in 1:1 coordinates
        CGRect scrolledClippedRect = CGRectApplyAffineTransform(clippedDirtyRect, invTransform);

        // Intersect our 2 rects, giving us a window into our transformed rect that has the correct origin for our virtual scroller
        CGRect windowedClippedRect = CGRectIntersection(scrolledClippedRect, transformedTimeline);
        
        [[NSColor darkGrayColor] setFill];
        CGContextFillRect(context, clippedDirtyRect);
        
//        clippedDirtyRect = (NSRect)CGRectApplyAffineTransform((CGRect)clippedDirtyRect, CGAffineTransformMakeTranslation(scrollAmount, 0));
//        NSLog(@"true bounds %@", NSStringFromRect(self.bounds));
//        NSLog(@"transformedTimeline %@", NSStringFromRect(transformedTimeline));
//        NSLog(@"invtransformedTimeline %@", NSStringFromRect(invTransformedTimeline));
//        NSLog(@"windowedClippedRect %@", NSStringFromRect(windowedClippedRect));

        [[NSColor whiteColor] setFill];
        [[NSColor whiteColor] setStroke];

//        use origin of transformed rect to offset scroll position or something?
        for(CGFloat i = 0; i < clippedDirtyRect.size.width; i+=1.0)
        {
            CGPoint x = CGPointMake(i, 0);
            
            
            // Test Code
            float draw = fmod(i, self.frameDurationInPixels);
            
            if( draw <= FLT_EPSILON)
            {
                CGPoint top = CGPointMake(i, transformedTimeline.size.height);
                
                top = CGPointApplyAffineTransform(top, transform);
//                top.x = Mod(top.x , scrolledClippedRect.size.width );

                CGPoint bottom = CGPointMake(top.x, 0);
                
                [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
            }
            
//            // Draw Tick
//            [self drawAtPoint:x withColor:[NSColor blackColor] atTickScale:scaledFrameTickInPixels.x height:0.9 inContext:context maxTickMag:2.0 label:nil maxLabelMag:0];
//
//            // Draw Frame
//            [self drawAtPoint:x withColor:[NSColor lightGrayColor] atTickScale:scaledFrameDurationInPixels.x height:0.8 inContext:context maxTickMag:0.25 label:@"f %f" maxLabelMag:1.5];
//
//            // Draw Seconds
//            [self drawAtPoint:x withColor:[NSColor yellowColor] atTickScale:scaledSecond.x height:0.7 inContext:context maxTickMag:0.01 label:@"s %f" maxLabelMag:0.05];
//
//            // Draw Minutes
//            [self drawAtPoint:x withColor:[NSColor redColor] atTickScale:scaledMinute.x height:0.6 inContext:context maxTickMag:0 label:@"m %f" maxLabelMag:0.0];
//
//            // Draw Hour
//            [self drawAtPoint:x withColor:[NSColor greenColor] atTickScale:scaledHour.x height:0.5 inContext:context maxTickMag:0 label:@"h %f" maxLabelMag:0.0];
        }
    }
}

@end
