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
    NSLog(@"1 Grap pixel data ...");
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bitsPerComponent = 8;
    
    CGImageRef imgRef = self.imageView.image.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
    NSUInteger imgPixelCount = imgWidth * imgHeight;
    NSUInteger imgByteCount = imgPixelCount * bytesPerPixel;
    NSLog(@"  img size: %i x %i", imgWidth, imgHeight);
    NSLog(@"    pixels: %i", imgPixelCount);
    NSLog(@"     bytes: %i", imgByteCount);
    
    // char not int -- to get each channel instead of the entire pixel
    char *rawPixels = (char*)calloc(imgByteCount, sizeof(char));
    NSUInteger bytesPerRow = bytesPerPixel * imgWidth;
    NSLog(@"  Bytes per row: %i", bytesPerRow);
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
    
    NSLog(@"2 Process pixel data ...");
    NSLog(@"  Prepare data structures");
    
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

    NSLog(@"  New size: %i x %i", imgNewWidth, imgNewHeight);
    NSLog(@"    pixels: %i", imgNewPixelCount);
    NSLog(@"     bytes: %i", imgNewByteCount);
    
    if (imgWidthInt > imgHeightInt) {
        NSLog(@"  Make C call (vertical)");
        carveSeamsVertical(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight);
    } else {
        NSLog(@"  Make C call (horizontal)");
        carveSeamsHorizontal(rawPixels, imgWidthInt, imgHeightInt, rawResults, imgNewWidth, imgNewHeight);
    }
    free(rawPixels);
    
    NSLog(@"3 Return Processed data ...");
    NSLog(@"  Prepare data structures");
    
    NSUInteger newBytesPerRow = bytesPerPixel * imgNewWidth;
    NSLog(@"  Bytes per row: %i", bytesPerRow);
    CGColorSpaceRef newColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(rawResults, imgNewWidth, imgNewHeight,
                                                 bitsPerComponent, newBytesPerRow, newColorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(newColorSpace);
    free(rawResults);
    
    NSLog(@"  Display new image");
    if (newContext) {
        CGImageRef newImgRef = CGBitmapContextCreateImage(newContext);
        CGContextRelease(newContext);
        
        //UIImage *oldImage = self.imageView.image;
        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
        self.imageView.image = newImage;
        //[self.imageView setImage:newImage];
        //self.imageView.image = [UIImage imageWithCGImage:newImgRef];
    }
    
    NSLog(@"4 Done");
}

@end
