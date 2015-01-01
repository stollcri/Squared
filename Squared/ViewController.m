//
//  ViewController.m
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "ViewController.h"
#import "SquaredDefines.h"
#import "ImageUtils.h"
#import "SeamCarveBridge.h"

@interface ViewController ()

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

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.wasRotated = NO;
    self.paintMode = PaintModeNone;
    self.currentImageStage = -1;
    self.watermark = YES;
    
    // Only iOS 8 and above supports the UIApplicationOpenSettingsURLString
    // used to launch the Settings app from your application.  If the
    // UIApplicationOpenSettingsURLString is not present, we're running on an
    // old version of iOS.
    if (&UIApplicationOpenSettingsURLString == NULL) {
        [self.settingsButton setEnabled:NO];
    }
    
    [self.freezeButton setEnabled:NO];
    [self.unFreezeButton setEnabled:NO];
    [self.squareButton setEnabled:NO];
    [self.saveButton setEnabled:NO];
    
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
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    // TODO: move to bridge class
    if (img) {
        NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
        int maximumSize = MAXIMUM_SIZE_DEFAULT;
        if ([squaredDefaults integerForKey:@"maximumSize"]) {
            maximumSize = (int)([squaredDefaults integerForKey:@"maximumSize"] * MAXIMUM_SIZE_MULTIPLIER) + MAXIMUM_SIZE_BASEVALUE;
        }
        
        // make sure choosen image is less than maximum size
        CGSize newSize;
        if ((img.size.height > maximumSize) || (img.size.width > maximumSize)) {
            int temp = 0.0;
            float newWidth = 0;
            float newHeight = 0;
            
            // determine new image dimensions
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
        
        // add subview for painting image masks
        // TODO: abstract this duplication (create paint subview)
        CGRect tmp = [ImageUtils getImageDisplaySize:self.imageView];
        [self.paintImageView removeFromSuperview];
        UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
        [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
        self.paintImageView = tmpImgVw;
        [self.imageView addSubview:self.paintImageView];
        self.hasMaskData = NO;
        
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

#pragma mark - Squaring methods

- (void)squareImageBegin {
    //
    // ** Reasoning for orientation change **
    //
    // The seam carving algorithm can handle images in portrait or landscape, HOWEVER...
    // The seam carving algorithm should receive images which are wider than tall (lanscape)
    //
    // This is due to the memory layour of the algorithm; it uses a row-major-order
    // If it is passed a portrait image it must move down the image -- column-major-order
    // To move down the image it must skip forward image-width number of pixels
    // So, the next pixel is never cached near the processor and must be fetched from memory
    // This means that we basically get no help from the processor caches
    //
    // This may not seem like a big deal, but since this is a memory movement intensive algorithm
    // THE PROCESSING OF THE ALGORITHM TIME IS DOUBLED WHEN IT CUTS HORIZONTAL SEAMS
    //
    
    UIImage *orientedImage;
    UIImage *orientedMask;
    if (self.imageView.image.size.height > self.imageView.image.size.width) {
        orientedImage = [ImageUtils imageRotatedByOrientation:self.imageView.image orientation:UIImageOrientationRight];
        // don't bother rotating an empty painting sub view, just pass the nil
        if (self.paintImageView.image) {
            orientedMask = [ImageUtils imageRotatedByOrientation:self.paintImageView.image orientation:UIImageOrientationRight];
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
            UIImage *orientedImage = [ImageUtils imageRotatedByOrientation:tmpImage orientation:UIImageOrientationLeft];
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
            UIImage *orientedImage = [ImageUtils imageRotatedByOrientation:tmpImage orientation:UIImageOrientationLeft];
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
    // return from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // remove (invisible) paint window
        [self.paintImageView removeFromSuperview];
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [ImageUtils imageRotatedByOrientation:tmpImage orientation:UIImageOrientationLeft];
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
        
        //
        // TODO: for free version with paid removal of mark
        //  fix image alpha and size (across resolutions)
        //  make it part of the exported image!
        //  add to photo editing extension
        //
        if (self.watermark) {
            CGRect tmp = [ImageUtils getImageDisplaySize:self.imageView];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setImage:[UIImage imageNamed:@"Banner"]];
            [tmpImgVw setContentMode:UIViewContentModeBottomLeft];
            self.logoImageView = tmpImgVw;
            [self.imageView addSubview:self.logoImageView];
        }
        
        [self enableUIelements];
    });
}

#pragma mark - UI Updates

- (void)disableUIelements {
    [self.openButton setEnabled:NO];
    [self.settingsButton setEnabled:NO];
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
    if (&UIApplicationOpenSettingsURLString) {
        [self.settingsButton setEnabled:YES];
    }
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
            CGRect tmp = [ImageUtils getImageDisplaySize:self.imageView];
            [self.paintImageView removeFromSuperview];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
            self.paintImageView = tmpImgVw;
            [self.imageView addSubview:self.paintImageView];
        } else {
            // TODO: add original image reloading
        }
    }
}

//
// TODO: Rotate watermark too!!! (also in the photo editing extension)
//
- (void)deviceOrientationDidChange:(NSNotification *)notification {
    if (self.paintImageView) {
        CGRect tmp = [ImageUtils getImageDisplaySize:self.imageView];
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

- (IBAction)doSettings:(id)sender {
    if (&UIApplicationOpenSettingsURLString) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}

- (IBAction)doSquaring:(id)sender {
    [self squareImageBegin];
}

- (IBAction)doSaving:(id)sender {
    UIImage *imagetoshare;
    if (self.watermark) {
        CGRect tmp = [ImageUtils getImageDisplaySize:self.imageView];
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
