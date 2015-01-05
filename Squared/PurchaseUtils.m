//
//  PurchaseUtils.m
//  Squared
//
//  Created by Christopher Stoll on 1/2/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import "PurchaseUtils.h"
#import "SquaredDefines.h"

@implementation PurchaseUtils

+ (NSArray *)listProductIdentifiers
{
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Products" ofType:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfFile:plistPath];
    return productIdentifiers;
}

+ (BOOL)validateReceipt
{
    bool result = NO;
    
    // check that a receipt exists
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (receiptData) {
        
        // Create the JSON object that describes the request
        NSError *error;
        NSDictionary *requestContents = @{@"receipt-data": [receiptData base64EncodedStringWithOptions:0]};
        NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
        
        if (requestData) {
            // Create a POST request with the receipt data.
            NSURL *storeURL = [NSURL URLWithString:APP_STORE_VERIFY_URL];
            NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
            [storeRequest setHTTPMethod:@"POST"];
            [storeRequest setHTTPBody:requestData];
            
            // Make a connection to the iTunes Store on a background queue.
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                                   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                       BOOL didSucceed = NO;
                                       NSDictionary *jsonReceiptIAP;
                                       
                                       if (connectionError) {
                                           didSucceed = NO;
                                           /* ... Handle error ... */
                                       } else {
                                           NSError *error;
                                           NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                           if (!jsonResponse) {
                                               didSucceed = NO;
                                               /* ... Handle error ...*/
                                           } else {
                                               NSString* bundleIDactual = [[NSBundle mainBundle] bundleIdentifier];
                                               
                                               if ([bundleIDactual isEqualToString:APP_BUNDLE_IDENTIFIER]) {
                                                   jsonReceipt = jsonResponse[@"receipt"];
                                                   NSString* bundleIDreturn = jsonReceipt[@"bundle_id"];
                                                   
                                                   if ([bundleIDreturn isEqualToString:bundleIDactual]) {
                                                       didSucceed = YES;
                                                   }
                                               }
                                           }
                                       }
                                       
                                       if (didSucceed) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.verified" object:nil userInfo:jsonReceiptIAP];
                                           });
                                       } else {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               [[NSNotificationCenter defaultCenter] postNotificationName:@"org.christopherstoll.squared.verificationfailed" object:nil];
                                            });
                                       }
                                       
                                   }];
        }
    }
    
    return result;
}

@end
