//
//  ImageUtils.h
//  Squared
//
//  Created by Christopher Stoll on 1/1/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageUtils : NSObject

+ (CGRect)getDisplaySizeOfImageView:(UIImageView *)imageView;
+ (UIImage *)rotateImage:(UIImage*)image byOrientation:(UIImageOrientation)orientation;

@end
