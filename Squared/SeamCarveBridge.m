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
#import "SquaredDefines.h"
#import "SeamCarve.h"

@implementation SeamCarveBridge

// TODO: move to it's own class? (Otherwise this becomes a generic "utility class")
//
// REF: http://maniacdev.com/2011/11/tutorial-easy-face-detection-with-core-image-in-ios-5
//
+ (NSArray *)findFaces:(UIImage *)sourceImage {
    CIImage *image = [CIImage imageWithCGImage:sourceImage.CGImage];
    // TODO: Consider changing CIDetectorAccuracyLow to CIDetectorAccuracyLow
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:[NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy]];
    return [detector featuresInImage:image];
}

+ (void)squareImage:(UIImage *)sourceImage withMask:(UIImage *)sourceImageMask {
    //NSUserDefaults *squaredDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
    
    int seamCutsPerItteration = CUTS_PER_ITTERATION_DEFAULT;
    if ([squaredDefaults integerForKey:@"cutsPerItteration"]) {
        seamCutsPerItteration = (int)((CUTS_PER_ITTERATION_BASEVALUE - (int)[squaredDefaults integerForKey:@"cutsPerItteration"]) * CUTS_PER_ITTERATION_MULTIPLIER);
    }
    
    int padMode = 0;
    int padWithColor = 0;
    int padWithColorR = 0;
    int padWithColorG = 0;
    int padWithColorB = 0;
    int padWithColorA = 0;
    if ([squaredDefaults integerForKey:@"padSquareColor"]) {
        padWithColor = (int)[squaredDefaults integerForKey:@"padSquareColor"];
        
        if (padWithColor) {
            if (padWithColor == 1) { // single color average
                padMode = PAD_MODE_COLOR;
            } else if (padWithColor == 2) { // double color average
                padMode = PAD_MODE_COLORS;
            } else if (padWithColor == 3) { // transparent
                padMode = PAD_MODE_CLEAR;
            } else if (padWithColor == 4) { // mirror
                padMode = PAD_MODE_MIRROR;
            } else if (padWithColor == 5) { // smear
                padMode = PAD_MODE_SMEAR;
            } else if (padWithColor == 6) { // black
                padMode = PAD_MODE_BLACK;
                padWithColorA = 255;
            } else if (padWithColor == 7) { // white
                padMode = PAD_MODE_WHITE;
                padWithColorR = 255;
                padWithColorG = 255;
                padWithColorB = 255;
                padWithColorA = 255;
            }
        }
    }
    
    CGImageRef imgRef = sourceImage.CGImage;
    CGImageRef imgRefMask = sourceImageMask.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
    
    // TODO: this shouldn't be hard-coded
    NSUInteger bytesPerPixel = 4; //CGImageGetBitsPerPixel(sourceImage.CGImage) / 16;
    NSUInteger bitsPerComponent = CGImageGetBitsPerComponent(sourceImage.CGImage); // 8;
    
    NSUInteger imgPixelCount = imgWidth * imgHeight;
    NSUInteger imgByteCount = imgPixelCount * bytesPerPixel;
    
    // char not int -- to get each channel instead of the entire pixel
    unsigned char *rawPixels = (unsigned char*)calloc(imgByteCount, sizeof(unsigned char));
    unsigned char *rawPixelsMask = (unsigned char*)calloc(imgByteCount, sizeof(unsigned char));
    NSUInteger bytesPerRow = bytesPerPixel * imgWidth;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rawPixels, imgWidth, imgHeight,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextRef contextMask = CGBitmapContextCreate(rawPixelsMask, imgWidth, imgHeight,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, imgWidth, imgHeight), imgRef);
        CGContextRelease(context);
        // This causes zombies which when released result in bad access errors
        //CGImageRelease(imgRef);
    } else {
        if (contextMask) {
            CGContextRelease(contextMask);
        }
        // There is a problem with the context, so we will not be able to process anything
        // The most likely cause is that there was no image data provided
        // TODO: imporve error handling (below also)
        return;
    }
    if (contextMask) {
        CGContextDrawImage(contextMask, CGRectMake(0, 0, imgWidth, imgHeight), imgRefMask);
        CGContextRelease(contextMask);
    } else {
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
    unsigned int widthIncrement = 0;
    unsigned int heightIncrement = 0;
    unsigned int seamRemovalCount = 0;
    unsigned int seamRemovalItterations = 0;
    unsigned int pixelDepth = (unsigned int)bytesPerPixel;
    if (imgWidthInt > imgHeightInt) {
        imgNewWidth = imgHeightInt;
        imgNewHeight = imgHeightInt;
        widthIncrement = seamCutsPerItteration;
        heightIncrement = 0;
        seamRemovalCount = imgWidthInt - imgHeightInt;
        seamRemovalItterations = (int)(seamRemovalCount / seamCutsPerItteration) + 1;
    }
    
    NSUInteger imgNewPixelCount = imgNewWidth * imgNewHeight;
    NSUInteger imgNewByteCount = imgNewPixelCount * bytesPerPixel;
    unsigned char *rawResults;
    if (imgNewByteCount) {
        rawResults = (unsigned char*)calloc(imgNewByteCount, sizeof(unsigned char));
    } else {
        free(faceCoordinates);
        return;
    }
    
    unsigned int currentWidthT = imgWidthInt;
    unsigned int currentHeightT = imgHeightInt;
    struct Pixel *imagePixels = createImageData(rawPixels, imgWidthInt, imgHeightInt, pixelDepth, rawPixelsMask, faceCount, faceCoordinates);
    
    int imageShowModulus = 0;
    int imageShowModulusTwo = 0;
    if (seamRemovalItterations > MAX_ITTERATION_IMAGES_TO_SHOW) {
        if (seamRemovalItterations < (MAX_ITTERATION_IMAGES_TO_SHOW * 2)) {
            imageShowModulus = (int)(seamRemovalItterations / (seamRemovalItterations - MAX_ITTERATION_IMAGES_TO_SHOW)) + 1;
        } else {
            imageShowModulusTwo = (int)(seamRemovalItterations / MAX_ITTERATION_IMAGES_TO_SHOW);
            imageShowModulus = 0;
        }
    }
    
    // if we are using padding then perform a pre-pass to get a border for the original image
    int performPrePass = 0;
    if (padWithColor) {
        performPrePass = 1;
    }
    
    for (int i = 0; i < seamRemovalItterations; ++i) {
        if (i < (seamRemovalItterations - 1)) {
            unsigned char *rawResultsTemp;
            if (!performPrePass) {
                currentWidthT = currentWidthT - widthIncrement;
                currentHeightT = currentHeightT - heightIncrement;
                
                if (!padWithColor) {
                    rawResultsTemp = (unsigned char*)calloc(currentWidthT * currentHeightT * bytesPerPixel, sizeof(unsigned char));
                } else {
                    rawResultsTemp = (unsigned char*)calloc(currentWidthT * currentWidthT * bytesPerPixel, sizeof(unsigned char));
                }
                
                carveSeamsVertical(imagePixels, imgWidthInt, imgHeightInt, rawResultsTemp, currentWidthT, currentHeightT, pixelDepth, seamCutsPerItteration, padMode, padWithColorR, padWithColorG, padWithColorB, padWithColorA);
                
            } else {
                //
                // If the image has padding then we need to run a pre-pass to add a border to the unprocessed image
                // not doing this causes a jarring UI when the images are unsquared using the pinch gesture
                //
                rawResultsTemp = (unsigned char*)calloc(currentWidthT * currentWidthT * bytesPerPixel, sizeof(unsigned char));
                carveSeamsVertical(imagePixels, imgWidthInt, imgHeightInt, rawResultsTemp, currentWidthT, currentHeightT, pixelDepth, 0, padMode, padWithColorR, padWithColorG, padWithColorB, padWithColorA);
                performPrePass = 0;
                --i;
            }
            
            if (!imageShowModulus || (i % imageShowModulus)) {
                if (!imageShowModulusTwo || !(i % imageShowModulusTwo)) {
                    NSUInteger newBytesPerRow = bytesPerPixel * currentWidthT;
                    CGColorSpaceRef newColorSpace = CGColorSpaceCreateDeviceRGB();
                    CGContextRef newContext;
                    if (!padWithColor) {
                        newContext = CGBitmapContextCreate(rawResultsTemp, currentWidthT, currentHeightT,
                                                           bitsPerComponent, newBytesPerRow, newColorSpace,
                                                           kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
                    } else {
                        newContext = CGBitmapContextCreate(rawResultsTemp, currentWidthT, currentWidthT,
                                                           bitsPerComponent, newBytesPerRow, newColorSpace,
                                                           kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
                    }
                    CGColorSpaceRelease(newColorSpace);
                    
                    if (newContext) {
                        CGImageRef newImgRef = CGBitmapContextCreateImage(newContext);
                        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
                        if (i >= 0) {
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.squareupdate" object:newImage];
                        } else {
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.squaretransition" object:newImage];
                        }
                        CGContextRelease(newContext);
                        CGImageRelease(newImgRef);
                    }
                }
            }
            
            free(rawResultsTemp);
        } else {
            carveSeamsVertical(imagePixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight, pixelDepth, (currentWidthT - imgNewWidth), padMode, padWithColorR, padWithColorG, padWithColorB, padWithColorA);
        }
    }
    
    free(imagePixels);
    free(faceCoordinates);
    free(rawPixelsMask);
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
