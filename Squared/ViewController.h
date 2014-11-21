//
//  ViewController.h
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>

#define PAINT_BRUSH_SIZE 32.0
#define PAINT_BRUSH_ALPHA 0.6
#define PAINT_COLOR_FRZ_R 0.2509803922
#define PAINT_COLOR_FRZ_G 0.2509803922
#define PAINT_COLOR_FRZ_B 1.0
#define PAINT_COLOR_UFZ_R 1.0
#define PAINT_COLOR_UFZ_G 0.2509803922
#define PAINT_COLOR_UFZ_B 0.2509803922

typedef NS_ENUM(NSUInteger, PaintMode) {
    PaintModeNone,
    PaintModeFreeze,
    PaintModeUnFreeze
};

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *openButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *squareButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *freezeButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *unFreezeButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

- (IBAction)doOpen:(id)sender;
- (IBAction)doSquaring:(id)sender;
- (IBAction)doSaving:(id)sender;
- (IBAction)doFreezing:(id)sender;
- (IBAction)doUnFreezing:(id)sender;


@end

