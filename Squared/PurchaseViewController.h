//
//  PurchaseViewController.h
//  Squared
//
//  Created by Christopher Stoll on 1/1/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface PurchaseViewController : UIViewController <SKProductsRequestDelegate>

@property NSArray *products;

@property (weak, nonatomic) IBOutlet UILabel *mainText;
@property (weak, nonatomic) IBOutlet UIButton *buyButton;
@property (weak, nonatomic) IBOutlet UIButton *restoreButton;
@property (weak, nonatomic) IBOutlet UILabel *thanksText;

- (IBAction)doBuy:(id)sender;
- (IBAction)doRestore:(id)sender;
- (IBAction)doCancel:(id)sender;
- (IBAction)deTest:(id)sender;

@end
