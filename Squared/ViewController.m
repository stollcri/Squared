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
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    
    [self.squareButton setEnabled:NO];
    [self.saveButton setEnabled:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:@"org.christopherstoll.squared.squarecomplete" object:nil];
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
        [self.squareButton setEnabled:YES];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Squaring methods

- (void)squareImage {
    NSUInteger bytesPerPixel = 4;
    NSUInteger bitsPerComponent = 8;
    
    CGImageRef imgRef = self.imageView.image.CGImage;
    NSUInteger imgWidth = CGImageGetWidth(imgRef);
    NSUInteger imgHeight = CGImageGetHeight(imgRef);
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
    
    unsigned int imgWidthInt = (unsigned int)imgWidth;
    unsigned int imgHeightInt = (unsigned int)imgHeight;
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
        
        // TODO: don't update the UI this way, find something better
        UIImage *newImage = [UIImage imageWithCGImage:newImgRef];
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.imageView.image = newImage;
            [self enableUIelements];
        });
    }
    
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.squarecomplete" object:self];
}

/*
- (void)squareImageComplete:(NSNotification *)notification {
}
*/

#pragma mark - UI Actions

- (void)disableUIelements {
    [self.openButton setEnabled:NO];
    [self.squareButton setEnabled:NO];
    [self.saveButton setEnabled:NO];
    
    //
    // Go out slowly since this will take some time
    //
    
    self.activityIndicator.alpha = 0.2;
    [self.activityIndicator startAnimating];
    
    NSValue *animationDurationValue = @0.8;
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    self.imageView.alpha = 0.2;
    self.activityIndicator.alpha = 1.0;
    [UIView commitAnimations];
    
    // alternative method for animation
    //[UIView animateWithDuration:animationDuration delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
    //    self.imageView.alpha = 0.25;
    //} completion: nil];
}

- (void)enableUIelements {
    [self.activityIndicator stopAnimating];
    
    //
    // Return quickly
    //
    
    NSValue *animationDurationValue = @0.2;
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    self.imageView.alpha = 1.0;
    [UIView commitAnimations];
    
    [self.openButton setEnabled:YES];
    [self.squareButton setEnabled:YES];
    [self.saveButton setEnabled:YES];
}

#pragma mark - UI Interactions

- (IBAction)doOpen:(id)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = @[(NSString *) kUTTypeImage];
    imagePicker.allowsEditing = NO;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (IBAction)doSquaring:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self squareImage];
    });
    [self disableUIelements];
}

- (IBAction)doSaving:(id)sender {
    UIImage *imagetoshare = self.imageView.image;
    NSArray *activityItems = @[imagetoshare];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

@end
