//
//  ImageUtils.m
//  Squared
//
//  Created by Christopher Stoll on 1/1/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import "ImageUtils.h"

@implementation ImageUtils

// calculate the size of an image set to aspect-fit
+ (CGRect)getDisplaySizeOfImageView:(UIImageView *)imageView
{
    CGRect results = CGRectZero;
    CGSize imageSize = imageView.image.size;
    CGSize frameSize = imageView.frame.size;
    //if ((imageSize.width < frameSize.width) && (imageSize.height < frameSize.height)) {
    //    results.size = imageSize;
    //} else {
    CGFloat widthRatio = imageSize.width / frameSize.width;
    CGFloat heightRatio = imageSize.height / frameSize.height;
    CGFloat maxRatio = MAX(widthRatio, heightRatio);
    
    results.size.width = roundf(imageSize.width / maxRatio);
    results.size.height = roundf(imageSize.height / maxRatio);
    //}
    results.origin.x = roundf(imageView.center.x - (results.size.width / 2));
    results.origin.y = roundf(imageView.center.y - (results.size.height / 2));
    return results;
}

+ (UIImage *)rotateImage:(UIImage*)image byOrientation:(UIImageOrientation)orientation
{
    UIImage *newImage;
    CGSize size = image.size;
    UIGraphicsBeginImageContext(CGSizeMake(size.height, size.width));
    [[UIImage imageWithCGImage:[image CGImage] scale:image.scale orientation:orientation] drawInRect:CGRectMake(0, 0, size.height ,size.width)];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
