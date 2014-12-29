//
//  UserDefaultsUtils.h
//  Squared
//
//  Created by Christopher Stoll on 12/28/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserDefaultsUtils : NSObject

+ (NSDictionary*)loadDefaultsFromSettingsPage:(NSString*)plistName inSettingsBundleAtURL:(NSURL*)settingsBundleURL;

@end
