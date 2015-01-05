//
//  TransactionQueueObserver.m
//  Squared
//
//  Created by Christopher Stoll on 1/1/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import "TransactionQueueObserver.h"
#import "SquaredDefines.h"
#import "PurchaseUtils.h"
#import "UserDefaultsUtils.h"

@interface TransactionQueueObserver ()
@property BOOL useSharedDefaults;
@end

@implementation TransactionQueueObserver

- (id)init {
    self = [super init];
    if (self) {
        self.useSharedDefaults = YES;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
                // Call the appropriate custom method for the transaction state.
            case SKPaymentTransactionStatePurchasing:
                [self showTransactionAsInProgress:transaction deferred:NO];
                break;
            case SKPaymentTransactionStateDeferred:
                [self showTransactionAsInProgress:transaction deferred:YES];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
            default:
                // For debugging
                //NSLog(@"Unexpected transaction state %@", @(transaction.transactionState));
                break;
        }
    }
}

- (void)showTransactionAsInProgress:(SKPaymentTransaction *)transaction deferred:(BOOL)deferrred
{
    //NSLog(@"showTransactionAsInProgress");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.purchasepending" object:nil];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction
{
    //NSLog(@"failedTransaction");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.purchasefailed" object:nil];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    //NSLog(@"completeTransaction");
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    //[PurchaseUtils validateReceiptWithAppStore];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    //NSLog(@"restoreTransaction");
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    //[PurchaseUtils validateReceiptWithAppStore];
}

@end
