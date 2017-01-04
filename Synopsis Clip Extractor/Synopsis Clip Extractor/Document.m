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

@property (strong) AVURLAsset* clipAsset;
@property (strong) AVAssetReader* clipAssetReader;
@property (strong) AVAssetReaderTrackOutput* clipAssetReaderTrackOutput;
@property (strong) AVAssetReaderOutputMetadataAdaptor* clipAssetReaderMetadataAdaptor;


@property (strong) dispatch_queue_t backgroundQueue;

// Array of CMTimeRanges
@property (strong) NSMutableArray<NSValue*>* potentialEditPoints;


@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        
        self.backgroundQueue = dispatch_queue_create("info.synopsis.clip.extractor.backgroundqueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
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
            
            self.clipAssetReaderMetadataAdaptor = [AVAssetReaderOutputMetadataAdaptor assetReaderOutputMetadataAdaptorWithAssetReaderTrackOutput:self.clipAssetReaderTrackOutput];
            
            if([self.clipAssetReader canAddOutput:self.clipAssetReaderTrackOutput])
            {
                [self.clipAssetReader addOutput:self.clipAssetReaderTrackOutput];
            }
            
            [self.clipAssetReader startReading];
            
            // TODO: Fix self capture
            dispatch_async(self.backgroundQueue, ^{
                
                //Cache last decoded metadata info
                NSArray* lastFeatureVector = nil;
                NSArray* lastHistogram = nil;
                NSString* lastHash = nil;
                
                float lastComparedFeatures = 0;
                float lastComparedHistograms = 0;
                float lastcomparedHash = 0;
                
                float deriviativeFeature = 0;
                float deriviativeHistogram = 0;
                float deriviativeHash = 0;
                
                while(self.clipAssetReader.status == AVAssetReaderStatusReading)
                {
                    AVTimedMetadataGroup* timedMetadata = [self.clipAssetReaderMetadataAdaptor nextTimedMetadataGroup];
                    
                    if(timedMetadata)
                    {
                        for(AVMetadataItem* item in timedMetadata.items)
                        {
                            NSDictionary* frameMetadata = [self decodeSynopsisMetadataItem:item];
                            NSDictionary* standard = [frameMetadata valueForKey:kSynopsisStandardMetadataDictKey];
                            NSArray* histogram = [standard valueForKey:kSynopsisStandardMetadataHistogramDictKey];
                            NSString* hash = [standard valueForKey:kSynopsisStandardMetadataPerceptualHashDictKey];
                            
                            NSArray* featureVector = [standard valueForKey:kSynopsisStandardMetadataFeatureVectorDictKey];
                            
                            float comparedHistograms = 0.0;
                            float comparedFeatures = 0.0;
                            float comparedHashes = 0.0;
                            
                            if(lastFeatureVector && lastFeatureVector.count && featureVector.count && (lastFeatureVector.count == featureVector.count))
                            {
                                comparedFeatures = compareFeatureVector(lastFeatureVector, featureVector);
                                
//                                if(lastComparedFeatures)
                                {
                                    deriviativeFeature = lastComparedFeatures - comparedFeatures;
                                }
                            }
                            
                            if(lastHistogram && histogram)
                            {
                                comparedHistograms = compareHistogtams(lastHistogram, histogram);
                                
//                                if(lastComparedHistograms)
                                {
                                    deriviativeHistogram = lastComparedHistograms - comparedHistograms;
                                }

                            }
                            
                            if(lastHash && hash)
                            {
                                comparedHashes = compareFrameHashes(lastHash, hash);
                                
//                                if(lastComparedHistograms)
                                {
                                    deriviativeHash = lastcomparedHash - comparedHashes;
                                }

                            }
                            
                            NSLog(@"Time: %f, f %f, df %f  hist %f, dhist %f, hash %f, dhash %f", CMTimeGetSeconds(timedMetadata.timeRange.start),
                                  comparedFeatures, deriviativeFeature,
                                  comparedHistograms, deriviativeHistogram,
                                  comparedHashes, deriviativeHash);
                            
                            lastFeatureVector = featureVector;
                            lastHistogram = histogram;
                            lastHash = hash;
                            
                            lastComparedFeatures = comparedFeatures;
                            lastComparedHistograms = comparedHistograms;
                            lastcomparedHash = comparedHashes;

                        }
                    }
                    else
                    {
                        break;
                    }
                    
                }
            });
        }
    }

    return self;
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
