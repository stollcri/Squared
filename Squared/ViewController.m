//
//  ViewController.m
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import "ViewController.h"
#import "SeamCarve.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    if (img) {
        self.imageView.image = img;
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)buttonTouched:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = @[(NSString *) kUTTypeImage];
    imagePicker.allowsEditing = NO;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (IBAction)doSquaring:(id)sender {
    NSUInteger bytesPerPixel = 4;
    NSUInteger bitsPerComponent = 8;
    
    CGImageRef imgRef = self.imageView.image.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
    NSUInteger imgPixelCount = imgWidth * imgHeight;
    NSUInteger imgByteCount = imgPixelCount * bytesPerPixel;
    
    // char not int -- to get each channel instead of the entire pixel
    char *rawPixels = (char*)calloc(imgByteCount, sizeof(char));
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
    
    unsigned int imgWidthInt = imgWidth;
    unsigned int imgHeightInt = imgHeight;
    unsigned int imgNewWidth = 0;
    unsigned int imgNewHeight = 0;
    if (imgWidthInt > imgHeightInt) {
        imgNewWidth = imgHeightInt;
        //imgNewWidth = imgWidthInt;
        imgNewHeight = imgHeightInt;
    } else {
        imgNewWidth = imgWidthInt;
        imgNewHeight = imgWidthInt;
        //imgNewHeight = imgHeightInt;
    }
    NSUInteger imgNewPixelCount = imgNewWidth * imgNewHeight;
    NSUInteger imgNewByteCount = imgNewPixelCount * bytesPerPixel;
    char *rawResults = (char*)calloc(imgNewByteCount, sizeof(char));
    
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
        CGImageRef newImgRef = CGBitmapContextCreateImage(newContext);
        CGContextRelease(newContext);
        
        //UIImage *oldImage = self.imageView.image;
        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
        self.imageView.image = newImage;
        //[self.imageView setImage:newImage];
        //self.imageView.image = [UIImage imageWithCGImage:newImgRef];
    }
}

@end
