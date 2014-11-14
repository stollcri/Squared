//
//  SeamCarveBridge.m
//  Squared
//
//  Created by Christopher Stoll on 11/13/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "SeamCarveBridge.h"
#import "SeamCarve.h"

@implementation SeamCarveBridge

+ (void)squareImage:(UIImage *)sourceImage {
    NSUInteger bytesPerPixel = 4;
    NSUInteger bitsPerComponent = 8;
    
    //CGImageRef imgRef = self.imageView.image.CGImage;
    CGImageRef imgRef = sourceImage.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
    NSUInteger imgPixelCount = imgWidth * imgHeight;
    NSUInteger imgByteCount = imgPixelCount * bytesPerPixel;
    NSLog(@"size: %lu x %lu", (unsigned long)imgWidth, (unsigned long)imgHeight);
    NSLog(@"pixels: %lu", (unsigned long)imgPixelCount);
    NSLog(@"bytes: %lu", (unsigned long)imgByteCount);
    NSLog(@"seams: %ld", (long)(imgWidth - imgHeight));
    
    // char not int -- to get each channel instead of the entire pixel
    unsigned char *rawPixels = (unsigned char*)calloc(imgByteCount, sizeof(unsigned char));
    NSUInteger bytesPerRow = bytesPerPixel * imgWidth;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rawPixels, imgWidth, imgHeight,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, imgWidth, imgHeight), imgRef);
        CGContextRelease(context);
        // This causes zombies which when released result in bad access errors
        //CGImageRelease(imgRef);
    } else {
        // There is a problem with the context, so we will not be able to process anything
        // The most likely cause is that there was no image data provided
        // TODO: imporve error handling
        return;
    }
    
    unsigned int imgWidthInt = (unsigned int)imgWidth;
    unsigned int imgHeightInt = (unsigned int)imgHeight;
    unsigned int imgNewWidth = 0;
    unsigned int imgNewHeight = 0;
    if (imgWidthInt > imgHeightInt) {
        imgNewWidth = imgHeightInt;
        //imgNewWidth = imgWidthInt; // TODO: fix
        imgNewHeight = imgHeightInt;
    } else {
        imgNewWidth = imgWidthInt;
        imgNewHeight = imgWidthInt;
        //imgNewHeight = imgHeightInt; // TODO: fix
    }
    NSUInteger imgNewPixelCount = imgNewWidth * imgNewHeight;
    NSUInteger imgNewByteCount = imgNewPixelCount * bytesPerPixel;
    unsigned char *rawResults = (unsigned char*)calloc(imgNewByteCount, sizeof(unsigned char));
    
    // TODO: use blocks to get a background thread
    if (imgWidthInt > imgHeightInt) {
        carveSeamsVertical(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight);
    } else {
        carveSeamsHorizontal(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight);
    }
    free(rawPixels);
    
    NSUInteger newBytesPerRow = bytesPerPixel * imgNewWidth;
    CGColorSpaceRef newColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(rawResults, imgNewWidth, imgNewHeight,
                                                    bitsPerComponent, newBytesPerRow, newColorSpace,
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(newColorSpace);
    free(rawResults);
    
    if (newContext) {
        //
        // TODO: Fix this error
        // CASMBA.local Squared[86652] <Error>: copy_read_only: vm_copy failed: status 1.
        // it seems to happen after 4 or 5 runs of the algorithm
        //
        // http://stackoverflow.com/questions/13100078/ios-crash-cgdataprovidercreatewithcopyofdata-vm-copy-failed-status-1
        //
        CGImageRef newImgRef = CGBitmapContextCreateImage(newContext);
        CGContextRelease(newContext);
        
        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.squarecomplete" object:newImage];
    }
}

@end
