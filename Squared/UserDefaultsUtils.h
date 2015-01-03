//
//  UserDefaultsUtils.h
//  Squared
//
//  Created by Christopher Stoll on 12/28/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UserDefaultsUtils : NSObject

+ (void)loadDefaults:(BOOL)shared;

+ (BOOL)getBoolDefault:(BOOL)shared forKey:(NSString*)key;
+ (NSInteger)getIntegerDefault:(BOOL)shared forKey:(NSString*)key;

+ (void)setBool:(BOOL)shared value:(BOOL)value forKey:(NSString*)key;

+ (void)setSharedFromStandard;

+ (NSDictionary*)loadDefaultsFromSettingsPage:(NSString*)plistName inSettingsBundleAtURL:(NSURL*)settingsBundleURL;

@end
