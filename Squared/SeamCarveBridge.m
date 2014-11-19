//
//  SeamCarveBridge.m
//  Squared
//
//  Created by Christopher Stoll on 11/13/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import "SeamCarveBridge.h"
#import "SeamCarve.h"

@implementation SeamCarveBridge

// TODO: move to it's own class? (Otherwise this becomes a generic "utility class")
//
// REF: http://maniacdev.com/2011/11/tutorial-easy-face-detection-with-core-image-in-ios-5
//
+ (NSArray *)findFaces:(UIImage *)sourceImage {
    CIImage *image = [CIImage imageWithCGImage:sourceImage.CGImage];
    // TODO: Consider changing CIDetectorAccuracyLow to CIDetectorAccuracyHigh
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:[NSDictionary dictionaryWithObject:CIDetectorAccuracyLow forKey:CIDetectorAccuracy]];
    return [detector featuresInImage:image];
}

+ (void)squareImage:(UIImage *)sourceImage {
    CGImageRef imgRef = sourceImage.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
    //NSLog(@"%lu x %lu", (unsigned long)imgWidth, (unsigned long)imgHeight);
    
    // TODO: this shouldn't be hard-coded
    NSUInteger bytesPerPixel = 4; //CGImageGetBitsPerPixel(sourceImage.CGImage) / 16;
    NSUInteger bitsPerComponent = CGImageGetBitsPerComponent(sourceImage.CGImage); // 8;
    
    NSUInteger imgPixelCount = imgWidth * imgHeight;
    NSUInteger imgByteCount = imgPixelCount * bytesPerPixel;
    
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
    
    // check if the image contains any faces
    NSArray *faceBounds = [SeamCarveBridge findFaces:sourceImage];
    int faceCount = (int)faceBounds.count;
    int *faceCoordinates = (int*)calloc((faceBounds.count * 4), sizeof(int));
    
    // build c data structures for face information
    if (faceCount > 0) {
        int faceCoordCount = 0;
        for (CIFaceFeature *faceFeature in faceBounds) {
            faceCoordinates[faceCoordCount] = (int)faceFeature.bounds.origin.x;
            ++faceCoordCount;
            
            faceCoordinates[faceCoordCount] = (int)faceFeature.bounds.origin.y;
            ++faceCoordCount;
            
            faceCoordinates[faceCoordCount] = (int)faceFeature.bounds.size.width;
            ++faceCoordCount;
            
            faceCoordinates[faceCoordCount] = (int)faceFeature.bounds.size.height;
            ++faceCoordCount;
        }
    }
    
    unsigned int imgWidthInt = (unsigned int)imgWidth;
    unsigned int imgHeightInt = (unsigned int)imgHeight;
    unsigned int imgNewWidth = 0;
    unsigned int imgNewHeight = 0;
    unsigned int pixelDepth = (unsigned int)bytesPerPixel;
    if (imgWidthInt > imgHeightInt) {
        imgNewWidth = imgHeightInt;
        imgNewHeight = imgHeightInt;
    } else {
        imgNewWidth = imgWidthInt;
        imgNewHeight = imgWidthInt;
    }
    NSUInteger imgNewPixelCount = imgNewWidth * imgNewHeight;
    NSUInteger imgNewByteCount = imgNewPixelCount * bytesPerPixel;
    unsigned char *rawResults = (unsigned char*)calloc(imgNewByteCount, sizeof(unsigned char));
    
    if (imgWidthInt > imgHeightInt) {
        carveSeamsVertical(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight, pixelDepth, faceCount, faceCoordinates);
    } else {
        carveSeamsHorizontal(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight, pixelDepth, faceCount, faceCoordinates);
    }
    free(faceCoordinates);
    free(rawPixels);
    
    NSUInteger newBytesPerRow = bytesPerPixel * imgNewWidth;
    CGColorSpaceRef newColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(rawResults, imgNewWidth, imgNewHeight,
                                                    bitsPerComponent, newBytesPerRow, newColorSpace,
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(newColorSpace);
    
    if (newContext) {
        CGImageRef newImgRef = CGBitmapContextCreateImage(newContext);
        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.squarecomplete" object:newImage];
        CGContextRelease(newContext);
        CGImageRelease(newImgRef);
    }
    free(rawResults);
}

@end
