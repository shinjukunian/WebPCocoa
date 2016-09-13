
//
//  WebPDecoder2.m
//  APNGAsm
//
//  Created by Morten Bertz on 6/29/16.
//  Copyright © 2016 telethon k.k. All rights reserved.
//

#import "WebPDecoder.h"
#import "demux.h"
#import "decode.h"

#define kDefaultFrameRate 10.0

//https://chromium.googlesource.com/webm/libwebp/+/master/examples/anim_util.c

typedef struct {
    uint8_t* rgba;         // Decoded and reconstructed full frame.
    int duration;          // Frame duration in milliseconds.
    int is_key_frame;      // True if this frame is a key-frame.
} DecodedFrame;

typedef struct {
    uint32_t canvas_width;
    uint32_t canvas_height;
    uint32_t bgcolor;
    uint32_t loop_count;
    DecodedFrame* frames;
    uint32_t num_frames;
    void* raw_mem;
} AnimatedImage;

static const int kNumChannels = 4;


@interface WebPDecoder ()

@property NSURL *imageURL;
@property BOOL shouldCache;
@property NSCache *cache;
@property CGFloat width;
@property CGFloat height;


@end



@implementation WebPDecoder{
    AnimatedImage _images;
    NSMutableArray *_tStamps;
    NSMutableArray *_tStampsRel;
    NSUInteger _numFr;
}

-(instancetype)initWithURL:(NSURL *)url shouldCache:(BOOL)cache{
    self=[super init];
    if (self) {
        self.imageURL=url;
        self.shouldCache=cache;
        if (cache) {
            self.cache=[[NSCache alloc]init];
            [self readWebP:url];
            
        }
        else{
            WebPData data;
            WebPDataInit(&data);
            
            NSData *inData=[NSData dataWithContentsOfURL:url];
            data.bytes=inData.bytes;
            data.size=inData.length;
            WebPAnimDecoderOptions options;
            WebPAnimDecoderOptionsInit(&options);
            WebPAnimDecoder *decoder=WebPAnimDecoderNew(&data, &options);
            WebPAnimInfo info;
            WebPAnimDecoderGetInfo(decoder, &info);
            self.width=info.canvas_width;
            self.height=info.canvas_height;
            _numFr=info.frame_count;
            WebPAnimDecoderDelete(decoder);
            
        }

    }
    
    return  self;
}


-(BOOL)readWebP:(NSURL*)url{
    
    BOOL success=NO;
    
    _tStamps=[NSMutableArray new];
    _tStampsRel=[NSMutableArray new];
    [_tStamps addObject:@(0)];
    
    WebPData data;
    WebPDataInit(&data);
    
    NSData *inData=[NSData dataWithContentsOfURL:url];
    data.bytes=inData.bytes;
    data.size=inData.length;
    
    ReadAnimatedWebP(nil, &data, &_images, NO, nil);
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    self.height=_images.canvas_height;
    self.width=_images.canvas_width;
    _numFr=_images.num_frames;
    CGFloat elapsedTime=0;
    for (NSUInteger i=0; i<_images.num_frames; i++) {
        NSUInteger size=_images.canvas_width*_images.canvas_height*kNumChannels;
        DecodedFrame frame=_images.frames[i];
        elapsedTime+=frame.duration;
        CGDataProviderRef dataProvider=CGDataProviderCreateWithData(NULL, frame.rgba, size, releaseImageData);
        CGBitmapInfo bitmapInfo= kCGBitmapByteOrderDefault | kCGImageAlphaLast;
        CGImageRef imageRef = CGImageCreate(_images.canvas_width, _images.canvas_height, 8, 32, _images.canvas_width*4, colorSpace, bitmapInfo, dataProvider, NULL, false, kCGRenderingIntentDefault);
        
        CGDataProviderRelease(dataProvider);
        [self.cache setObject:CFBridgingRelease(imageRef) forKey:@(i)];
        [_tStamps addObject:@(elapsedTime)];
        
    }
    if (elapsedTime>0) {
        for (NSNumber *number in _tStamps) {
            CGFloat relativeTime=number.floatValue/elapsedTime;
            [_tStampsRel addObject:@(relativeTime)];
        }
    }
    else{
        elapsedTime=1/kDefaultFrameRate*_numFr;
        NSMutableArray *dummyStamps=[NSMutableArray new];
        CGFloat dummyTime=0;
        for (NSUInteger idx=0; idx<_numFr; idx++) {
            [dummyStamps addObject:@(dummyTime)];
            [_tStampsRel addObject:@((float)idx/(float)_numFr)];
            dummyTime+=1/kDefaultFrameRate*1000;
  
        }
        _tStamps=dummyStamps;
        
    }

    
   // ClearAnimatedImage(&(_images));
    CGColorSpaceRelease(colorSpace);
    return  success;
}




-(CGImageRef)imageAtIndex:(NSUInteger)idx{
    if (self.shouldCache) {
        CGImageRef im=(__bridge CGImageRef)([self.cache objectForKey:@(idx)]);
        if (im){
            return im;
        }
        else{
            if([self readWebP:self.imageURL]){
                CGImageRef im=(__bridge CGImageRef)([self.cache objectForKey:@(idx)]);
                if (im){
                    return im;
                }
            }
        }
        
        
    }
    return nil;
}

-(NSUInteger)numberOfFrames{
    return _numFr;
}

-(CGSize)frameSize{
    return  CGSizeMake(self.width, self.height);
}


-(void)dealloc{
    if (_images.frames) {
        ClearAnimatedImage(&(_images));
    }
}

-(NSArray*)timeStamps{
    return _tStamps.copy;
}

-(NSArray*)relativeTimeStamps{
    return _tStampsRel.copy;
}

static int ReadAnimatedWebP(const char filename[],
                            const WebPData* const webp_data,
                            AnimatedImage* const image, int dump_frames,
                            const char dump_folder[]) {
    int ok = 0;
    int dump_ok = 1;
    uint32_t frame_index = 0;
    int prev_frame_timestamp = 0;
    WebPAnimDecoder* dec;
    WebPAnimInfo anim_info;
    memset(image, 0, sizeof(*image));
    dec = WebPAnimDecoderNew(webp_data, NULL);
    if (dec == NULL) {
        fprintf(stderr, "Error parsing image: %s\n", filename);
        goto End;
    }
    if (!WebPAnimDecoderGetInfo(dec, &anim_info)) {
        fprintf(stderr, "Error getting global info about the animation\n");
        goto End;
    }
    // Animation properties.
    image->canvas_width = anim_info.canvas_width;
    image->canvas_height = anim_info.canvas_height;
    image->loop_count = anim_info.loop_count;
    image->bgcolor = anim_info.bgcolor;
    // Allocate frames.
    if (!AllocateFrames(image, anim_info.frame_count)) return 0;
    // Decode frames.
    while (WebPAnimDecoderHasMoreFrames(dec)) {
        DecodedFrame* curr_frame;
        uint8_t* curr_rgba;
        uint8_t* frame_rgba;
        int timestamp;
        if (!WebPAnimDecoderGetNext(dec, &frame_rgba, &timestamp)) {
            fprintf(stderr, "Error decoding frame #%u\n", frame_index);
            goto End;
        }
        assert(frame_index < anim_info.frame_count);
        curr_frame = &image->frames[frame_index];
        curr_rgba = curr_frame->rgba;
        curr_frame->duration = timestamp - prev_frame_timestamp;
        curr_frame->is_key_frame = 0;  // Unused.
        memcpy(curr_rgba, frame_rgba,
               image->canvas_width * kNumChannels * image->canvas_height);
        // Needed only because we may want to compare with GIF later.
//        CleanupTransparentPixels((uint32_t*)curr_rgba,
//                                 image->canvas_width, image->canvas_height);
        if (dump_frames && dump_ok) {
            dump_ok = DumpFrame(filename, dump_folder, frame_index, curr_rgba,
                                image->canvas_width, image->canvas_height);
            if (!dump_ok) {  // Print error once, but continue decode loop.
                fprintf(stderr, "Error dumping frames to %s\n", dump_folder);
            }
        }
        ++frame_index;
        prev_frame_timestamp = timestamp;
    }
    ok = dump_ok;
End:
    WebPAnimDecoderDelete(dec);
    return ok;
}


static void releaseImageData(void *info, const void *data, size_t size)
{
    //free((uint8_t*)data);
}




+(BOOL)isWebP:(NSURL *)url{
    
    WebPData data;
    WebPDataInit(&data);
    
    NSData *inData=[NSData dataWithContentsOfURL:url];
    data.bytes=inData.bytes;
    data.size=inData.length;
    return  IsWebP(&data);

}


static int IsWebP(const WebPData* const webp_data) {
    return (WebPGetInfo(webp_data->bytes, webp_data->size, NULL, NULL) != 0);
}



void ClearAnimatedImage(AnimatedImage* const image) {
    if (image != NULL) {
        free(image->raw_mem);
        free(image->frames);
        image->num_frames = 0;
        image->frames = NULL;
        image->raw_mem = NULL;
    }
}


static int AllocateFrames(AnimatedImage* const image, uint32_t num_frames) {
    uint32_t i;
    const size_t rgba_size =
    image->canvas_width * kNumChannels * image->canvas_height;
    uint8_t* const mem = (uint8_t*)malloc(num_frames * rgba_size * sizeof(*mem));
    DecodedFrame* const frames =
    (DecodedFrame*)malloc(num_frames * sizeof(*frames));
    if (mem == NULL || frames == NULL) {
        free(mem);
        free(frames);
        return 0;
    }
    free(image->raw_mem);
    image->num_frames = num_frames;
    image->frames = frames;
    for (i = 0; i < num_frames; ++i) {
        frames[i].rgba = mem + i * rgba_size;
        frames[i].duration = 0;
        frames[i].is_key_frame = 0;
    }
    image->raw_mem = mem;
    return 1;
}





static int DumpFrame(const char filename[], const char dump_folder[],
                     uint32_t frame_num, const uint8_t rgba[],
                     int canvas_width, int canvas_height) {
    int ok = 0;
    size_t max_len;
    int y;
    const char* base_name = NULL;
    char* file_name = NULL;
    FILE* f = NULL;
    base_name = strrchr(filename, '/');
    base_name = (base_name == NULL) ? filename : base_name + 1;
    max_len = strlen(dump_folder) + 1 + strlen(base_name)
    + strlen("_frame_") + strlen(".pam") + 8;
    file_name = (char*)malloc(max_len * sizeof(*file_name));
    if (file_name == NULL) goto End;
    if (snprintf(file_name, max_len, "%s/%s_frame_%d.pam",
                 dump_folder, base_name, frame_num) < 0) {
        fprintf(stderr, "Error while generating file name\n");
        goto End;
    }
    f = fopen(file_name, "wb");
    if (f == NULL) {
        fprintf(stderr, "Error opening file for writing: %s\n", file_name);
        ok = 0;
        goto End;
    }
    if (fprintf(f, "P7\nWIDTH %d\nHEIGHT %d\n"
                "DEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n",
                canvas_width, canvas_height) < 0) {
        fprintf(stderr, "Write error for file %s\n", file_name);
        goto End;
    }
    for (y = 0; y < canvas_height; ++y) {
        if (fwrite((const char*)(rgba) + y * canvas_width * kNumChannels,
                   canvas_width * kNumChannels, 1, f) != 1) {
            fprintf(stderr, "Error writing to file: %s\n", file_name);
            goto End;
        }
    }
    ok = 1;
End:
    if (f != NULL) fclose(f);
    free(file_name);
    return ok;
}


@end
