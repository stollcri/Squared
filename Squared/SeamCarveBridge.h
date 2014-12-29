//
//  SeamCarveBridge.h
//  Squared
//
//  Created by Christopher Stoll on 11/13/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define MAXIMUM_IMAGE_SIZE 1280
#define CUTS_PER_ITTERATION_MULTIPLIER 4
#define MAX_ITTERATION_IMAGES_TO_SHOW 18

@interface SeamCarveBridge : NSObject

+ (void)squareImage:(UIImage *)sourceImage withMask:(UIImage *)sourceImageMask;
+ (NSArray *)findFaces:(UIImage *)sourceImage;

@end
