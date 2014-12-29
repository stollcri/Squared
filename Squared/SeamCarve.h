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
#include <time.h>
#include <string.h>

//#define REFRESH_SEAM_MATRIX_EVERY 64
/*
#define COLOR_TO_GREY_FACTOR_R 0.2126
#define COLOR_TO_GREY_FACTOR_G 0.7152
#define COLOR_TO_GREY_FACTOR_B 0.0722
*/
#define COLOR_TO_GREY_FACTOR_R 0.299
#define COLOR_TO_GREY_FACTOR_G 0.587
#define COLOR_TO_GREY_FACTOR_B 0.114

#define SEAM_MOVE_COST 0.25

struct Pixel {
    int r;
    int g;
    int b;
    int a;
    int bright;
    double gaussA;
    double gaussB;
    double sobelA;
    double energy;
    double seamval;
};

struct Pixel *createImageData(unsigned char *sImg, int sImgWidth, int sImgHeight, int pixelDepth, unsigned char *sImgMask, int faceCount, int *faceBoundsArray);
void carveSeamsVertical(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount, int padMode, int padR, int padG, int padB, int padA);

#endif /* defined(__Squared__SeamCarve__) */
