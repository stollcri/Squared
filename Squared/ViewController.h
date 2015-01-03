//
//  ViewController.h
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, PaintMode) {
    PaintModeNone,
    PaintModeFreeze,
    PaintModeUnFreeze
};

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *openButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *settingsButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *squareButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *freezeButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *unFreezeButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIView *popoverAnchor;
@property (weak, nonatomic) IBOutlet UIButton *removeLogoButton;

- (IBAction)doOpen:(id)sender;
- (IBAction)doSettings:(id)sender;
- (IBAction)doSquaring:(id)sender;
- (IBAction)doSaving:(id)sender;
- (IBAction)doFreezing:(id)sender;
- (IBAction)doUnFreezing:(id)sender;
- (IBAction)handlePinch:(UIPinchGestureRecognizer *)sender;

@end

