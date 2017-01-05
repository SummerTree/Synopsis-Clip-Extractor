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

@interface Document ()
{
    CMSimpleQueueRef compressedMetadataQueue;
    CMSimpleQueueRef decompressedMetadataQueue;
    CMSimpleQueueRef jsonMetadataQueue;
}

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
        int32_t capacity = 1024;
        
        CMSimpleQueueCreate(kCFAllocatorDefault, capacity, &compressedMetadataQueue);
        CMSimpleQueueCreate(kCFAllocatorDefault, capacity, &decompressedMetadataQueue);
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
    CFRelease(decompressedMetadataQueue);
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
        
        AVAssetTrack* assetTrack = [self.clipAsset tracksWithMediaType:AVMediaTypeMetadata][0];
        
        if(assetTrack)
        {
            self.clipAssetReaderTrackOutput = [ AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetTrack outputSettings:nil];
            
            self.clipAssetReaderTrackOutput.alwaysCopiesSampleData = NO;
            
            self.clipAssetReaderMetadataAdaptor = [AVAssetReaderOutputMetadataAdaptor assetReaderOutputMetadataAdaptorWithAssetReaderTrackOutput:self.clipAssetReaderTrackOutput];
            
            if([self.clipAssetReader canAddOutput:self.clipAssetReaderTrackOutput])
            {
                [self.clipAssetReader addOutput:self.clipAssetReaderTrackOutput];
            }
            
            [self.clipAssetReaderTrackOutput markConfigurationAsFinal];
            
            [self.clipAssetReader startReading];
            
            dispatch_semaphore_t finishedSemaphore = dispatch_semaphore_create(4);

            __block BOOL finishedReading = NO;
            __block BOOL finishedDecompressing = NO;
            __block BOOL finishedParsing = NO;
            __block BOOL finishedCalculating = NO;

            // TODO: Fix self capture
            dispatch_async(self.backgroundReadQueue, ^{
                
                while(self.clipAssetReader.status == AVAssetReaderStatusReading )
                {
                    @autoreleasepool
                    {
                        // At capacity?
                        if( CMSimpleQueueGetCount(compressedMetadataQueue) == CMSimpleQueueGetCapacity(compressedMetadataQueue) )
                        {
//                            sleep(1);
                            continue;
                        }
                        
                        AVTimedMetadataGroup* timedMetadata = [self.clipAssetReaderMetadataAdaptor nextTimedMetadataGroup];
                        if(timedMetadata)
                        {
                            for(AVMetadataItem* metadataItem in timedMetadata.items)
                            {
                                NSString* key = metadataItem.identifier;
                                
                                if([key isEqualToString:kSynopsislMetadataIdentifier])
                                {
                                    CMSimpleQueueEnqueue(compressedMetadataQueue, CFBridgingRetain(metadataItem));
                                }
                            }
                        }
                        else
                        {
                            finishedReading = YES;
                            dispatch_semaphore_signal(finishedSemaphore);
                            break;
                        }
                    }
                }
            });
            
            // Decompress Metadata to raw on background queue
            dispatch_async(self.backgroundDecompressionQueue, ^{

                while( ! finishedReading )
                {
                    @autoreleasepool
                    {
                        // At capacity
                        if( CMSimpleQueueGetCount(decompressedMetadataQueue) == CMSimpleQueueGetCapacity(decompressedMetadataQueue) )
                        {
//                            sleep(1);
                            continue;
                        }
                        
                        AVMetadataItem* metadataItem = CFBridgingRelease(CMSimpleQueueDequeue(compressedMetadataQueue));
                        
                        if(metadataItem)
                        {
                            NSData* zipped = (NSData*)metadataItem.value;
                            NSData* json = [zipped gunzippedData];
                            
                            CMSimpleQueueEnqueue(decompressedMetadataQueue, CFBridgingRetain(json));
                        }
                    }
                }
                
                // unwind anything left in the SimpleQueue
                while(  CMSimpleQueueGetCount(compressedMetadataQueue) > 0 )
                {
                    // At capacity
                    if( CMSimpleQueueGetCount(decompressedMetadataQueue) == CMSimpleQueueGetCapacity(decompressedMetadataQueue) )
                    {
//                        sleep(1);
                        continue;
                    }
                    AVMetadataItem* metadataItem = CFBridgingRelease(CMSimpleQueueDequeue(compressedMetadataQueue));
                    
                    if(metadataItem)
                    {
                        NSData* zipped = (NSData*)metadataItem.value;
                        NSData* json = [zipped gunzippedData];
                        
                        CMSimpleQueueEnqueue(decompressedMetadataQueue, CFBridgingRetain(json));
                    }
                }
                
                finishedDecompressing = YES;
                dispatch_semaphore_signal(finishedSemaphore);
            });
            
            // Parse Raw NSData to JSON on background queue
            dispatch_async(self.backgroundJSONParseQueue, ^{
    
                while( ! finishedDecompressing )
                {
                    @autoreleasepool
                    {
                        // At capacity
                        if( CMSimpleQueueGetCount(jsonMetadataQueue) == CMSimpleQueueGetCapacity(jsonMetadataQueue) )
                        {
//                            sleep(1);
                            continue;
                        }
                        
                        // run a few parallel parsing sessions since this is the slowest
                        NSUInteger processors = [NSProcessInfo processInfo].processorCount;
                        
                        // cache n JSON blobs to parse in parallel
                        NSMutableArray* jsonBatch = [NSMutableArray arrayWithCapacity:processors];
                        NSMutableArray* parsedJsonBatch = [NSMutableArray arrayWithCapacity:processors];

                        // Lock access to our parsedJSonBatch array so we can mutate it on parallel threads
                        NSLock* lock = [[NSLock alloc] init];
                        
                        for(NSUInteger proc = 0; proc < processors; proc++)
                        {
                            NSData* json = CFBridgingRelease(CMSimpleQueueDequeue(decompressedMetadataQueue));
                            
                            if(json)
                            {
                                [jsonBatch addObject:json];
                            }
                        }
                        
                        dispatch_group_t parallelParse = dispatch_group_create();
                        
                        for(NSUInteger i = 0; i < jsonBatch.count; i++)
                        {
                            NSData* json = jsonBatch[i];
                            
                            dispatch_group_enter(parallelParse);
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                
                                @autoreleasepool
                                {
                                    NSDictionary* frameMetadata = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
                                    
                                    if(frameMetadata)
                                    {
                                        [lock lock];
                                        [parsedJsonBatch addObject:frameMetadata];
                                        [lock unlock];
                                    }
                                }

                                dispatch_group_leave(parallelParse);
                            });
                        }
                        
                        // Thread sync
                        dispatch_group_wait(parallelParse, DISPATCH_TIME_FOREVER);
                        
                        for(NSDictionary* frameMetadata in parsedJsonBatch)
                        {
                            CMSimpleQueueEnqueue(jsonMetadataQueue, CFBridgingRetain(frameMetadata));
                        }
                    }
                }
                
                // unwind anything left in the SimpleQueue
                while(  CMSimpleQueueGetCount(decompressedMetadataQueue) > 0 )
                {
                    // At capacity
                    if( CMSimpleQueueGetCount(jsonMetadataQueue) == CMSimpleQueueGetCapacity(jsonMetadataQueue) )
                    {
//                        sleep(1);
                        continue;
                    }
                    NSData* json = CFBridgingRelease(CMSimpleQueueDequeue(decompressedMetadataQueue));
                    
                    if(json)
                    {
                        NSDictionary* frameMetadata = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
                        if(frameMetadata)
                        {
                            CMSimpleQueueEnqueue(jsonMetadataQueue, CFBridgingRetain(frameMetadata));
                        }
                    }
                }
                
                finishedParsing = YES;
                dispatch_semaphore_signal(finishedSemaphore);
            });

            
            
            // Calculate frame delta's from Raw JSON Queue
            dispatch_async(self.backgroundCalculateQueue, ^{
                
                while( ! finishedParsing )
                {
                    @autoreleasepool
                    {
                        NSDictionary* frameMetadata = CFBridgingRelease(CMSimpleQueueDequeue(jsonMetadataQueue));
                        
                        if(frameMetadata)
                        {
                            [self calculateFromMetadata:frameMetadata];
                        }
                    }
                }
                
                // unwind anything left in the SimpleQueue
                while(  CMSimpleQueueGetCount(jsonMetadataQueue) > 0 )
                {
                    NSDictionary* frameMetadata = CFBridgingRelease(CMSimpleQueueDequeue(jsonMetadataQueue));
                    
                    if(frameMetadata)
                    {
                        [self calculateFromMetadata:frameMetadata];
                    }
                }
                
                finishedCalculating = YES;
                dispatch_semaphore_signal(finishedSemaphore);
            });
            
            // Wait on our semaphor
            
        }
    }

    return self;
}

- (void) calculateFromMetadata:(NSDictionary*)frameMetadata
{
    NSDictionary* standard = [frameMetadata valueForKey:kSynopsisStandardMetadataDictKey];
    NSArray* featureVector = [standard valueForKey:kSynopsisStandardMetadataFeatureVectorDictKey];
    NSArray* histogram = [standard valueForKey:kSynopsisStandardMetadataHistogramDictKey];
    NSString* hash = [standard valueForKey:kSynopsisStandardMetadataPerceptualHashDictKey];
    
    __block float comparedHistograms = 0.0;
    __block float comparedFeatures = 0.0;
    __block float comparedHashes = 0.0;
    
    // Parallelize calculations:
    dispatch_group_t calcGroup = dispatch_group_create();
    
    if(self.lastFeatureVector && self.lastFeatureVector.count && featureVector.count && (self.lastFeatureVector.count == featureVector.count))
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            comparedFeatures = compareFeatureVector(self.lastFeatureVector, featureVector);
            dispatch_group_leave(calcGroup);
            
        });
    }
    
    if(self.lastHistogram && histogram)
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            comparedHistograms = compareHistogtams(self.lastHistogram, histogram);
            dispatch_group_leave(calcGroup);
        });
    }
    
    if(self.lastHash && hash)
    {
        dispatch_group_enter(calcGroup);
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            
            comparedHashes = compareFrameHashes(self.lastHash, hash);
            dispatch_group_leave(calcGroup);
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
    
    self.lastFeatureVector = featureVector;
    self.lastHistogram = histogram;
    self.lastHash = hash;
    
    self.lastComparedFeatures = comparedFeatures;
    self.lastComparedHistograms = comparedHistograms;
    self.lastcomparedHash = comparedHashes;

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
