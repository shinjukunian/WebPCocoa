//
//  WebPEncoder.h
//  APNGAsm
//
//  Created by Morten Bertz on 6/28/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger,WebPConversionPreset) {
    WebPConversionPresetDefault=0,
    WebPConversionPresetPicture,
    WebPConversionPresetPhoto,
    WebPConversionPresetDrawing,
    WebPConversionPresetDrawingIcon,
    WebPConversionPresetText
};


@interface WebPEncoder : NSObject

@property NSUInteger inverseFPS;
@property CGFloat quality;
@property WebPConversionPreset preset;
@property BOOL useLossless;
@property NSUInteger loopCount;


-(void)encodePNGs:(NSArray <NSURL*> * _Nonnull )pngURLs outPath:(NSURL* _Nonnull )outPath size:(CGSize)size withCompletion:(void(^_Nonnull)(NSURL * _Nullable outURL))completion;

-(BOOL)addFrame:(nonnull CGImageRef)frame withTimeStamp:(NSTimeInterval)timeStamp;
-(void)encodeFramesToURL:(nonnull NSURL*)url withCompletion:(void(^_Nonnull)(NSURL *_Nullable ourURL))completion;


@end
