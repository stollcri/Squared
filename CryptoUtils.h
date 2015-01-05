//
//  CryptoUtils.h
//  Squared
//
//  Created by Christopher Stoll on 1/5/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CryptoUtils : NSObject

+ (NSString *)hashed_string:(NSString *)input;

@end
