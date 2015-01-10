//
//  PurchaseUtils.h
//  Squared
//
//  Created by Christopher Stoll on 1/2/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PurchaseUtils : NSObject

+ (NSArray *)listProductIdentifiers;

- (NSString *)getRootCertificateVigenere;

- (NSInteger)getCurrentValidationStage;
- (BOOL)validateMainBundleReceipt;

@end
