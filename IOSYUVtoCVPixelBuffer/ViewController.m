//
//  ViewController.m
//  IOSYUVtoCVPixelBuffer
//
//  Created by starmier on 2019/6/2.
//  Copyright © 2019年 yy. All rights reserved.
//

#import "ViewController.h"
#import <CoreMedia/CMTime.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface ViewController ()
{
	dispatch_queue_t mPushQueue;
	FILE* mVideoSourceFile;
	BOOL mIsStartPublish;
	
	dispatch_queue_t mPushAudioQueue;
	FILE* file;
	BOOL mIsStartAudioPublish;
	NSUInteger mSampleRate;
	NSUInteger mChannelsPerFrame;
	AudioStreamBasicDescription mAudioStreamBasicDescription;
}

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)doTestVideo
{
	if (mPushQueue == NULL)
	{
		mPushQueue = dispatch_queue_create("external.push.video", DISPATCH_QUEUE_SERIAL);
	}
	
	if (mVideoSourceFile == NULL)
	{
		NSString *path=[[NSBundle mainBundle] pathForResource:@"V_544_304_nv12" ofType:@"yuv"];//16位对齐，但是画面显示正常；
//		NSString *path=[[NSBundle mainBundle] pathForResource:@"V_540_302_nv12" ofType:@"yuv"];//没有16位对齐，花屏，需要进行逐行copy进行子节对齐
//		NSString *path=[[NSBundle mainBundle] pathForResource:@"V640_360_x264_nv21" ofType:@"yuv"];
//
//		NSString *path=[[NSBundle mainBundle] pathForResource:@"V_544_304_yuv420p" ofType:@"yuv"];//16位对齐，但是画面显示正常；
//
//		NSString *path=[[NSBundle mainBundle] pathForResource:@"V640_360_x264_rgba" ofType:@"rgb"];
//		NSString *path=[[NSBundle mainBundle] pathForResource:@"V640_360_x264_rgba" ofType:@"rgb"];//16位对齐，但是画面显示正常；
		
		
		if((mVideoSourceFile=fopen([path UTF8String],"r"))==NULL)
		{
			printf("File cannot be opened./n");
		}
	}
	
	dispatch_async(mPushQueue, ^{
		
		UInt64 _time = 0;
//		int width = 640;
//		int height = 360;
//		size_t samples = width*height*4;
//
//		int width = 540;
//		int height = 302;
		int width = 544;
		int height = 304;
		NSUInteger samples = width*height*3/2;
		
		uint8_t* buf = (uint8_t *)malloc(samples);
		while (1)
		{
			if(self->mIsStartPublish)
			{
				UInt64 now = [[NSDate date] timeIntervalSince1970] * 1000;//ms
				if (now - _time > 60)
				{
					memset(buf, 0, samples);
					fread(buf, samples, 1, self->mVideoSourceFile);
					CVPixelBufferRef pixelBuffer = [self createCVPixelBufferRefFromNV12buffer1:buf width:width height:height];
//					CVPixelBufferRef pixelBuffer = [self createCVPixelBufferRefFromNV12buffer:buf width:width height:height];//逐行copy
//					CVPixelBufferRef pixelBuffer = [self createCVPixelBufferRefFromYUV420pBuffer:buf width:width height:height];
//					CVPixelBufferRef pixelBuffer = [self createCVPixelBufferRefFromBGRAbuffer:buf width:width height:height];
//					CVPixelBufferRef pixelBuffer = [self createCVPixelBufferRefFromBGRAbuf:buf width:width height:height];
					_time = now;
//					UIImage* img = [UIImage imageNamed:@"testimg"];
//					CVPixelBufferRef pixelBuffer = [self CVPixelBufferRefFromUiImage:img];
					CMTime time = CMTimeMakeWithSeconds(_time, 1);
					NSLog(@"====== push data video:%p now:%llu", pixelBuffer, _time);
					CVPixelBufferRelease(pixelBuffer);
					
					int eof = feof(self->mVideoSourceFile);
					if (eof == 1) {
						NSLog(@"====== push data video is end....");
						self->mIsStartPublish = NO;
					}
				}
			}
		}
	});
	
	if (mPushAudioQueue == NULL)
	{
		mPushAudioQueue = dispatch_queue_create("external.push.audio", DISPATCH_QUEUE_SERIAL);
	}
	
	if (file == NULL)
	{
		NSString *path=[[NSBundle mainBundle] pathForResource:@"t44_1_a" ofType:@"pcm"];
		if((file=fopen([path UTF8String],"r"))==NULL)
		{
			printf("File cannot be opened./n");
		}
	}
	
	mSampleRate = 44100;
	mChannelsPerFrame = 1;
	mAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
	mAudioStreamBasicDescription.mFormatFlags = 0;
	mAudioStreamBasicDescription.mSampleRate = 44100;
	mAudioStreamBasicDescription.mChannelsPerFrame = 2;
	mAudioStreamBasicDescription.mBitsPerChannel = 16;
	mAudioStreamBasicDescription.mFramesPerPacket = 1024;
	mAudioStreamBasicDescription.mBytesPerFrame = mAudioStreamBasicDescription.mBitsPerChannel * mAudioStreamBasicDescription.mChannelsPerFrame / 8;
	mAudioStreamBasicDescription.mBytesPerPacket = mAudioStreamBasicDescription.mFramesPerPacket*mAudioStreamBasicDescription.mBytesPerFrame;
	
	dispatch_async(mPushAudioQueue, ^{
		
		UInt64 _time = 0;
		NSUInteger samples = self->mSampleRate * 200 * self->mChannelsPerFrame/1000;
		uint8_t* buf = (uint8_t *)malloc(samples*2);
		while (1)
		{
			if(self->mIsStartAudioPublish)
			{
				UInt64 now = [[NSDate date] timeIntervalSince1970] * 1000;//ms
				if (now - _time > 200)
				{
					memset(buf, 0, samples*2);
					size_t size1 = fread(buf, samples*2, 1, self->file);
					
					_time = now;
//						CMSampleBufferRef sampleBuffer = [self createAudioSampleBuffer:buf withLen:0 withASBD:self->mAudioStreamBasicDescription];
					
					NSLog(@"====== push data audio now:%llu, size1:%zu.\n", _time, size1);
					int eof = feof(self->file);
					if (eof == 1) {
						NSLog(@"====== push data audio is end....");
						self->mIsStartAudioPublish = NO;
					}
				}
			}
		}
	});
}


- (uint32_t)bitmapInfoWithPixelFormatType:(OSType) pixelFormat
{
	if (pixelFormat == kCVPixelFormatType_32BGRA) {
//		uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
		//此格式也可以
		uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
		return bitmapInfo;
	}else if (pixelFormat == kCVPixelFormatType_32ARGB){
		uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big;
		//此格式也可以
//		uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Big;
		return bitmapInfo;
	}
	return 0;
}

-(UIImage *)YUVtoUIImage:(int)w h:(int)h buffer:(unsigned char *)buffer{
	//YUV(NV12)-->CIImage--->UIImage Conversion
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
	
	
	CVPixelBufferRef pixelBuffer = NULL;
	
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  w,
										  h,
										  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	
	// Here y_ch0 is Y-Plane of YUV(NV12) data.
	unsigned char *y_ch0 = buffer;
	unsigned char *y_ch1 = buffer + w * h;
	memcpy(yDestPlane, y_ch0, w * h);
	unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	
	// Here y_ch1 is UV-Plane of YUV(NV12) data.
	memcpy(uvDestPlane, y_ch1, w * h/2);
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
	// CIImage Conversion
	CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
	
	CIContext *MytemporaryContext = [CIContext contextWithOptions:nil];
	CGImageRef MyvideoImage = [MytemporaryContext createCGImage:coreImage
													   fromRect:CGRectMake(0, 0, w, h)];
	
	// UIImage Conversion
	UIImage *Mynnnimage = [[UIImage alloc] initWithCGImage:MyvideoImage
													 scale:1.0
											   orientation:UIImageOrientationRight];
	
	CVPixelBufferRelease(pixelBuffer);
	CGImageRelease(MyvideoImage);
	
	return Mynnnimage;
}

-(CVPixelBufferRef)createCVPixelBufferRefFromBGRAbuf:(unsigned char *)buffer width:(int)width height:(int)height
{
	CVPixelBufferRef pixelBuffer = NULL;
	
	NSDictionary* option = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
	
	CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)option, &pixelBuffer);
	
	NSParameterAssert(status == kCVReturnSuccess && pixelBuffer != NULL);
	
	CVPixelBufferLockBaseAddress(pixelBuffer, 0);
	
	
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	
	//创建格式爲 kCVPixelFormatType_32ARGB 的 pixelBuffer，创建一个CGContextRef 对象，并将其内部地址设置爲pixelBuffer的内部地址。使用 CGContextDrawImage() 函数将原始图片的数据绘制到我们创建的context上面，完成。
	
	CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
	CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
	
	size_t bitsPerComponent = 8;
	size_t bitsPerPixel = 32;
	size_t bytesPerRow = 4 * width;
	
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, width*height*4, NULL);
	CGImageRef imageRef = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, rgbColorSpace, bitmapInfo, provider, NULL, NO, renderingIntent);
	
	void* pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
	NSParameterAssert(pxdata != NULL);
	NSParameterAssert(pxdata != NULL);
	
	
	CGContextRef context = CGBitmapContextCreate(pxdata,
												 width,
												 height,
												 8,
												 CVPixelBufferGetBytesPerRow(pixelBuffer),
												 rgbColorSpace,
												 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	NSParameterAssert(context);
	CGContextConcatCTM(context, CGAffineTransformIdentity);
	CGContextDrawImage(context, CGRectMake(0,
										   0,
										   width,
										   height),
					   imageRef);
	
//	UIImage *retImage1 = [UIImage imageWithCGImage:imageRef];//测试
	
	CGColorSpaceRelease(rgbColorSpace);
	CGContextRelease(context);
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	return pixelBuffer;
}

-(CVPixelBufferRef)createCVPixelBufferRefFromBGRAbuffer:(unsigned char *)buffer width:(int)w height:(int)h {
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}, (NSString*)kCVPixelBufferBytesPerRowAlignmentKey:@(16)};
	
	CVPixelBufferRef pixelBuffer = NULL;
	int _outWidth = w + (16 - w%16);
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  _outWidth,
										  h,
										  kCVPixelFormatType_32BGRA,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);
	
//	int size = CVPixelBufferGetPlaneCount(pixelBuffer);
	
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	
	void* pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
	memset(pxdata, 0x80, w * h*4);
	long chrominanceWidth0 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
	long chrominanceHeight0 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
	
	for (int row = 0; row < chrominanceHeight0; ++row) {
		memcpy(pxdata + row * (chrominanceWidth0*4),
			   buffer + row * w*4,
			   w*4);
	}
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
	return pixelBuffer;
}

-(CVPixelBufferRef)createCVPixelBufferRefFromYUV420pBuffer:(unsigned char *)buffer width:(int)w height:(int)h {
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
	
	CVPixelBufferRef pixelBuffer = NULL;
	
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  w,
										  h,
										  kCVPixelFormatType_420YpCbCr8PlanarFullRange,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	// Here y_ch0 is Y-Plane of Y(I420/yuv420p) data.
	unsigned char *y_ch0 = buffer;
	memcpy(yDestPlane, y_ch0, w * h);
	
	unsigned char *uDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	// Here y_ch1 is U-Plane of U(I420/yuv420p) data.
	unsigned char *y_ch1 = buffer + w * h;
	memcpy(uDestPlane, y_ch1, w * h/4);
	
	unsigned char *vDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
	// Here y_ch1 is V-Plane of V(I420/yuv420p) data.
	unsigned char *y_ch2 = buffer + w * h;
	memcpy(vDestPlane, y_ch2, w * h/4);
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
	return pixelBuffer;
}
//逐行copy，修复没有16位对齐导致 失真问题；
-(CVPixelBufferRef)AddWatertoCVPixelBufferRefFromNV12buffer:(unsigned char *)buffer width:(int)w height:(int)h {
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}, (NSString*)kCVPixelBufferBytesPerRowAlignmentKey:@(16)};//kCVPixelBufferPlaneAlignmentKey
	
	
	CVPixelBufferRef pixelBuffer = NULL;
	
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  544,
										  h,
										  kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	
	//逐行copy数据
	uint8_t *yDestPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	
	size_t bytesPerRowChrominance0 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
	
	long chrominanceWidth0 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
	long chrominanceHeight0 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
	
	
	memset(yDestPlane, 0x80, chrominanceHeight0 * bytesPerRowChrominance0);
	
	for (int row = 0; row < chrominanceHeight0; ++row) {
		memcpy(yDestPlane + row * bytesPerRowChrominance0,
			   buffer + row * w,
			   w);
	}
	
	//逐行copy数据
	// Chrominance
	uint8_t *uvDestPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	
	size_t bytesPerRowChrominance = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
	
	long chrominanceWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
	long chrominanceHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
	
	
	memset(uvDestPlane, 0x80, chrominanceHeight * bytesPerRowChrominance);
	
	for (int row = 0; row < chrominanceHeight; ++row) {
		memcpy(uvDestPlane + row * bytesPerRowChrominance,
			   buffer +(chrominanceHeight0*w)  + row * w,
			   w);
	}
	
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
	
	
	// CIImage Conversion
	CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
	
	CIContext *MytemporaryContext = [CIContext contextWithOptions:nil];
	CGImageRef MyvideoImage = [MytemporaryContext createCGImage:coreImage
													   fromRect:CGRectMake(0, 0, w, h)];
	
	// UIImage Conversion
	UIImage *Mynnnimage = [[UIImage alloc] initWithCGImage:MyvideoImage
													 scale:1.0
											   orientation:UIImageOrientationRight];
	//
	////	CVPixelBufferRelease(pixelBuffer);
	CGImageRelease(MyvideoImage);
	
	return pixelBuffer;
}

- (void)getDataFromImage:(UIImage*) img
{
	UIImage* _img = [UIImage imageNamed:@"testimg1"];
	CGImageRef imgRef = [_img CGImage];
	CGDataProviderRef provider = CGImageGetDataProvider(imgRef);
	CFDataRef pixelData = CGDataProviderCopyData(provider);
	const uint8_t* data = CFDataGetBytePtr(pixelData);
	
	size_t bitsPerPixel = CGImageGetBitsPerPixel(imgRef);
	NSLog(@"bitsPerPixel:%lu",bitsPerPixel);
	size_t bitsPerComponent = CGImageGetBitsPerComponent(imgRef);
	NSLog(@"bitsPerComponent:%lu",bitsPerComponent);
	
	NSLog(@"\n");
	
	size_t frameWidth = CGImageGetWidth(imgRef);
	NSLog(@"frameWidth:%lu",frameWidth);
	size_t frameHeight = CGImageGetHeight(imgRef);
	NSLog(@"frameHeight:%lu",frameHeight);
	size_t bytesPerRow = CGImageGetBytesPerRow(imgRef);
	NSLog(@"bytesPerRow:%lu ==:%lu",bytesPerRow,bytesPerRow/4);
	
	CFRelease(pixelData);
}

//逐行copy，修复没有16位对齐导致 失真问题；
-(CVPixelBufferRef)createCVPixelBufferRefFromNV12buffer:(unsigned char *)buffer width:(int)w height:(int)h {
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}, (NSString*)kCVPixelBufferBytesPerRowAlignmentKey:@(16)};//kCVPixelBufferPlaneAlignmentKey
	
	//	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
	
	
	CVPixelBufferRef pixelBuffer = NULL;
	int _outWidth = w + (16 - w%16);
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  _outWidth,
										  h,
										  kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	
	//逐行copy数据
	uint8_t *yDestPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	
	size_t bytesPerRowChrominance0 = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
	
	long chrominanceWidth0 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
	long chrominanceHeight0 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
	
	
	memset(yDestPlane, 0x80, chrominanceHeight0 * bytesPerRowChrominance0);
	
	for (int row = 0; row < chrominanceHeight0; ++row) {
		memcpy(yDestPlane + row * bytesPerRowChrominance0,
			   buffer + row * w,
			   w);
	}
	
	//逐行copy数据
	// Chrominance
	uint8_t *uvDestPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	
	size_t bytesPerRowChrominance = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
	
	long chrominanceWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
	long chrominanceHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
	
	
	memset(uvDestPlane, 0x80, chrominanceHeight * bytesPerRowChrominance);
	
	for (int row = 0; row < chrominanceHeight; ++row) {
		memcpy(uvDestPlane + row * bytesPerRowChrominance,
			   buffer +(chrominanceHeight0*w)  + row * w,
			   w);
	}
	
	
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
	
	
	// CIImage Conversion
	CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
	
	CIContext *MytemporaryContext = [CIContext contextWithOptions:nil];
	CGImageRef MyvideoImage = [MytemporaryContext createCGImage:coreImage
													   fromRect:CGRectMake(0, 0, w, h)];
	
	// UIImage Conversion
	UIImage *Mynnnimage = [[UIImage alloc] initWithCGImage:MyvideoImage
													 scale:1.0
											   orientation:UIImageOrientationRight];
	//
	////	CVPixelBufferRelease(pixelBuffer);
	CGImageRelease(MyvideoImage);
	
	return pixelBuffer;
}
//planek copy
-(CVPixelBufferRef)createCVPixelBufferRefFromNV12buffer1:(unsigned char *)buffer width:(int)w height:(int)h {
	NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}, (NSString*)kCVPixelBufferBytesPerRowAlignmentKey:@(16)};//kCVPixelBufferPlaneAlignmentKey
	
	
	CVPixelBufferRef pixelBuffer = NULL;
	
	CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
										  w,
										  h,
										  kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
										  (__bridge CFDictionaryRef)(pixelAttributes),
										  &pixelBuffer);//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
	
	CVPixelBufferLockBaseAddress(pixelBuffer,0);
	unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
	
	// Here y_ch0 is Y-Plane of YUV(NV12) data.
	unsigned char *y_ch0 = buffer;
	memcpy(yDestPlane, y_ch0, w * h);
	unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
	
	// Here y_ch1 is UV-Plane of YUV(NV12) data.
	unsigned char *y_ch1 = buffer + w * h;
	memcpy(uvDestPlane, y_ch1, w * h/2);
	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
	
	if (result != kCVReturnSuccess) {
		NSLog(@"Unable to create cvpixelbuffer %d", result);
	}
	
//	CIImage Conversion
//	CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
//
//	CIContext *MytemporaryContext = [CIContext contextWithOptions:nil];
//	CGImageRef MyvideoImage = [MytemporaryContext createCGImage:coreImage
//													   fromRect:CGRectMake(0, 0, w, h)];
//
//	// UIImage Conversion
//	UIImage *Mynnnimage = [[UIImage alloc] initWithCGImage:MyvideoImage
//													 scale:1.0
//											   orientation:UIImageOrientationRight];
//
//	//	CVPixelBufferRelease(pixelBuffer);
//	CGImageRelease(MyvideoImage);
	
	return pixelBuffer;
}

- (CVPixelBufferRef)CreateNV12CVPixelBufferRefWithRawdata:(uint8_t*) buf withLen:(int)len withWidth:(size_t)width withHeight:(size_t)height withType:(OSType)pixelFormatType
{
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
							 nil];
	
	CVPixelBufferRef pxbuffer = NULL;
	
	size_t frameWidth = width;//640;
	size_t frameHeight = height;//320;
	
	CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
										  frameWidth,
										  frameHeight,
										  pixelFormatType,//kCVPixelFormatType_32ARGB。kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
										  (__bridge CFDictionaryRef) options,
										  &pxbuffer);
	
	NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
	
	CVPixelBufferLockBaseAddress(pxbuffer, 0);
	size_t bytesPerRowChrominance = CVPixelBufferGetBytesPerRowOfPlane(pxbuffer, 1);
	
	//	long chrominaceWith = CVPixelBufferGetWidthOfPlane( pxbuffer, 1);
	long chrominaceHeight = CVPixelBufferGetHeightOfPlane( pxbuffer, 1);
	
	//chrominance
	uint8_t* uvDestPlane = (uint8_t*) CVPixelBufferGetBaseAddressOfPlane(pxbuffer, 1);
	
	memset(uvDestPlane, 0x80, chrominaceHeight * bytesPerRowChrominance);
	
	for (int row = 0; row < chrominaceHeight; ++row)
	{
		memcpy(uvDestPlane + row*bytesPerRowChrominance, (buf + row *frameWidth), frameWidth);
	}
	
	
	void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
	NSParameterAssert(pxdata != NULL);
	
	CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
	
	return pxbuffer;
}

- (CVPixelBufferRef)CVPixelBufferRefFromUiImage:(UIImage *)img
{
	CGImageRef image = [img CGImage];
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
							 nil];
	
	CVPixelBufferRef pxbuffer = NULL;
	
	CGFloat frameWidth = CGImageGetWidth(image);
	CGFloat frameHeight = CGImageGetHeight(image);
	
	CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
										  frameWidth,
										  frameHeight,
										  kCVPixelFormatType_32ARGB,
										  (__bridge CFDictionaryRef) options,
										  &pxbuffer);
	
	NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
	
	CVPixelBufferLockBaseAddress(pxbuffer, 0);
	void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
	NSParameterAssert(pxdata != NULL);
	
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	
	CGContextRef context = CGBitmapContextCreate(pxdata,
												 frameWidth,
												 frameHeight,
												 8,
												 CVPixelBufferGetBytesPerRow(pxbuffer),
												 rgbColorSpace,
												 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
	NSParameterAssert(context);
	CGContextConcatCTM(context, CGAffineTransformIdentity);
	CGContextDrawImage(context, CGRectMake(0,
										   0,
										   frameWidth,
										   frameHeight),
					   image);
	CGColorSpaceRelease(rgbColorSpace);
	CGContextRelease(context);
	
	CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
	
	return pxbuffer;
}

- (CMSampleBufferRef)createAudioSampleBuffer:(char*) buf withLen:(int) len withASBD:(AudioStreamBasicDescription) asbd{
	
	AudioBufferList audioData;
	audioData.mNumberBuffers = 1;
	char* tmp = malloc(len);
	memcpy(tmp, buf, len);
	
	audioData.mBuffers[0].mData = tmp;
	audioData.mBuffers[0].mNumberChannels = asbd.mChannelsPerFrame;
	audioData.mBuffers[0].mDataByteSize = len;
	
	
	CMSampleBufferRef buff = NULL;
	CMFormatDescriptionRef format =NULL;
	OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd,0, NULL, 0, NULL, NULL, &format);
	
	if (status) {
		return nil;
	}
	CMSampleTimingInfo timing = {CMTimeMake(asbd.mFramesPerPacket,asbd.mSampleRate), kCMTimeZero, kCMTimeInvalid };
	
	
	status = CMSampleBufferCreate(kCFAllocatorDefault,NULL, false,NULL, NULL, format, (CMItemCount)asbd.mFramesPerPacket,1, &timing, 0,NULL, &buff);
	
	if (status) { //失败
		return nil;
	}
	
	status = CMSampleBufferSetDataBufferFromAudioBufferList(buff,kCFAllocatorDefault,kCFAllocatorDefault,0, &audioData);
	
	if (tmp) {
		free(tmp);
	}
	CFRelease(format);
	
	return buff;
}

- (CVPixelBufferRef)CVPixelBufferRefFromUiImage1:(UIImage *)img
{
	CGSize size = img.size;
	CGImageRef image = [img CGImage];
	OSType pixelFormat = kCVPixelFormatType_32BGRA;
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
	CVPixelBufferRef pxbuffer = NULL;
	CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, pixelFormat, (__bridge CFDictionaryRef) options, &pxbuffer);
	
	NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
	
	CVPixelBufferLockBaseAddress(pxbuffer, 0);
	void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
	NSParameterAssert(pxdata != NULL);
	
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	
	//CGBitmapInfo的设置
	//uint32_t bitmapInfo = CGImageAlphaInfo | CGBitmapInfo;
	
	//当inputPixelFormat=kCVPixelFormatType_32BGRA CGBitmapInfo的正确的设置
	//uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
	//uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
	
	//当inputPixelFormat=kCVPixelFormatType_32ARGB CGBitmapInfo的正确的设置
	//uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big;
	//uint32_t bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Big;
	
	uint32_t bitmapInfo = [self bitmapInfoWithPixelFormatType:pixelFormat];
	
	CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4*size.width, rgbColorSpace, bitmapInfo);
	NSParameterAssert(context);
	
	CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
	CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
	
	CGColorSpaceRelease(rgbColorSpace);
	CGContextRelease(context);
	
	return pxbuffer;
}



@end
