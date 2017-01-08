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
#import <Synopsis/GZIP.h>
#import "KeyframeView.h"
#import "TimelineView.h"

@interface Document ()
{
    CMSimpleQueueRef compressedMetadataQueue;
    CMSimpleQueueRef jsonMetadataQueue;
}

@property (weak) IBOutlet KeyframeView* keyframeView;
@property (weak) IBOutlet TimelineView* timelineView;

@property (strong) AVURLAsset* clipAsset;
@property (strong) AVAssetReader* clipAssetReader;
@property (strong) AVAssetReaderTrackOutput* clipAssetReaderTrackOutput;
@property (strong) AVAssetReaderOutputMetadataAdaptor* clipAssetReaderMetadataAdaptor;


@property (strong) dispatch_queue_t backgroundReadQueue;
@property (strong) dispatch_queue_t backgroundDecompressionQueue;
@property (strong) dispatch_queue_t backgroundJSONParseQueue;
@property (strong) dispatch_queue_t backgroundCalculateQueue;

// Array of CMTimeRanges
@property (strong) NSMutableArray<NSValue*>* potentialEditPoints;

// For Delta / Dervitative calculations
@property (strong) NSArray* lastFeatureVector;
@property (strong) NSArray* lastHistogram;
@property (strong) NSString* lastHash;

@property (assign) float lastComparedFeatures;
@property (assign) float lastComparedHistograms;
@property (assign) float lastcomparedHash;

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        int32_t capacity = 64;
        
        CMSimpleQueueCreate(kCFAllocatorDefault, capacity, &compressedMetadataQueue);
        CMSimpleQueueCreate(kCFAllocatorDefault, capacity, &jsonMetadataQueue);
        
        self.backgroundReadQueue = dispatch_queue_create("info.synopsis.clip.extractor.backgroundReadQueue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        self.backgroundDecompressionQueue = dispatch_queue_create("info.synopsis.clip.extractor.backgroundDecompressionQueue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        self.backgroundJSONParseQueue = dispatch_queue_create("info.synopsis.clip.extractor.backgroundJSONParseQueue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        self.backgroundCalculateQueue = dispatch_queue_create("info.synopsis.clip.extractor.backgroundCalculateQueue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    }
    return self;
}

- (void) dealloc
{
    CFRelease(compressedMetadataQueue);
    CFRelease(jsonMetadataQueue);
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
        self.clipAsset = [AVURLAsset assetWithURL:url];
        
        self.clipAssetReader = [AVAssetReader assetReaderWithAsset:self.clipAsset error:nil];
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
    
    [self.keyframeView setFrameFromDuration:duration andFrameDuration:frameDuration];
    [self.timelineView setFrameFromDuration:duration andFrameDuration:frameDuration];
    
    if(metadataAssetTrack)
    {
        self.clipAssetReaderTrackOutput = [ AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:metadataAssetTrack outputSettings:nil];
        
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
    [self.clipAssetReader startReading];
    
    __weak typeof (self) weakSelf = self;
    
    dispatch_group_t pipelineGroup = dispatch_group_create();
    
    __block BOOL finishedReading = NO;
    __block BOOL finishedDecompressing = NO;
    __block BOOL finishedParsing = NO;
    __block BOOL finishedCalculating = NO;
    
    useconds_t sleepTime = 1000;
    
    // Read Thread
    dispatch_group_enter(pipelineGroup);
    dispatch_async(weakSelf.backgroundReadQueue, ^{
        
        while(weakSelf.clipAssetReader.status == AVAssetReaderStatusReading )
        {
            @autoreleasepool
            {
                // At capacity?
                if( CMSimpleQueueGetCount(compressedMetadataQueue) == CMSimpleQueueGetCapacity(compressedMetadataQueue) )
                {
//                    NSLog(@"CompressedMetadata Queue Full - Throttling");
                    usleep(sleepTime);
                    continue;
                }
                
                AVTimedMetadataGroup* timedMetadata = [weakSelf.clipAssetReaderMetadataAdaptor nextTimedMetadataGroup];
                if(timedMetadata)
                {
                    for(AVMetadataItem* metadataItem in timedMetadata.items)
                    {
                        NSString* key = metadataItem.identifier;
                        
                        if([key isEqualToString:kSynopsislMetadataIdentifier])
                        {
                            CFDataRef data = (CFDataRef)CFBridgingRetain(metadataItem.value);
                            if(data)
                                CMSimpleQueueEnqueue(compressedMetadataQueue, data);
                        }
                    }
                }
                else
                {
                    finishedReading = YES;
                    dispatch_group_leave(pipelineGroup);
                    break;
                }
            }
        }
    });

    
    dispatch_group_enter(pipelineGroup);
    dispatch_async(weakSelf.backgroundJSONParseQueue, ^{

        // Parse Zipped Data to JSON on background queue
        NSUInteger batchCount = [NSProcessInfo processInfo].processorCount;
        NSLock* batchLock = [[NSLock alloc] init];
        NSMutableArray* batchCache = [NSMutableArray arrayWithCapacity:batchCount];
        dispatch_group_t batchGroup = dispatch_group_create();

        while( ! finishedReading )
        {
            @autoreleasepool
            {
                // At capacity
                if( CMSimpleQueueGetCount(jsonMetadataQueue) == CMSimpleQueueGetCapacity(jsonMetadataQueue) )
                {
//                    NSLog(@"JSONMetadata Queue Full - Throttling");
                    usleep(sleepTime);
                    continue;
                }
                
                // Parallelize unzip and json parsing
                __block int dataCount = 0;
                for(int i = 0; i < batchCount; i++)
                {
                    CFDataRef data = (CFDataRef)(CMSimpleQueueDequeue(compressedMetadataQueue));
                    
                    if(data)
                    {
                        dispatch_group_enter(batchGroup);
                        
                        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                            
                            @autoreleasepool
                            {
                                NSData* json = [(__bridge NSData*)data gunzippedData];
                                
                                if(json)
                                {
                                    NSDictionary* frameMetadata = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
                                    
                                    if(frameMetadata)
                                    {
                                        // TODO: FIX ORDERING HERE:
                                        [batchLock lock];
                                        dataCount++;
//                                        [batchCache insertObject:frameMetadata atIndex:dataCount];
                                        [batchCache addObject:frameMetadata];
                                        [batchLock unlock];
                                    }
                                }
                                CFRelease(data);
                            }
                            
                            dispatch_group_leave(batchGroup);
                        });
                    }
                }
                
                dispatch_group_wait(batchGroup, DISPATCH_TIME_FOREVER);

                [batchLock lock];

                for(int i = 0; i < batchCache.count; i++)
                {
                    NSDictionary* frameMetadata = batchCache[i];
                    
                    if(frameMetadata)
                    {
//                        dispatch_async(weakSelf.backgroundCalculateQueue, ^{
//                            @autoreleasepool {
                                [weakSelf calculateFromMetadata:frameMetadata];
//                            }
//                        });

                        frameMetadata = nil;
                    }
                }
                
                [batchCache removeAllObjects];
//                batchCache = [NSMutableArray arrayWithCapacity:batchCount];
                [batchLock unlock];
            }
        }
        
        // unwind anything left in the SimpleQueue
        while(  CMSimpleQueueGetCount(compressedMetadataQueue) > 0 )
        {
            // At capacity
            if( CMSimpleQueueGetCount(jsonMetadataQueue) == CMSimpleQueueGetCapacity(jsonMetadataQueue) )
            {
//                NSLog(@"JSONMetadata Queue Full - Throttling");
                usleep(sleepTime);
                continue;
            }

            CFDataRef data = (CFDataRef)(CMSimpleQueueDequeue(compressedMetadataQueue));
            
            if(data)
            {
                NSData* json = [(__bridge NSData*)data gunzippedData];
                
                if(json)
                {
                    NSDictionary* frameMetadata = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
                    
                    if(frameMetadata)
                    {
//                        dispatch_async(weakSelf.backgroundCalculateQueue, ^{
//                            @autoreleasepool {
                                [weakSelf calculateFromMetadata:frameMetadata];
//                            }
//                        });
                    }
                    
                    frameMetadata = nil;
                }
                CFRelease(data);
            }
        }
        
        finishedParsing = YES;
        dispatch_group_leave(pipelineGroup);
    });
    
    
    dispatch_group_wait(pipelineGroup, DISPATCH_TIME_FOREVER);
    NSLog(@"Finished");
}

- (void) calculateFromMetadata:(NSDictionary*)frameMetadata
{
    NSDictionary* standard = [frameMetadata objectForKey:kSynopsisStandardMetadataDictKey];
    NSArray* featureVector = [standard objectForKey:kSynopsisStandardMetadataFeatureVectorDictKey];
    NSArray* histogram = [standard objectForKey:kSynopsisStandardMetadataHistogramDictKey];
    NSString* hash = [standard objectForKey:kSynopsisStandardMetadataPerceptualHashDictKey];
    
    __block float comparedHistograms = 0.0;
    __block float comparedFeatures = 0.0;
    __block float comparedHashes = 0.0;
    
    // Parallelize calculations:
    dispatch_group_t calcGroup = dispatch_group_create();
    
    if(self.lastFeatureVector && self.lastFeatureVector.count && featureVector.count && (self.lastFeatureVector.count == featureVector.count))
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
    {
        float deriviativeFeature = self.lastComparedFeatures - comparedFeatures;
    }
    //                                if(lastComparedHistograms)
    {
        float deriviativeHistogram = self.lastComparedHistograms - comparedHistograms;
    }
    //                                if(lastComparedHistograms)
    {
       float  deriviativeHash = self.lastcomparedHash - comparedHashes;
    }
    
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

- (id) decodeSynopsisMetadataItem:(AVMetadataItem*)metadataItem
{
    
    NSString* key = metadataItem.identifier;
    
    if([key isEqualToString:kSynopsislMetadataIdentifier])
    {
        // JSON
        //                // Decode our metadata..
        //                NSString* stringValue = (NSString*)metadataItem.value;
        //                NSData* dataValue = [stringValue dataUsingEncoding:NSUTF8StringEncoding];
        //                id decodedJSON = [NSJSONSerialization JSONObjectWithData:dataValue options:kNilOptions error:nil];
        //                if(decodedJSON)
        //                    [metadataDictionary setObject:decodedJSON forKey:key];
        
        //                // BSON:
        //                NSData* zipped = (NSData*)metadataItem.value;
        //                NSData* bsonData = [zipped gunzippedData];
        //                NSDictionary* bsonDict = [NSDictionary dictionaryWithBSON:bsonData];
        //                if(bsonDict)
        //                    [metadataDictionary setObject:bsonDict forKey:key];
        
        // GZIP + JSON
        NSData* zipped = (NSData*)metadataItem.value;
        NSData* json = [zipped gunzippedData];
        id decodedJSON = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
        if(decodedJSON)
        {
            return decodedJSON;
        }
        
        return nil;
    }
    
    return nil;

}



@end
