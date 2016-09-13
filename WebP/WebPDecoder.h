//
//  WebPDecoder2.h
//  APNGAsm
//
//  Created by Morten Bertz on 6/29/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WebPDecoder2 : NSObject


@property (readonly) NSUInteger numberOfFrames;
@property (readonly) CGSize frameSize;
@property (readonly) NSArray <NSNumber*>*_Nonnull timeStamps;
@property (readonly) NSArray <NSNumber*>*_Nonnull relativeTimeStamps;


-(instancetype _Nonnull)initWithURL:(NSURL* _Nonnull)url shouldCache:(BOOL)cache;
-(CGImageRef _Nullable  )imageAtIndex:(NSUInteger)idx  CF_RETURNS_NOT_RETAINED;

+(BOOL)isWebP:(nonnull NSURL*)url;


@end
