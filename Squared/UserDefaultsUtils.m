//
//  UserDefaultsUtils.m
//  Squared
//
//  Created by Christopher Stoll on 12/28/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#import "UserDefaultsUtils.h"
#import "SquaredDefines.h"

@implementation UserDefaultsUtils

+ (NSInteger)deviceSpecificCutsPerItteration
{
    NSInteger result = DEFAULT_CUTS_PER_ITTERATION;
    if ([[UIScreen mainScreen] respondsToSelector: @selector(scale)]) {
        CGSize screenSize = [[UIScreen mainScreen] bounds].size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        screenSize = CGSizeMake(screenSize.width * screenScale, screenSize.height * screenScale);
        
        if (screenSize.height <= 960) {
            result -= 4;
        } else if (screenSize.height <= 1136) {
            result -= 2;
        }
    }
    if (result <= 0) {
        result = 1;
    }
    return result;
}

+ (NSInteger)deviceSpecificMaximumSize
{
    NSInteger result = DEFAULT_MAXIMUM_SIZE;
    if ([[UIScreen mainScreen] respondsToSelector: @selector(scale)]) {
        CGSize screenSize = [[UIScreen mainScreen] bounds].size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        screenSize = CGSizeMake(screenSize.width * screenScale, screenSize.height * screenScale);
        
        if (screenSize.height <= 960) {
            result -= 2;
        } else if (screenSize.height <= 1136) {
            result -= 1;
        }
    }
    if (result <= 0) {
        result = 1;
    }
    return result;
}

+ (void)loadDefaults:(BOOL)shared
{
    if (shared) {
        // Shared user defaults set here for the photo editing extension
        NSUserDefaults *squaredDefaultsShared = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
        if (![squaredDefaultsShared integerForKey:@"cutsPerItteration"] && ![squaredDefaultsShared integerForKey:@"padSquareColor"] && ![squaredDefaultsShared integerForKey:@"maximumSize"] && ![squaredDefaultsShared integerForKey:@"IAP_NoLogo"]) {
            
            // load up the same defaults as for the settings bundle
            NSURL *settingsBundleURLshared = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"bundle"];
            NSDictionary *appDefaultsShared = [UserDefaultsUtils loadDefaultsFromSettingsPage:@"Root.plist" inSettingsBundleAtURL:settingsBundleURLshared];
            
            [squaredDefaultsShared setInteger:[self deviceSpecificCutsPerItteration] forKey:@"cutsPerItteration"];
            [squaredDefaultsShared setInteger:[self deviceSpecificMaximumSize] forKey:@"maximumSize"];
            
            [squaredDefaultsShared registerDefaults:appDefaultsShared];
            [squaredDefaultsShared synchronize];
        }
        
        if (![squaredDefaultsShared integerForKey:@"cutsPerItteration"]) {
            [squaredDefaultsShared setInteger:[self deviceSpecificCutsPerItteration] forKey:@"cutsPerItteration"];
        }
        if (![squaredDefaultsShared integerForKey:@"padSquareColor"]) {
            [squaredDefaultsShared setInteger:DEFAULT_PAD_SQUARE_COLOR forKey:@"padSquareColor"];
        }
        if (![squaredDefaultsShared integerForKey:@"maximumSize"]) {
            [squaredDefaultsShared setInteger:[self deviceSpecificMaximumSize] forKey:@"maximumSize"];
        }
        [squaredDefaultsShared synchronize];
    } else {
        // User defaults from the settings bundle (only for the Squared app)
        NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
        if (![squaredDefaults integerForKey:@"cutsPerItteration"] && ![squaredDefaults integerForKey:@"padSquareColor"] && ![squaredDefaults integerForKey:@"maximumSize"] && ![squaredDefaults integerForKey:@"IAP_NoLogo"]) {
            
            // load up the same defaults as for the settings bundle
            NSURL *settingsBundleURLshared = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"bundle"];
            NSDictionary *appDefaultsShared = [UserDefaultsUtils loadDefaultsFromSettingsPage:@"Root.plist" inSettingsBundleAtURL:settingsBundleURLshared];
            
            [squaredDefaults setInteger:[self deviceSpecificCutsPerItteration] forKey:@"cutsPerItteration"];
            [squaredDefaults setInteger:[self deviceSpecificMaximumSize] forKey:@"maximumSize"];
            
            [squaredDefaults registerDefaults:appDefaultsShared];
            [squaredDefaults synchronize];
        }
        
        if (![squaredDefaults integerForKey:@"cutsPerItteration"]) {
            [squaredDefaults setInteger:[self deviceSpecificCutsPerItteration] forKey:@"cutsPerItteration"];
        }
        // zero is a liegitimate choice for pad square color
        //if (![squaredDefaults integerForKey:@"padSquareColor"]) {
        //    [squaredDefaults setInteger:DEFAULT_PAD_SQUARE_COLOR forKey:@"padSquareColor"];
        //}
        if (![squaredDefaults integerForKey:@"maximumSize"]) {
            [squaredDefaults setInteger:[self deviceSpecificMaximumSize] forKey:@"maximumSize"];
        }
        [squaredDefaults synchronize];
    }
}

+ (BOOL)getBoolDefault:(BOOL)shared forKey:(NSString*)key
{
    NSUserDefaults *userDefaults;
    if (shared) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    } else {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    if ([userDefaults boolForKey:key]) {
        return [userDefaults boolForKey:key];
    } else {
        return NO;
    }
}

+ (NSInteger)getIntegerDefault:(BOOL)shared forKey:(NSString*)key
{
    NSUserDefaults *userDefaults;
    if (shared) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    } else {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    if ([userDefaults boolForKey:key]) {
        return [userDefaults integerForKey:key];
    } else {
        return 0;
    }
}

+ (void)setBool:(BOOL)shared value:(BOOL)value forKey:(NSString*)key
{
    NSUserDefaults *userDefaults;
    if (shared) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    } else {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    [userDefaults setBool:value forKey:key];
    [userDefaults synchronize];
}

+ (void)setString:(BOOL)shared value:(NSString *)value forKey:(NSString*)key
{
    NSUserDefaults *userDefaults;
    if (shared) {
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    } else {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    [userDefaults setValue:value forKey:key];
    [userDefaults synchronize];
}

+ (void)setSharedFromStandard
{
    NSUserDefaults *squaredDefaults = [NSUserDefaults standardUserDefaults];
    NSUserDefaults *squaredDefaultsShared = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_SUITE_NAME];
    [squaredDefaultsShared setValue:[squaredDefaults valueForKey:@"cutsPerItteration"] forKey:@"cutsPerItteration"];
    [squaredDefaultsShared setValue:[squaredDefaults valueForKey:@"padSquareColor"] forKey:@"padSquareColor"];
    [squaredDefaultsShared setValue:[squaredDefaults valueForKey:@"maximumSize"] forKey:@"maximumSize"];
    
    // make sure algorithm settings are valid
    if (![squaredDefaultsShared stringForKey:@"algorithmSettings"]) {
        [squaredDefaultsShared setValue:ALGORITHM_SETTINGS_HASH forKey:@"algorithmSettings"];
    } else {
        if ([squaredDefaultsShared integerForKey:@"IAP_NoLogo"]) {
            NSString *algorithmSettings = [squaredDefaultsShared stringForKey:@"algorithmSettings"];
            if ([algorithmSettings isEqualToString:ALGORITHM_SETTINGS_HASH]) {
                [squaredDefaultsShared setBool:NO forKey:@"IAP_NoLogo"];
            }
        }
    }
    [squaredDefaultsShared synchronize];
}

//| ----------------------------------------------------------------------------
//! Helper function that parses a Settings page file, extracts each preference
//! defined within along with its default value.  If the page contains a
//! 'Child Pane Element', this method will recurs on the referenced page file.
//
+ (NSDictionary*)loadDefaultsFromSettingsPage:(NSString*)plistName inSettingsBundleAtURL:(NSURL*)settingsBundleURL
{
    // Each page of settings is represented by a property-list file that follows
    // the Settings Application Schema:
    // <https://developer.apple.com/library/ios/#documentation/PreferenceSettings/Conceptual/SettingsApplicationSchemaReference/Introduction/Introduction.html>.
    
    // Create an NSDictionary from the plist file.
    NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfURL:[settingsBundleURL URLByAppendingPathComponent:plistName]];
    
    // The elements defined in a settings page are contained within an array
    // that is associated with the root-level PreferenceSpecifiers key.
    NSArray *prefSpecifierArray = settingsDict[@"PreferenceSpecifiers"];
    
    // If prefSpecifierArray is nil, something wen't wrong.  Either the
    // specified plist does ot exist or is malformed.
    if (prefSpecifierArray == nil)
        return nil;
    
    // Create a dictionary to hold the parsed results.
    NSMutableDictionary *keyValuePairs = [NSMutableDictionary dictionary];
    
    for (NSDictionary *prefItem in prefSpecifierArray)
        // Each element is itself a dictionary.
    {
        // What kind of control is used to represent the preference element in the
        // Settings app.
        NSString *prefItemType = prefItem[@"Type"];
        // How this preference element maps to the defaults database for the app.
        NSString *prefItemKey = prefItem[@"Key"];
        // The default value for the preference key.
        NSString *prefItemDefaultValue = prefItem[@"DefaultValue"];
        
        if ([prefItemType isEqualToString:@"PSChildPaneSpecifier"])
            // If this is a 'Child Pane Element'.  That is, a reference to another
            // page.
        {
            // There must be a value associated with the 'File' key in this preference
            // element's dictionary.  Its value is the name of the plist file in the
            // Settings bundle for the referenced page.
            NSString *prefItemFile = prefItem[@"File"];
            
            // Recurs on the referenced page.
            NSDictionary *childPageKeyValuePairs = [self loadDefaultsFromSettingsPage:prefItemFile inSettingsBundleAtURL:settingsBundleURL];
            
            // Add the results to our dictionary
            [keyValuePairs addEntriesFromDictionary:childPageKeyValuePairs];
        }
        else if (prefItemKey != nil && prefItemDefaultValue != nil)
            // Some elements, such as 'Group' or 'Text Field' elements do not contain
            // a key and default value.  Skip those.
        {
            keyValuePairs[prefItemKey] = prefItemDefaultValue;
        }
    }
    
    return keyValuePairs;
}

@end
