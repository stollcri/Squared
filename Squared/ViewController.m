//
//  ViewController.m
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <StoreKit/StoreKit.h>
#import "ViewController.h"
#import "SquaredDefines.h"
#import "UserDefaultsUtils.h"
#import "PurchaseUtils.h"
#import "ImageUtils.h"
#import "SeamCarveBridge.h"

@interface ViewController ()

@property BOOL useSharedDefaults;
@property NSInteger cutsPerItteration;
@property NSInteger padSquareColor;
@property NSInteger maximumSize;
@property BOOL IAP_NoLogo;

@property BOOL wasRotated;
@property BOOL hasMaskData;

@property BOOL mouseSwiped;
@property CGPoint lastPoint;
@property PaintMode paintMode;
@property CGFloat paintColorR;
@property CGFloat paintColorG;
@property CGFloat paintColorB;
@property UIImageView *paintImageView;

@property NSMutableArray *imageStages;
@property NSInteger currentImageStage;

@property UIImageView *logoImageView;
@property BOOL showWatermark; // YES by default, NO when purchsed (watermark will not show)
@property BOOL showPurchaseButton; // YES by default, NO when purchase is in progress (buy button will not show)
// The reason for two different booleans above is that
//  the first only gets turned off when the watermark removal is purchased
//  the second can be turned off at any time, when a purchase cannot be made or when one is in progress

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
        
    // Shared user defaults set here for the photo editing extension
    self.useSharedDefaults = NO;
    [UserDefaultsUtils loadDefaultsShared:self.useSharedDefaults];
    [self getDefaults];
    
    //
    // I'm not crazy about this, but it seems to be the best way to try and keep settings for
    // the app and the photo editing extension in sync. The app can read directly from the
    // settings bundle, but the photo editing extension cannot, so we have to help it out
    //
    // update shared defaults based upon the settings bundle defaults
    [UserDefaultsUtils setSharedFromStandard];
    
    self.showWatermark = YES;
    self.showPurchaseButton = YES;
    // the shared user setting may claim that we shouldn't display the watermark, but it
    // could have been changed outside of the program, so we will validate the purchase.
    // Once the validation process is complete the purchase notficiation will post which
    // will remove the watermark (like when a new purchase is made)
    if (self.IAP_NoLogo) {
        [self validatePurchase];
    }
    
    self.wasRotated = NO;
    self.paintMode = PaintModeNone;
    self.currentImageStage = -1;
    
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
    [self.removeLogoButton setHidden:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageUpdate:) name:@"org.christopherstoll.squared.squareupdate" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageComplete:) name:@"org.christopherstoll.squared.squarecomplete" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(squareImageBorderTransition:) name:@"org.christopherstoll.squared.squaretransition" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseStarted:) name:@"org.christopherstoll.squared.purchasepending" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseFailed:) name:@"org.christopherstoll.squared.purchasefailed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseCompleted:) name:@"org.christopherstoll.squared.purchased" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)getDefaults
{
    self.cutsPerItteration = [UserDefaultsUtils getIntegerDefault:self.useSharedDefaults forKey:@"cutsPerItteration"];
    self.padSquareColor = [UserDefaultsUtils getIntegerDefault:self.useSharedDefaults forKey:@"padSquareColor"];
    self.maximumSize = [UserDefaultsUtils getIntegerDefault:self.useSharedDefaults forKey:@"maximumSize"];
    self.IAP_NoLogo = [UserDefaultsUtils getBoolDefault:YES forKey:@"IAP_NoLogo"]; // always from shared
}

- (void)defaultsChanged:(NSNotification *)notification {
    [self getDefaults];
}

- (void)validatePurchase
{
    PurchaseUtils *purchase = [[PurchaseUtils alloc] init];
    if ([purchase validateMainBundleReceipt]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.purchased" object:nil];
    } else {
        SKReceiptRefreshRequest *receiptRefresh = [[SKReceiptRefreshRequest alloc] init];
        [receiptRefresh setDelegate:self];
        [receiptRefresh start];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    // TODO: move to bridge class
    if (img) {
        int maximumSize = MAXIMUM_SIZE_DEFAULT;
        if (self.maximumSize) {
            maximumSize = (int)(self.maximumSize * MAXIMUM_SIZE_MULTIPLIER) + MAXIMUM_SIZE_BASEVALUE;
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
        CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
        [self.paintImageView removeFromSuperview];
        UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
        [tmpImgVw setAlpha:PAINT_BRUSH_ALPHA];
        self.paintImageView = tmpImgVw;
        [self.imageView addSubview:self.paintImageView];
        self.hasMaskData = NO;
        
        [self.removeLogoButton setHidden:YES];
        
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

- (void)squareImageBegin
{
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
        orientedImage = [ImageUtils rotateImage:self.imageView.image byOrientation:UIImageOrientationRight];
        // don't bother rotating an empty painting sub view, just pass the nil
        if (self.paintImageView.image) {
            orientedMask = [ImageUtils rotateImage:self.paintImageView.image byOrientation:UIImageOrientationRight];
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
    
    [self disableUIelements];
    
    // prepare squaring stages array
    self.imageStages = [[NSMutableArray alloc] init];
    self.currentImageStage = 0;
    if (!self.padSquareColor) {
        [self.imageStages addObject:self.imageView.image];
    }
}

- (void)squareImageBorderTransition:(NSNotification *)notification
{
    // receive updates from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [ImageUtils rotateImage:tmpImage byOrientation:UIImageOrientationLeft];
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

- (void)squareImageUpdate:(NSNotification *)notification
{
    // receive updates from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [ImageUtils rotateImage:tmpImage byOrientation:UIImageOrientationLeft];
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

- (void)squareImageComplete:(NSNotification *)notification
{
    // return from the background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // remove (invisible) paint window
        [self.paintImageView removeFromSuperview];
        // update present display
        if (self.wasRotated) {
            UIImage *tmpImage = [notification object];
            UIImage *orientedImage = [ImageUtils rotateImage:tmpImage byOrientation:UIImageOrientationLeft];
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
        if (self.showWatermark) {
            CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
            UIImageView *tmpImgVw = [[UIImageView alloc] initWithFrame:tmp];
            [tmpImgVw setImage:[UIImage imageNamed:@"Banner"]];
            [tmpImgVw setContentMode:UIViewContentModeBottomLeft];
            self.logoImageView = tmpImgVw;
            [self.imageView addSubview:self.logoImageView];
        }
        
        [self enableUIelements];
    });
}

#pragma mark - Notification handlers

- (void)purchaseStarted:(NSNotification *)notification
{
    self.showPurchaseButton = NO;
}

- (void)purchaseFailed:(NSNotification *)notification
{
    self.showPurchaseButton = YES;
}

- (void)purchaseCompleted:(NSNotification *)notification
{
    self.showPurchaseButton = NO;
    self.showWatermark = NO;
    
    [self.removeLogoButton setHidden:YES];
    [self.logoImageView removeFromSuperview];
    
    [UserDefaultsUtils setBool:self.useSharedDefaults value:YES forKey:@"IAP_NoLogo"];
}

#pragma mark - UI Updates

- (void)disableUIelements
{
    [self.removeLogoButton setHidden:YES];
    
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
    if (self.padSquareColor) {
        self.imageView.alpha = 0.0;
    } else {
        self.imageView.alpha = 0.5;
    }
    self.paintImageView.alpha = 0.0;
    self.activityIndicator.alpha = 1.0;
    [UIView commitAnimations];
}

- (void)enableUIelements
{
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
    
    if (self.showWatermark && self.showPurchaseButton) {
        // TODO: Double check this section works
        // only show the purchase button if they can purchase
        if ([SKPaymentQueue canMakePayments]) {
            [self.removeLogoButton setHidden:NO];
        }
    }
}

- (void)updatePaintUI
{
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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
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
            CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
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

- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    if (self.paintImageView) {
        CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
        [self.paintImageView setFrame:tmp];
        [self.logoImageView setFrame:tmp];
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
    if (self.showWatermark) {
        CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
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
    [self updatePaintUI];
}

- (IBAction)doUnFreezing:(id)sender {
    if (self.paintMode == PaintModeUnFreeze) {
        self.paintMode = PaintModeNone;
    } else {
        self.paintMode = PaintModeUnFreeze;
    }
    [self updatePaintUI];
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)sender {
    // must have an image loaded and squared
    if (self.currentImageStage >= 0) {
        // zoom out (un-square)
        if (sender.scale < 1) {
            if (self.currentImageStage < (self.imageStages.count - 1)) {
                self.currentImageStage += 1;
                self.imageView.image = self.imageStages[self.currentImageStage];
                
                if (self.showWatermark && !self.padSquareColor) {
                    CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
                    [self.logoImageView setFrame:tmp];
                }
            }
        // soom in (re-square)
        } else if (sender.scale > 1) {
            if (self.currentImageStage > 0) {
                self.currentImageStage -= 1;
                self.imageView.image = self.imageStages[self.currentImageStage];
                
                if (self.showWatermark && !self.padSquareColor) {
                    CGRect tmp = [ImageUtils getDisplaySizeOfImageView:self.imageView];
                    [self.logoImageView setFrame:tmp];
                }
            }
        }
    }
    
    // reset scale
    sender.scale = 1;
}

@end
