//
//  SeamCarve.h
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#ifndef __Squared__SeamCarve__
#define __Squared__SeamCarve__

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <math.h>

#define REFRESH_SEAM_MATRIX_EVERY 32
/*
#define COLOR_TO_GREY_FACTOR_R 0.2126
#define COLOR_TO_GREY_FACTOR_G 0.7152
#define COLOR_TO_GREY_FACTOR_B 0.0722
*/

#define COLOR_TO_GREY_FACTOR_R 0.2
#define COLOR_TO_GREY_FACTOR_G 0.2
#define COLOR_TO_GREY_FACTOR_B 0.6

struct rgbaPixel {
    int r;
    int g;
    int b;
    int a;
};

void carveSeamsVertical(char *sImg, int sImgWidth, int sImgHeight, char *tImg, int tImgWidth, int tImgHeight);
void carveSeamsHorizontal(char *sImg, int sImgWidth, int sImgHeight, char *tImg, int tImgWidth, int tImgHeight);

#endif /* defined(__Squared__SeamCarve__) */
