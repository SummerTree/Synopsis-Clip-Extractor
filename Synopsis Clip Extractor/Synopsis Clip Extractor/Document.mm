//
//  Document.m
//  Synopsis Clip Extractor
//
//  Created by vade on 1/4/17.
//  Copyright © 2017 Synopsis. All rights reserved.
//

#import "Document.h"
#import <AVFoundation/AVFoundation.h>
#import <Synopsis/Synopsis.h>
#import "KeyframeView.h"
#import "TimelineView.h"
#import "PlayerView.h"

@interface Document ()
{
}

@property (weak) IBOutlet PlayerView* playerView;
@property (weak) IBOutlet TimelineView* timelineView;

@property (strong) AVURLAsset* clipAsset;
@property (strong) AVAssetReader* clipAssetReader;
@property (strong) AVAssetReaderTrackOutput* clipAssetReaderTrackOutput;
@property (strong) AVAssetReaderOutputMetadataAdaptor* clipAssetReaderMetadataAdaptor;
@property (strong) SynopsisMetadataDecoder* metadataDecoder;

@property (strong) NSOperationQueue* backgroundReadQueue;
@property (strong) NSOperationQueue* backgroundJSONParseQueue;
@property (strong) NSOperationQueue* backgroundCalculateQueue;

@property (strong) NSMutableArray<NSArray<NSNumber*>*>* derivedMetadataInfo;
@property (strong) NSMutableArray<NSValue*>* derivedMetadataTimeRanges;
@property (strong) NSMutableArray<NSNumber*>* derivedMetadataBestGuessEditTimes;

// For Delta / Dervitative calculations
@property (strong) SynopsisDenseFeature* lastFeatureVector;
@property (strong) SynopsisDenseFeature* lastHistogram;
@property (strong) NSString* lastHash;

@property (assign) float lastComparedFeatures;
@property (assign) float lastComparedHistograms;
@property (assign) float lastcomparedHash;

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
        
        self.backgroundReadQueue = [[NSOperationQueue alloc] init];
        self.backgroundReadQueue.maxConcurrentOperationCount = 1;
        self.backgroundReadQueue.qualityOfService = NSQualityOfServiceUserInteractive;

        self.backgroundJSONParseQueue = [[NSOperationQueue alloc] init];
        self.backgroundJSONParseQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        self.backgroundJSONParseQueue.qualityOfService = NSQualityOfServiceUserInteractive;

        self.backgroundCalculateQueue = [[NSOperationQueue alloc] init];
        self.backgroundCalculateQueue.maxConcurrentOperationCount = 1;
        self.backgroundCalculateQueue.qualityOfService = NSQualityOfServiceUserInteractive;

        self.derivedMetadataTimeRanges = [NSMutableArray new];
        self.derivedMetadataInfo = [NSMutableArray new];
    }
    return self;
}

- (void) dealloc
{
//    CFRelease(compressedMetadataQueue);
//    CFRelease(jsonMetadataQueue);
}

+ (BOOL)autosavesInPlace {
    return YES;
}


- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
//    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return nil;
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
//    [NSException raise:@"UnimplementedMethod" format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return YES;
}

- (nullable instancetype)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    self = [super initWithContentsOfURL:url ofType:typeName error:outError];
    if(self)
    {
        self.clipAsset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES} ];
        
        self.clipAssetReader = [AVAssetReader assetReaderWithAsset:self.clipAsset error:nil];
        
        self.metadataDecoder = [[SynopsisMetadataDecoder alloc] initWithVersion:SYNOPSIS_VERSION_NUMBER];
    }

    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;
{
    [super windowControllerDidLoadNib:windowController];
    
    AVAssetTrack* videoAssetTrack = [self.clipAsset tracksWithMediaType:AVMediaTypeVideo][0];
    AVAssetTrack* metadataAssetTrack = [self.clipAsset tracksWithMediaType:AVMediaTypeMetadata][0];
    
    CMTime duration = metadataAssetTrack.timeRange.duration;
    CMTime frameDuration = metadataAssetTrack.minFrameDuration;
    
    [self.timelineView setFrameFromDuration:duration andFrameDuration:frameDuration];
    [self.playerView setCurrentPlayerAsset:self.clipAsset];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"PlayerTime" object:self.timelineView queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note)
    {
        CMTime currentTime = [[note.userInfo objectForKey:@"timelineTime"] CMTimeValue];
        [self.playerView setCurrentTime:currentTime];
    }];
    
    if(metadataAssetTrack)
    {
        self.clipAssetReaderTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:metadataAssetTrack outputSettings:nil];
        self.clipAssetReaderTrackOutput.alwaysCopiesSampleData = NO;
        
        self.clipAssetReaderMetadataAdaptor = [AVAssetReaderOutputMetadataAdaptor assetReaderOutputMetadataAdaptorWithAssetReaderTrackOutput:self.clipAssetReaderTrackOutput];
        
        if([self.clipAssetReader canAddOutput:self.clipAssetReaderTrackOutput])
        {
            [self.clipAssetReader addOutput:self.clipAssetReaderTrackOutput];
        }
        
        [self.clipAssetReaderTrackOutput markConfigurationAsFinal];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @autoreleasepool {
                [self readOnBackgroundQueue];
            }
        });
    }

}

- (void) readOnBackgroundQueue
{
    id activityObject = [NSProcessInfo.processInfo beginActivityWithOptions:NSActivityUserInitiated | NSActivityLatencyCritical | NSActivityIdleSystemSleepDisabled reason:@"Process Metadata"];
  
    [self.clipAssetReader startReading];
    
    __weak typeof (self) weakSelf = self;
    
    dispatch_group_t pipelineGroup = dispatch_group_create();
    
    // Read Thread
    dispatch_group_enter(pipelineGroup);
    
    NSBlockOperation* readOperation = [[NSBlockOperation alloc] init];
    readOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
    
    [readOperation addExecutionBlock:^{
        
        while(weakSelf.clipAssetReader.status == AVAssetReaderStatusReading )
        {
            @autoreleasepool
            {
                AVTimedMetadataGroup* timedMetadata = [weakSelf.clipAssetReaderMetadataAdaptor nextTimedMetadataGroup];
                if(timedMetadata)
                {
                    for(AVMetadataItem* metadataItem in timedMetadata.items)
                    {
                        NSString* key = metadataItem.identifier;
                        
                        if([key isEqualToString:kSynopsislMetadataIdentifier])
                        {
                            NSData* data = (NSData*)metadataItem.value;
                            
                            NSValue* timeRangeValue = [NSValue valueWithCMTimeRange:(timedMetadata.timeRange)];
 
                            NSBlockOperation* jsonParseOperation = [[NSBlockOperation alloc] init];
                            jsonParseOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
                            [jsonParseOperation addExecutionBlock:^{

                                NSDictionary* frameMetadata = [weakSelf.metadataDecoder decodeSynopsisData:data];
                                if(frameMetadata)
                                {
                                    NSBlockOperation* calculateOperation = [[NSBlockOperation alloc] init];
                                    calculateOperation.queuePriority = NSOperationQueuePriorityVeryHigh;

                                    [calculateOperation addExecutionBlock:^{
                                        [weakSelf calculateFromMetadata:frameMetadata timeRangeValue:timeRangeValue];
                                    }];

                                    if(lastJSONReadOperation)
                                    {
                                        [calculateOperation addDependency:lastJSONReadOperation];
                                    }

                                    [weakSelf.backgroundCalculateQueue addOperation:calculateOperation];
                                }
                                
                            }];

                            [weakSelf.backgroundJSONParseQueue addOperation:jsonParseOperation];
                        }
                    }
                }
                else
                {
                    break;
                }
            }
        }
    }];

    [weakSelf.backgroundReadQueue addOperation:readOperation];
    
    [self.backgroundReadQueue waitUntilAllOperationsAreFinished];
    [self.backgroundJSONParseQueue waitUntilAllOperationsAreFinished];
    [self.backgroundCalculateQueue waitUntilAllOperationsAreFinished];

    NSLog(@"Finished");
    
    self.timelineView.interestingTimeRangesArray = self.derivedMetadataTimeRanges;
    self.timelineView.interestingPointsArray = self.derivedMetadataInfo;
    
    [NSProcessInfo.processInfo endActivity:activityObject];
    
}

- (void) calculateFromMetadata:(NSDictionary*)frameMetadata timeRangeValue:(NSValue*)timeRange
{
    [self.derivedMetadataTimeRanges addObject:timeRange];
        
    NSDictionary* standard = [frameMetadata objectForKey:kSynopsisStandardMetadataDictKey];
    SynopsisDenseFeature* featureVector = [standard objectForKey:kSynopsisStandardMetadataFeatureVectorDictKey];
    SynopsisDenseFeature* histogram = [standard objectForKey:kSynopsisStandardMetadataHistogramDictKey];
    NSString* hash = [standard objectForKey:kSynopsisStandardMetadataPerceptualHashDictKey];
    
    __block float comparedHistograms = 0.0;
    __block float comparedFeatures = 0.0;
    __block float comparedHashes = 0.0;
    
    // Parallelize calculations:
    dispatch_group_t calcGroup = dispatch_group_create();
    
    if(!self.lastFeatureVector)
        self.lastFeatureVector = featureVector;

    if(!self.lastHistogram)
        self.lastHistogram = histogram;

    if(!self.lastHash)
        self.lastHash = hash;
    
    if(self.lastFeatureVector && [self.lastFeatureVector featureCount] && [featureVector featureCount] && ([self.lastFeatureVector featureCount] == [featureVector featureCount]))
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            @autoreleasepool
            {
                comparedFeatures = compareFeatureVector(self.lastFeatureVector, featureVector);
                dispatch_group_leave(calcGroup);
            }

        });
    }
    
    if(self.lastHistogram && histogram)
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            @autoreleasepool
            {
                comparedHistograms = compareHistogtams(self.lastHistogram, histogram);
                dispatch_group_leave(calcGroup);
            }
        });
    }
    
    if(self.lastHash && hash)
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            @autoreleasepool
            {
                comparedHashes = compareFrameHashes(self.lastHash, hash);
                dispatch_group_leave(calcGroup);
            }
        });
    }
    
    // Sync threads
    dispatch_group_wait(calcGroup, DISPATCH_TIME_FOREVER);
    
    //                                if(lastComparedFeatures)
//    {
        float deriviativeFeature = self.lastComparedFeatures - comparedFeatures;
//    }
    //                                if(lastComparedHistograms)
//    {
        float deriviativeHistogram = self.lastComparedHistograms - comparedHistograms;
//    }
    //                                if(lastComparedHistograms)
//    {
       float  deriviativeHash = self.lastcomparedHash - comparedHashes;
//    }
    
    NSArray* infoTracks = @[ @(comparedFeatures), @(comparedHistograms), @(comparedHashes), @(deriviativeFeature), @(deriviativeHistogram), @(deriviativeHash)];
    
    [self.derivedMetadataInfo addObject:infoTracks];
    
    //                                        NSLog(@"Time: %f, f %f, df %f  hist %f, dhist %f, hash %f, dhash %f", CMTimeGetSeconds(timedMetadata.timeRange.start),
    //                                              comparedFeatures, deriviativeFeature,
    //                                              comparedHistograms, deriviativeHistogram,
    //                                              comparedHashes, deriviativeHash);
    
    self.lastFeatureVector = nil;
    self.lastHistogram = nil;
    self.lastHash = nil;
        
    self.lastFeatureVector =  featureVector;//[featureVector copy];
    self.lastHistogram = histogram ;
    self.lastHash = hash;

    self.lastComparedFeatures = comparedFeatures;
    self.lastComparedHistograms = comparedHistograms;
    self.lastcomparedHash = comparedHashes;
    
    featureVector = nil;
    histogram = nil;
    hash = nil;
    standard = nil;
    frameMetadata = nil;
}


@end
