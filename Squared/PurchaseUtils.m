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

@end
