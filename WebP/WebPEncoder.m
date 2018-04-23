//
//  WebPEncoder.m
//  APNGAsm
//
//  Created by Morten Bertz on 6/28/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "WebPEncoder.h"
#include "encode.h"
#include "mux.h"


@implementation WebPEncoder{
    WebPAnimEncoderOptions _options;
    WebPAnimEncoder *_encoder;
    WebPConfig _config;
    
}


-(instancetype)init{
    self=[super init];
    if (self){
        self.useLossless=NO;
        self.preset=WebPConversionPresetDefault;
        self.quality=75;
        self.loopCount=0;
    }
    return self;
}


-(void)encodePNGs:(NSArray<NSURL *> *)pngURLs outPath:(NSURL *)outPath size:(CGSize)size withCompletion:(void (^)(NSURL * _Nullable))completion{
    WebPAnimEncoderOptions options;
    WebPAnimEncoderOptionsInit(&options);
    options.anim_params.loop_count=(int)self.loopCount;
    
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef) pngURLs.firstObject, nil);
        NSDictionary *dict=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, nil));
        NSNumber *height=dict[(NSString*) kCGImagePropertyPixelHeight];
        NSNumber *width=dict[(NSString*) kCGImagePropertyPixelWidth];
        size=CGSizeMake(width.doubleValue, height.doubleValue);
        CFRelease(source);
    }
    
    
    WebPAnimEncoder *encoder=WebPAnimEncoderNew(size.width, size.height, &options);
    
    WebPConfig config;
    if (self.useLossless) {
        WebPConfigLosslessPreset(&config, 6);
    }
    else{
        WebPConfigPreset(&config, (WebPPreset)self.preset, self.quality);
    }
   
    

    
    CGFloat timestamp=0;
    
    for (NSURL *url in pngURLs) {
        CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef) url, nil);
        CGImageRef image=CGImageSourceCreateImageAtIndex(source, 0, nil);
        
        CGColorSpaceRef colorSpace = NULL;
        colorSpace = CGColorSpaceCreateDeviceRGB();
        uint8_t *bitmapData;
        
        size_t bitsPerPixel = CGImageGetBitsPerPixel(image);
        size_t bitsPerComponent = CGImageGetBitsPerComponent(image);
        size_t bytesPerPixel = bitsPerPixel / bitsPerComponent;
        
        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        
        size_t bytesPerRow = width * bytesPerPixel;
        size_t bufferLength = bytesPerRow * height;
       
       
        bitmapData=calloc(bufferLength, 1);
        
        CGContextRef context=  CGBitmapContextCreate(bitmapData, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
       
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);

        CGImageRelease(image);
      
        
        WebPPicture pic;
        WebPPictureInit(&pic);
        pic.width=(int)width;
        pic.height=(int)height;
        
        WebPPictureImportRGBA(&pic, bitmapData,(int)bytesPerRow);
        WebPAnimEncoderAdd(encoder, &pic, (int)timestamp, &config);
      
        free(bitmapData);
        WebPPictureFree(&pic);
        CFRelease(source);
        timestamp+=1.0/(CGFloat)self.inverseFPS*1000;
    }
    
    WebPData data;
    WebPDataInit(&data);
    

    WebPAnimEncoderAssemble(encoder, &data);
    
    NSData *outData=[NSData dataWithBytes:data.bytes length:data.size];
    NSError *error;
    if  (![outData writeToURL:outPath options:NSDataWritingAtomic error:&error]){
        NSLog(@"error writing %@",error);
    }
    WebPDataClear(&data);
    WebPAnimEncoderDelete(encoder);
    completion(outPath);
}


-(BOOL)addFrame:(CGImageRef)frame withTimeStamp:(NSTimeInterval)timeStamp{
    BOOL success=NO;
    if (!_encoder) {
        WebPAnimEncoderOptionsInit(&_options);
        _options.anim_params.loop_count=(int)self.loopCount;
        _options.allow_mixed=1;
        CGFloat height=CGImageGetHeight(frame);
        CGFloat width=CGImageGetWidth(frame);
        _encoder=WebPAnimEncoderNew(width, height, &_options);
        
        if (self.useLossless) {
            WebPConfigPreset(&_config, (WebPPreset)self.preset, self.quality);
            WebPConfigLosslessPreset(&_config, 6);
        }
        else{
            WebPConfigPreset(&_config, (WebPPreset)self.preset, self.quality);
        }
    }
    
    
    CGColorSpaceRef colorSpace = NULL;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    uint8_t *bitmapData;
    
    size_t bitsPerPixel = CGImageGetBitsPerPixel(frame);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(frame);
    size_t bytesPerPixel = bitsPerPixel / bitsPerComponent;
    
    size_t width = CGImageGetWidth(frame);
    size_t height = CGImageGetHeight(frame);
    
    size_t bytesPerRow = width * bytesPerPixel;
    size_t bufferLength = bytesPerRow * height;

    bitmapData=calloc(bufferLength, 1);
    CGContextRef context=  CGBitmapContextCreate(bitmapData, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), frame);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    WebPPicture pic;
    WebPPictureInit(&pic);
    pic.width=(int)width;
    pic.height=(int)height;
    
    WebPPictureImportRGBA(&pic, bitmapData,(int)bytesPerRow);
    success=WebPAnimEncoderAdd(_encoder, &pic, (int)(timeStamp*1000), &(_config));
    free(bitmapData);
    WebPPictureFree(&pic);
    return  success;
}

-(void)encodeFramesToURL:(NSURL *)url withCompletion:(void (^)(NSURL * _Nullable))completion{
    
    WebPData data;
    WebPDataInit(&data);
    WebPAnimEncoderAssemble(_encoder, &data);
    
    NSData *outData=[NSData dataWithBytes:data.bytes length:data.size];
    NSError *error;
    if  (![outData writeToURL:url options:NSDataWritingAtomic error:&error]){
        NSLog(@"error writing %@",error);
    }
    WebPDataClear(&data);
    WebPAnimEncoderDelete(_encoder);
    completion(url);

    
}



@end
