//
//  ViewController.m
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "ViewController.h"
#import "SeamCarveBridge.h"

@interface ViewController ()

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    
    [self.squareButton setEnabled:NO];
    [self.saveButton setEnabled:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    // TODO: move to bridge class
    if (img) {
        if ((img.size.height > MAXIMUM_IMAGE_SIZE) || (img.size.width > MAXIMUM_IMAGE_SIZE)) {
            int temp = 0.0;
            float newWidth = 0;
            float newHeight = 0;
            
            if (img.size.height > img.size.width) {
                temp = img.size.width * MAXIMUM_IMAGE_SIZE / img.size.height;
                newWidth = temp;
                newHeight = MAXIMUM_IMAGE_SIZE;
            } else {
                temp = img.size.height * MAXIMUM_IMAGE_SIZE / img.size.width;
                newWidth = MAXIMUM_IMAGE_SIZE;
                newHeight = temp;
            }
            
            CGSize newSize = CGSizeMake(newWidth, newHeight);
            UIGraphicsBeginImageContext(newSize);
            //UIGraphicsBeginImageContextWithOptions(newSize, 1.0f, 0.0f);
            [img drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            self.imageView.image = newImage;
        } else {
            self.imageView.image = img;
        }
        [self.squareButton setEnabled:YES];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Squaring methods

- (void)squareImageBegin {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SeamCarveBridge squareImage:self.imageView.image];
    });
    [self disableUIelements];
}

- (void)squareImageComplete:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = [notification object];
        [self enableUIelements];
    });
}

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
    [self squareImageBegin];
}

- (IBAction)doSaving:(id)sender {
    UIImage *imagetoshare = self.imageView.image;
    NSArray *activityItems = @[imagetoshare];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

@end
