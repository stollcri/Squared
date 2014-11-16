//
//  PhotoEditingViewController.m
//  Squared Extension
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import "PhotoEditingViewController.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import "SeamCarveBridge.h"


@interface PhotoEditingViewController () <PHContentEditingController>
@property (strong) PHContentEditingInput *input;
@property BOOL squaringComplete;
@end

@implementation PhotoEditingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - PHContentEditingController

- (BOOL)canHandleAdjustmentData:(PHAdjustmentData *)adjustmentData {
    // Inspect the adjustmentData to determine whether your extension can work with past edits.
    // (Typically, you use its formatIdentifier and formatVersion properties to do this.)
    return NO;
}

- (void)startContentEditingWithInput:(PHContentEditingInput *)contentEditingInput placeholderImage:(UIImage *)placeholderImage {
    // Present content for editing, and keep the contentEditingInput for use when closing the edit session.
    // If you returned YES from canHandleAdjustmentData:, contentEditingInput has the original image and adjustment data.
    // If you returned NO, the contentEditingInput has past edits "baked in".
    self.input = contentEditingInput;
    NSURL *currentImageURL = self.input.fullSizeImageURL;
    [self loadImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:currentImageURL]]];
}

- (void)finishContentEditingWithCompletionHandler:(void (^)(PHContentEditingOutput *))completionHandler {
    // Update UI to reflect that editing has finished and output is being rendered.
    
    // Render and provide output on a background queue.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create editing output from the editing input.
        PHContentEditingOutput *output = [[PHContentEditingOutput alloc] initWithContentEditingInput:self.input];
        
        // Provide new adjustments and render output to given location.
        // output.adjustmentData = <#new adjustment data#>;
        // NSData *renderedJPEGData = <#output JPEG#>;
        // [renderedJPEGData writeToURL:output.renderedContentURL atomically:YES];
        
        PHAdjustmentData *adjustData = [[PHAdjustmentData alloc] initWithFormatIdentifier:@"org.christopherstoll.squared" formatVersion:@"0.1" data:nil];
        output.adjustmentData = adjustData;
        NSData *imageData = UIImageJPEGRepresentation(self.imageView.image, 1.0f); // UIImagePNGRepresentation(self.imageView.image);
        [imageData writeToURL:output.renderedContentURL atomically:YES];
        
        // Call completion handler to commit edit to Photos.
        completionHandler(output);
        
        // Clean up temporary files, etc.
    });
}

- (BOOL)shouldShowCancelConfirmation {
    // Returns whether a confirmation to discard changes should be shown to the user on cancel.
    // (Typically, you should return YES if there are any unsaved changes.)
    //return NO;
    return self.squaringComplete;
}

- (void)cancelContentEditing {
    // Clean up temporary files, etc.
    // May be called after finishContentEditingWithCompletionHandler: while you prepare output.
}

#pragma mark - Squaring methods

- (void)squareImageBegin {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SeamCarveBridge squareImage:self.imageView.image];
    });
    [self disableUIelements];
}

- (void)squareImageComplete:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^(){
        self.imageView.image = [notification object];
        self.squaringComplete = YES;
        [self enableUIelements];
    });
}

#pragma mark - UI Actions

- (void)loadImage:(UIImage *)img {
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
    }
}

- (void)disableUIelements {
    [self.squareButton setEnabled:NO];
    
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
}

- (void)enableUIelements {
    [self.activityIndicator stopAnimating];
    
    NSValue *animationDurationValue = @0.2;
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    self.imageView.alpha = 1.0;
    [UIView commitAnimations];
    
    [self.squareButton setEnabled:YES];
}

#pragma mark - UI Interactions

- (IBAction)doSquaring:(id)sender {
    [self squareImageBegin];
}

@end
