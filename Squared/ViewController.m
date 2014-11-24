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

@property BOOL hasMaskData;

@property CGPoint lastPoint;
@property BOOL mouseSwiped;
@property PaintMode paintMode;
@property CGFloat paintColorR;
@property CGFloat paintColorG;
@property CGFloat paintColorB;
@property UIImageView *paintImageView;

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    
    [self.freezeButton setEnabled:NO];
    [self.unFreezeButton setEnabled:NO];
    [self.squareButton setEnabled:NO];
    [self.saveButton setEnabled:NO];
    self.paintMode = PaintModeNone;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    // TODO: move to bridge class
    if (img) {
        // make sure choosen image is less than maximum size
        if ((img.size.height > MAXIMUM_IMAGE_SIZE) || (img.size.width > MAXIMUM_IMAGE_SIZE)) {
            int temp = 0.0;
            float newWidth = 0;
            float newHeight = 0;
            
            // determine new image dimensions
            if (img.size.height > img.size.width) {
                temp = img.size.width * MAXIMUM_IMAGE_SIZE / img.size.height;
                newWidth = temp;
                newHeight = MAXIMUM_IMAGE_SIZE;
            } else {
                temp = img.size.height * MAXIMUM_IMAGE_SIZE / img.size.width;
                newWidth = MAXIMUM_IMAGE_SIZE;
                newHeight = temp;
            }
            
            // resize the image (in memory)
            CGSize newSize = CGSizeMake(newWidth, newHeight);
            UIGraphicsBeginImageContext(newSize);
            [img drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            self.imageView.image = newImage;
            
            // add subview for painting image masks
            // TODO: abstract this duplication (create paint subview)
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            [self.paintImageView removeFromSuperview];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
            self.paintImageView = tmpImgVw;
            [self.imageView addSubview:self.paintImageView];
            self.hasMaskData = NO;
        } else {
            self.imageView.image = img;
            
            // add subview for painting image masks
            // TODO: abstract this duplication (create paint subview)
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            [self.paintImageView removeFromSuperview];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
            self.paintImageView = tmpImgVw;
            [self.imageView addSubview:self.paintImageView];
            self.hasMaskData = NO;
        }
        
        // do not enable mask or squaring buttons if the image is already square
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
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Utilities

// calculate the size of an image set to aspect-fit
- (CGRect)getImageDisplaySize:(UIImageView *)imageView
{
    CGRect results = CGRectZero;
    CGSize imageSize = imageView.image.size;
    CGSize frameSize = imageView.frame.size;
    if ((imageSize.width < frameSize.width) && (imageSize.height < frameSize.height)) {
        results.size = imageSize;
    } else {
        CGFloat widthRatio = imageSize.width / frameSize.width;
        CGFloat heightRatio = imageSize.height / frameSize.height;
        CGFloat maxRatio = MAX(widthRatio, heightRatio);
        
        results.size.width = roundf(imageSize.width / maxRatio);
        results.size.height = roundf(imageSize.height / maxRatio);
    }
    results.origin.x = roundf(imageView.center.x - (results.size.width / 2));
    results.origin.y = roundf(imageView.center.y - (results.size.height / 2));
    return results;
}

#pragma mark - Squaring methods

- (void)squareImageBegin {
    // launch squaring algorithm on a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SeamCarveBridge squareImage:self.imageView.image withMask:self.paintImageView.image];
    });
    [self disableUIelements];
}

- (void)squareImageComplete:(NSNotification *)notification {
    // return from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.paintImageView removeFromSuperview];
        self.imageView.image = [notification object];
        [self enableUIelements];
    });
}

#pragma mark - UI Updates

- (void)disableUIelements {
    [self.openButton setEnabled:NO];
    [self.freezeButton setEnabled:NO];
    [self.unFreezeButton setEnabled:NO];
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
    // image is already square
    //[self.freezeButton setEnabled:YES];
    //[self.unFreezeButton setEnabled:YES];
    //[self.squareButton setEnabled:YES];
    [self.saveButton setEnabled:YES];
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

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        if (self.hasMaskData) {
            // TODO: abstract this duplication (create paint subview)
            CGRect tmp = [self getImageDisplaySize:self.imageView];
            [self.paintImageView removeFromSuperview];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
            self.paintImageView = tmpImgVw;
            [self.imageView addSubview:self.paintImageView];
            self.hasMaskData = NO;
        } else {
            // TODO: add original image reloading
        }
    }
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    if (self.paintImageView) {
        CGRect tmp = [self getImageDisplaySize:self.imageView];
        [self.paintImageView setFrame:tmp];
    }
}

#pragma mark - IB Actions

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
    activityVC.popoverPresentationController.sourceView = self.popoverAnchor;
    [self presentViewController:activityVC animated:TRUE completion:nil];
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

@end
