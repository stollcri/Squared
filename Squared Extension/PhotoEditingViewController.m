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
#import "SquaredDefines.h"
#import "UserDefaultsUtils.h"
#import "SeamCarveBridge.h"


@interface PhotoEditingViewController () <PHContentEditingController>

@property (strong) PHContentEditingInput *input;
@property NSURL *currentImageURL;

@property BOOL squaringComplete;
@property BOOL wasRotated;
@property BOOL hasMaskData;

@property BOOL mouseSwiped;
@property CGPoint lastPoint;
@property PaintMode paintMode;
@property CGFloat paintColorR;
@property CGFloat paintColorG;
@property CGFloat paintColorB;
@property UIImageView *paintImageView;

@property NSInteger padMode;
@property NSMutableArray *imageStages;
@property NSInteger currentImageStage;

@property BOOL watermark;
@property UIImageView *logoImageView;

@end

@implementation PhotoEditingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
    if (![squaredDefaults integerForKey:@"cutsPerItteration"]) {
        NSURL *settingsBundleURL = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"bundle"];
        NSDictionary *appDefaults = [UserDefaultsUtils loadDefaultsFromSettingsPage:@"Root.plist" inSettingsBundleAtURL:settingsBundleURL];
        //[[[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME] registerDefaults:appDefaults];
        //[[[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME] synchronize];
        [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    self.wasRotated = NO;
    self.paintMode = PaintModeNone;
    self.currentImageStage = -1;
    self.watermark = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageUpdate:) name:@"org.christopherstoll.squared.squareupdate" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageBorderTransition:) name:@"org.christopherstoll.squared.squaretransition" object:nil];
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
    self.currentImageURL = self.input.fullSizeImageURL;
    [self loadImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:self.currentImageURL]]];
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
        
        UIImage *imagetoshare;
        if (self.watermark) {
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(tmp.size.width, tmp.size.height), YES, 0.0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            UIGraphicsPushContext(context);
            [self.imageView.image drawInRect:CGRectMake(0, 0, tmp.size.width, tmp.size.height)];
            [self.logoImageView.image drawInRect:CGRectMake(0, (tmp.size.height - self.logoImageView.image.size.height), self.logoImageView.image.size.width, self.logoImageView.image.size.height)];
            UIGraphicsPopContext();
            imagetoshare = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        } else {
            imagetoshare = self.imageView.image;
        }
        
        NSData *imageData = UIImageJPEGRepresentation(imagetoshare, 1.0f); // UIImagePNGRepresentation(self.imageView.image);
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

#pragma mark - Utilities

- (void)loadImage:(UIImage *)img {
    // TODO: move to bridge class
    if (img) {
        NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
        int maximumSize = MAXIMUM_SIZE_DEFAULT;
        if ([squaredDefaults integerForKey:@"maximumSize"]) {
            maximumSize = (int)([squaredDefaults integerForKey:@"maximumSize"] * MAXIMUM_SIZE_MULTIPLIER) + MAXIMUM_SIZE_BASEVALUE;
        }
        
        CGSize newSize;
        if ((img.size.height > maximumSize) || (img.size.width > maximumSize)) {
            int temp = 0.0;
            float newWidth = 0;
            float newHeight = 0;
            
            if (img.size.height > img.size.width) {
                temp = img.size.width * maximumSize / img.size.height;
                newWidth = temp;
                newHeight = maximumSize;
            } else {
                temp = img.size.height * maximumSize / img.size.width;
                newWidth = maximumSize;
                newHeight = temp;
            }
            
            newSize = CGSizeMake(newWidth, newHeight);
            UIGraphicsBeginImageContext(newSize);
        } else {
            newSize = CGSizeMake(img.size.width, img.size.height);
            UIGraphicsBeginImageContext(newSize);
        }
        
        [img drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
        UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        self.imageView.image = newImage;
        
        self.wasRotated = NO;
        self.currentImageStage = -1;
        
        if (self.logoImageView) {
            [self.logoImageView removeFromSuperview];
        }
        
        // TODO: abstract this duplication (create paint subview)
        CGRect tmp = [self getImageDisplaySize:self.imageView];
        [self.paintImageView removeFromSuperview];
        UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
        [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
        self.paintImageView = tmpImgVw;
        [self.imageView addSubview:self.paintImageView];
        self.hasMaskData = NO;
        
        if (img.size.width != img.size.height) {
            [self.freezeButton setEnabled:YES];
            [self.unFreezeButton setEnabled:YES];
            [self.squareButton setEnabled:YES];
        } else {
            [self.freezeButton setEnabled:NO];
            [self.unFreezeButton setEnabled:NO];
            [self.squareButton setEnabled:NO];
        }
    }
}

- (CGRect)getImageDisplaySize:(UIImageView *)imageView
{
    //
    // TODO: The paint window is not being calculated corectly
    //       (in the Photo editing extension only)
    //
    CGRect results = CGRectZero;
    CGSize imageSize = imageView.image.size;
    CGSize frameSize = imageView.frame.size;
    if ((imageSize.width < frameSize.width) && (imageSize.height < frameSize.height)) {
        results.size = imageSize;
    } else {
        CGFloat widthRatio = imageSize.width / frameSize.width;
        CGFloat heightRatio = imageSize.height / frameSize.height;
        CGFloat maxRatio = MAX(widthRatio, heightRatio);
        //NSLog(@"%f = %f / %f", widthRatio, imageSize.width, frameSize.width);
        //NSLog(@"%f = %f / %f", heightRatio, imageSize.height, frameSize.height);
        
        results.size.width = roundf(imageSize.width / maxRatio);
        results.size.height = roundf(imageSize.height / maxRatio);
    }
    results.origin.x = roundf(imageView.center.x - (results.size.width / 2));
    results.origin.y = roundf(imageView.center.y - (results.size.height / 2));
    //NSLog(@"%f, %f -- %f, %f", results.origin.x, results.origin.y, results.size.width, results.size.height);
    return results;
}

- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - Squaring methods

- (void)squareImageBegin {
    UIImage *orientedImage;
    UIImage *orientedMask;
    if (self.imageView.image.size.height > self.imageView.image.size.width) {
        orientedImage = [self imageRotatedByDegrees:self.imageView.image deg:-90];
        // don't bother rotating an empty painting sub view, just pass the nil
        if (self.paintImageView.image) {
            orientedMask = [self imageRotatedByDegrees:self.paintImageView.image deg:-90];
        } else {
            orientedMask = self.paintImageView.image;
        }
        self.wasRotated = YES;
    } else {
        orientedImage = self.imageView.image;
        orientedMask = self.paintImageView.image;
    }
    
    // launch squaring algorithm on a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SeamCarveBridge squareImage:orientedImage withMask:orientedMask];
    });
    
    NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
    self.padMode = 0;
    if ([squaredDefaults integerForKey:@"padSquareColor"]) {
        self.padMode = (int)[squaredDefaults integerForKey:@"padSquareColor"];
    }
    
    [self disableUIelements];
    
    // preapre squaring stages array
    self.imageStages = [[NSMutableArray alloc] init];
    self.currentImageStage = 0;
    if (!self.padMode) {
        [self.imageStages addObject:self.imageView.image];
    }
}

- (void)squareImageBorderTransition:(NSNotification *)notification {
    // receive updates from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [self imageRotatedByDegrees:tmpImage deg:90];
            self.imageView.image = orientedImage;
            
            NSValue *animationDurationValue = @0.4;
            NSTimeInterval animationDuration;
            [animationDurationValue getValue:&animationDuration];
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            self.imageView.alpha = 0.5;
            [UIView commitAnimations];
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:orientedImage];
        } else {
            self.imageView.image = [notification object];
            
            NSValue *animationDurationValue = @0.4;
            NSTimeInterval animationDuration;
            [animationDurationValue getValue:&animationDuration];
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:animationDuration];
            self.imageView.alpha = 0.5;
            [UIView commitAnimations];
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:[notification object]];
        }
    });
}

- (void)squareImageUpdate:(NSNotification *)notification {
    // receive updates from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [self imageRotatedByDegrees:tmpImage deg:90];
            self.imageView.image = orientedImage;
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:orientedImage];
        } else {
            self.imageView.image = [notification object];
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:[notification object]];
        }
    });
}

- (void)squareImageComplete:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^(){
        // remove (invisible) paint window
        [self.paintImageView removeFromSuperview];
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [self imageRotatedByDegrees:tmpImage deg:90];
            self.imageView.image = orientedImage;
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:orientedImage];
        } else {
            self.imageView.image = [notification object];
            
            // add to the stages array
            self.currentImageStage += 1;
            [self.imageStages addObject:[notification object]];
        }
        
        if (self.watermark) {
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setImage:[UIImage imageNamed:@"Banner"]];
            [tmpImgVw setContentMode:UIViewContentModeBottomLeft];
            self.logoImageView = tmpImgVw;
            [self.imageView addSubview:self.logoImageView];
        }
        
        self.squaringComplete = YES;
        [self enableUIelements];
    });
}

#pragma mark - UI Updates

- (void)disableUIelements {
    [self.freezeButton setEnabled:NO];
    [self.unFreezeButton setEnabled:NO];
    [self.squareButton setEnabled:NO];
    
    self.activityIndicator.alpha = 0.2;
    [self.activityIndicator startAnimating];
    
    NSValue *animationDurationValue = @0.8;
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    if (self.padMode) {
        self.imageView.alpha = 0.0;
    } else {
        self.imageView.alpha = 0.5;
    }
    self.paintImageView.alpha = 0.0;
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
    
    // image is already square
    //[self.freezeButton setEnabled:YES];
    //[self.unFreezeButton setEnabled:YES];
    //[self.squareButton setEnabled:YES];
}

- (void)updatePatintUI {
    if (self.paintMode == PaintModeFreeze) {
        [self.freezeButton setTintColor:[UIColor whiteColor]];
        [self.unFreezeButton setTintColor:self.view.tintColor];
        self.paintColorR = PAINT_COLOR_FRZ_R;
        self.paintColorG = PAINT_COLOR_FRZ_G;
        self.paintColorB = PAINT_COLOR_FRZ_B;
    } else if (self.paintMode == PaintModeUnFreeze) {
        [self.freezeButton setTintColor:self.view.tintColor];
        [self.unFreezeButton setTintColor:[UIColor whiteColor]];
        self.paintColorR = PAINT_COLOR_UFZ_R;
        self.paintColorG = PAINT_COLOR_UFZ_G;
        self.paintColorB = PAINT_COLOR_UFZ_B;
    } else {
        [self.freezeButton setTintColor:self.view.tintColor];
        [self.unFreezeButton setTintColor:self.view.tintColor];
    }
}

#pragma mark - UI Responders

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.paintMode) {
        self.mouseSwiped = NO;
        self.hasMaskData = YES;
        UITouch *touch = [touches anyObject];
        self.lastPoint = [touch locationInView:self.paintImageView];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.paintMode) {
        self.mouseSwiped = YES;
        UITouch *touch = [touches anyObject];
        CGPoint currentPoint = [touch locationInView:self.paintImageView];
        
        UIGraphicsBeginImageContext(self.paintImageView.frame.size);
        [self.paintImageView.image drawInRect:CGRectMake(0, 0, self.paintImageView.frame.size.width, self.paintImageView.frame.size.height)];
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), self.lastPoint.x, self.lastPoint.y);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), currentPoint.x, currentPoint.y);
        CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), PAINT_BRUSH_SIZE);
        CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), self.paintColorR, self.paintColorG, self.paintColorB, 1.0);
        CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeNormal);
        
        CGContextStrokePath(UIGraphicsGetCurrentContext());
        self.paintImageView.image = UIGraphicsGetImageFromCurrentImageContext();
        [self.paintImageView setAlpha:PAINT_BRUSH_ALPHA];
        UIGraphicsEndImageContext();
        
        self.lastPoint = currentPoint;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.paintMode) {
        if(!self.mouseSwiped) {
            UIGraphicsBeginImageContext(self.paintImageView.frame.size);
            [self.paintImageView.image drawInRect:CGRectMake(0, 0, self.paintImageView.frame.size.width, self.paintImageView.frame.size.height)];
            CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
            CGContextSetLineWidth(UIGraphicsGetCurrentContext(), PAINT_BRUSH_SIZE);
            CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), self.paintColorR, self.paintColorG, self.paintColorB, 1.0);
            CGContextMoveToPoint(UIGraphicsGetCurrentContext(), self.lastPoint.x, self.lastPoint.y);
            CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), self.lastPoint.x, self.lastPoint.y);
            CGContextStrokePath(UIGraphicsGetCurrentContext());
            CGContextFlush(UIGraphicsGetCurrentContext());
            self.paintImageView.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    }
}

/*
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    //
    // TODO: This is not working at all
    //
    if (motion == UIEventSubtypeMotionShake) {
        if (self.hasMaskData) {
            // TODO: abstract this duplication (create paint subview)
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            [self.paintImageView removeFromSuperview];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
            self.paintImageView = tmpImgVw;
            [self.imageView addSubview:self.paintImageView];
        } else {
            // Don't really need this here, can cancel back to the original and then edit again
            //if (self.squaringComplete) {
            //    [self loadImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:self.currentImageURL]]];
            //}
        }
    }
}
*/

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    if (self.paintImageView) {
        CGRect tmp = [self getImageDisplaySize:self.imageView];
        [self.paintImageView setFrame:tmp];
    }
    
}

#pragma mark - IB Actions

- (IBAction)doSquaring:(id)sender {
    [self squareImageBegin];
}

- (IBAction)doFreezing:(id)sender {
    if (self.paintMode == PaintModeFreeze) {
        self.paintMode = PaintModeNone;
    } else {
        self.paintMode = PaintModeFreeze;
    }
    [self updatePatintUI];
}

- (IBAction)doUnFreezing:(id)sender {
    if (self.paintMode == PaintModeUnFreeze) {
        self.paintMode = PaintModeNone;
    } else {
        self.paintMode = PaintModeUnFreeze;
    }
    [self updatePatintUI];
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)sender {
    // must have an image loaded and squared
    if (self.currentImageStage >= 0) {
        // zoom out (un-square)
        if (sender.scale < 1) {
            if (self.currentImageStage < (self.imageStages.count - 1)) {
                self.currentImageStage += 1;
                self.imageView.image = self.imageStages[self.currentImageStage];
            }
            // soom in (re-square)
        } else if (sender.scale > 1) {
            if (self.currentImageStage > 0) {
                self.currentImageStage -= 1;
                self.imageView.image = self.imageStages[self.currentImageStage];
            }
        }
    }
    
    // reset scale
    sender.scale = 1;
}

@end
