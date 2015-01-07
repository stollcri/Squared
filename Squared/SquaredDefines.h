//
//  SquaredDefines.h
//  Squared
//
//  Created by Christopher Stoll on 12/28/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#ifndef Squared_SquaredDefines_h
#define Squared_SquaredDefines_h

#define APP_BUNDLE_IDENTIFIER @"org.christopherstoll.Squared"
#define APP_GROUP_SUITE_NAME @"group.org.christopherstoll.Squared"

#define APPLE_ROOT_CERT_MD5 @"7e611e0f7ba31b51986f413b41383ef0"

#ifdef DEBUG
#define DEVELOPMENT_CHECKS 1
#else
#define DEVELOPMENT_CHECKS 0
#endif

#define DEFAULT_MAXIMUM_SIZE 6
#define DEFAULT_PAD_SQUARE_COLOR 2
#define DEFAULT_CUTS_PER_ITTERATION 8

#define MAXIMUM_SIZE_DEFAULT 1120
#define MAXIMUM_SIZE_BASEVALUE 160
#define MAXIMUM_SIZE_MULTIPLIER 160

#define CUTS_PER_ITTERATION_DEFAULT 16
#define CUTS_PER_ITTERATION_BASEVALUE 12
#define CUTS_PER_ITTERATION_MULTIPLIER 4

#define MAX_ITTERATION_IMAGES_TO_SHOW 18

#define PAD_MODE_BORDERED_BEGIN 2
#define PAD_MODE_NONE 1
#define PAD_MODE_COLOR 2
#define PAD_MODE_COLORS 3
#define PAD_MODE_CLEAR 4
#define PAD_MODE_MIRROR 5
#define PAD_MODE_SMEAR 6
#define PAD_MODE_BLACK 7
#define PAD_MODE_WHITE 8
    
#define PAINT_BRUSH_SIZE 32.0
#define PAINT_BRUSH_ALPHA 0.6
#define PAINT_COLOR_FRZ_R 0.2509803922
#define PAINT_COLOR_FRZ_G 0.2509803922
#define PAINT_COLOR_FRZ_B 1.0
#define PAINT_COLOR_UFZ_R 1.0
#define PAINT_COLOR_UFZ_G 0.2509803922
#define PAINT_COLOR_UFZ_B 0.2509803922

#endif
