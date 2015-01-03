//
//  PurchaseViewController.m
//  Squared
//
//  Created by Christopher Stoll on 1/1/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import "PurchaseViewController.h"
#import "SquaredDefines.h"
#import "PurchaseUtils.h"

@implementation PurchaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.buyButton setHidden:YES];
    [self.thanksText setHidden:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseStarted:) name:@"org.christopherstoll.squared.purchasepending" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseFailed:) name:@"org.christopherstoll.squared.purchasefailed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseCompleted:) name:@"org.christopherstoll.squared.purchased" object:nil];
    
    // Fetch all the products
    NSArray *productIdentifiers = [PurchaseUtils listProductIdentifiers];
    [self validateProductIdentifiers:productIdentifiers];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)validateProductIdentifiers:(NSArray *)productIdentifiers
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

#pragma mark - SKProductsRequestDelegate protocol methods

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    self.products = response.products;
    /*
    for (NSString *invalidIdentifier in response.invalidProductIdentifiers) {
        // TODO: Handle any invalid product identifiers.
        NSLog(@"%@", invalidIdentifier);
    }
    */
    
    SKProduct *product = self.products.firstObject;
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
    
    // update buy button to have purchase price
    NSString *newButtonLabel = [[NSString alloc] initWithFormat:@"%@ %@", self.buyButton.titleLabel.text, formattedPrice];
    [self.buyButton setTitle:newButtonLabel forState:UIControlStateNormal];
    
    // prepare buy button for animation
    self.buyButton.alpha = 0.0;
    [self.buyButton setHidden:NO];
    
    // animate showing of buy button
    NSValue *animationDurationValue = @0.6;
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];
    self.buyButton.alpha = 1.0;
    [UIView commitAnimations];
}

#pragma mark - UI updaters

- (void)disableBuyButton
{
    [self.buyButton setEnabled:NO];
}

- (void)enableBuyButton
{
    [self.buyButton setEnabled:YES];
}

- (void)showThanks
{
    [self.mainText setHidden:YES];
    [self.buyButton setHidden:YES];
    [self.thanksText setHidden:NO];
}

#pragma mark - Notification handlers

- (void)purchaseStarted:(NSNotification *)notification
{
    [self disableBuyButton];
}

- (void)purchaseFailed:(NSNotification *)notification
{
    [self enableBuyButton];
}

- (void)purchaseCompleted:(NSNotification *)notification
{
    [self showThanks];
}

#pragma mark - IB Actions

- (IBAction)doBuy:(id)sender {
    SKProduct *product = self.products.firstObject;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (IBAction)doCancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)deTest:(id)sender {
    /*
    NSUserDefaults *squaredDefaultsShared = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    [squaredDefaultsShared setBool:YES forKey:@"IAP_NoLogo"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.purchased" object:nil];
    */
}

@end
