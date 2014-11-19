//
//  SeamCarve.c
//  Squared
//
//  Created by Christopher Stoll on 11/10/14.
//  Copyright (c) 2014 Christopher Stoll. All rights reserved.
//

#include "SeamCarve.h"

static inline int max(int a, int b)
{
    if (a > b) {
        return a;
    } else {
        return b;
    }
}
/*
static inline int max3(int a, int b, int c)
{
    if (a > b) {
        if (a > c) {
            return a;
        } else {
            return c;
        }
    } else {
        if (b > c) {
            return b;
        } else {
            return c;
        }
    }
}
*/
static inline int min(int a, int b)
{
    if (a < b) {
        return a;
    } else {
        return b;
    }
}

static inline int min3(int a, int b, int c)
{
    if (a < b) {
        if (a < c) {
            return a;
        } else {
            return c;
        }
    } else {
        if (b < c) {
            return b;
        } else {
            return c;
        }
    }
}

#pragma mark - pixel energy

static double getGreyValue(double r, double g, double b)
{
    return ((r * COLOR_TO_GREY_FACTOR_R) + (g * COLOR_TO_GREY_FACTOR_G) + (b * COLOR_TO_GREY_FACTOR_B));
}

static int getPixelGaussian(unsigned char *imageVector, int imageWidth, int imageHeight, int pixelDepth, int currentPixel, int sigma)
{
    int imageByteWidth = imageWidth * pixelDepth;
    int points[25];
    double pointValues[25];
        
    points[0] = currentPixel - imageByteWidth - imageByteWidth - pixelDepth - pixelDepth;
    points[1] = currentPixel - imageByteWidth - imageByteWidth - pixelDepth;
    points[2] = currentPixel - imageByteWidth - imageByteWidth;
    points[3] = currentPixel - imageByteWidth - imageByteWidth + pixelDepth;
    points[4] = currentPixel - imageByteWidth - imageByteWidth + pixelDepth + pixelDepth;
    
    points[5] = currentPixel - imageByteWidth - pixelDepth - pixelDepth;
    points[6] = currentPixel - imageByteWidth - pixelDepth;
    points[7] = currentPixel - imageByteWidth;
    points[8] = currentPixel - imageByteWidth + pixelDepth;
    points[9] = currentPixel - imageByteWidth + pixelDepth + pixelDepth;
    
    points[10] = currentPixel - pixelDepth - pixelDepth;
    points[11] = currentPixel - pixelDepth;
    points[12] = currentPixel;
    points[13] = currentPixel + pixelDepth;
    points[14] = currentPixel + pixelDepth + pixelDepth;
    
    points[15] = currentPixel + imageByteWidth - pixelDepth - pixelDepth;
    points[16] = currentPixel + imageByteWidth - pixelDepth;
    points[17] = currentPixel + imageByteWidth;
    points[18] = currentPixel + imageByteWidth + pixelDepth;
    points[19] = currentPixel + imageByteWidth + pixelDepth + pixelDepth;
    
    points[20] = currentPixel + imageByteWidth + imageByteWidth - pixelDepth - pixelDepth;
    points[21] = currentPixel + imageByteWidth + imageByteWidth - pixelDepth;
    points[22] = currentPixel + imageByteWidth + imageByteWidth;
    points[23] = currentPixel + imageByteWidth + imageByteWidth + pixelDepth;
    points[24] = currentPixel + imageByteWidth + imageByteWidth + pixelDepth + pixelDepth;
    
    // TODO: this is wrong, fix it
    for (int i = 0; i < 25; ++i) {
        if (points[i] < 0) {
            points[i] = 0;
        } else if (points[i] >= (imageHeight * imageWidth * pixelDepth)) {
            points[i] = (imageHeight * imageWidth * pixelDepth);
        }
    }

    // get the pixel values from the image array
    pointValues[0] = getGreyValue(imageVector[points[0]], imageVector[points[0]+1], imageVector[points[0]+2]);
    pointValues[1] = getGreyValue(imageVector[points[1]], imageVector[points[1]+1], imageVector[points[1]+2]);
    pointValues[2] = getGreyValue(imageVector[points[2]], imageVector[points[2]+1], imageVector[points[2]+2]);
    pointValues[3] = getGreyValue(imageVector[points[3]], imageVector[points[3]+1], imageVector[points[3]+2]);
    pointValues[4] = getGreyValue(imageVector[points[4]], imageVector[points[4]+1], imageVector[points[4]+2]);
    pointValues[5] = getGreyValue(imageVector[points[5]], imageVector[points[5]+1], imageVector[points[5]+2]);
    pointValues[6] = getGreyValue(imageVector[points[6]], imageVector[points[6]+1], imageVector[points[6]+2]);
    pointValues[7] = getGreyValue(imageVector[points[7]], imageVector[points[7]+1], imageVector[points[7]+2]);
    pointValues[8] = getGreyValue(imageVector[points[8]], imageVector[points[8]+1], imageVector[points[8]+2]);
    pointValues[9] = getGreyValue(imageVector[points[9]], imageVector[points[9]+1], imageVector[points[9]+2]);
    pointValues[10] = getGreyValue(imageVector[points[10]], imageVector[points[10]+1], imageVector[points[10]+2]);
    pointValues[11] = getGreyValue(imageVector[points[11]], imageVector[points[11]+1], imageVector[points[11]+2]);
    pointValues[12] = getGreyValue(imageVector[points[12]], imageVector[points[12]+1], imageVector[points[12]+2]);
    pointValues[13] = getGreyValue(imageVector[points[13]], imageVector[points[13]+1], imageVector[points[13]+2]);
    pointValues[14] = getGreyValue(imageVector[points[14]], imageVector[points[14]+1], imageVector[points[14]+2]);
    pointValues[15] = getGreyValue(imageVector[points[15]], imageVector[points[15]+1], imageVector[points[15]+2]);
    pointValues[16] = getGreyValue(imageVector[points[16]], imageVector[points[16]+1], imageVector[points[16]+2]);
    pointValues[17] = getGreyValue(imageVector[points[17]], imageVector[points[17]+1], imageVector[points[17]+2]);
    pointValues[18] = getGreyValue(imageVector[points[18]], imageVector[points[18]+1], imageVector[points[18]+2]);
    pointValues[19] = getGreyValue(imageVector[points[19]], imageVector[points[19]+1], imageVector[points[19]+2]);
    pointValues[20] = getGreyValue(imageVector[points[20]], imageVector[points[20]+1], imageVector[points[20]+2]);
    pointValues[21] = getGreyValue(imageVector[points[21]], imageVector[points[21]+1], imageVector[points[21]+2]);
    pointValues[22] = getGreyValue(imageVector[points[22]], imageVector[points[22]+1], imageVector[points[22]+2]);
    pointValues[23] = getGreyValue(imageVector[points[23]], imageVector[points[23]+1], imageVector[points[23]+2]);
    pointValues[24] = getGreyValue(imageVector[points[24]], imageVector[points[24]+1], imageVector[points[24]+2]);
    
    double gaussL1 = 0.0;
    double gaussL2 = 0.0;
    double gaussL3 = 0.0;
    double gaussL4 = 0.0;
    double gaussL5 = 0.0;
    double gaussAll = 0.0;
    if (sigma == 14) {
        // apply the gaussian kernel (sigma = 1.4)
        gaussL1 = (2 * pointValues[0]) + (4 * pointValues[1]) + (5 * pointValues[2]) + (4 * pointValues[3]) + (2 * pointValues[4]);
        gaussL2 = (4 * pointValues[5]) + (9 * pointValues[6]) + (12 * pointValues[7]) + (9 * pointValues[8]) + (4 * pointValues[9]);
        gaussL3 = (5 * pointValues[10]) + (12 * pointValues[11]) + (15 * pointValues[12]) + (12 * pointValues[13]) + (5 * pointValues[14]);
        gaussL4 = (4 * pointValues[15]) + (9 * pointValues[16]) + (12 * pointValues[17]) + (9 * pointValues[18]) + (4 * pointValues[19]);
        gaussL5 = (2 * pointValues[20]) + (4 * pointValues[21]) + (5 * pointValues[22]) + (4 * pointValues[23]) + (2 * pointValues[24]);
        gaussAll = (gaussL1 + gaussL2 + gaussL3 + gaussL4 + gaussL5) / 159;
    } else {
        // apply the gaussian kernel (sigma = 1)
        gaussL1 = (1 * pointValues[0]) + (4 * pointValues[1]) + (7 * pointValues[2]) + (4 * pointValues[3]) + (1 * pointValues[4]);
        gaussL2 = (4 * pointValues[5]) + (16 * pointValues[6]) + (26 * pointValues[7]) + (16 * pointValues[8]) + (4 * pointValues[9]);
        gaussL3 = (7 * pointValues[10]) + (26 * pointValues[11]) + (41 * pointValues[12]) + (26 * pointValues[13]) + (7 * pointValues[14]);
        gaussL4 = (4 * pointValues[15]) + (16 * pointValues[16]) + (26 * pointValues[17]) + (16 * pointValues[18]) + (4 * pointValues[19]);
        gaussL5 = (1 * pointValues[20]) + (4 * pointValues[21]) + (7 * pointValues[22]) + (4 * pointValues[23]) + (1 * pointValues[24]);
        gaussAll = (gaussL1 + gaussL2 + gaussL3 + gaussL4 + gaussL5) / 273;
    }
    
    return min(max((int)gaussAll, 0), 255);
}

static int getPixelEnergyDoG(unsigned char *imageVector, int currentPixel, int gaussianValue1, int gaussianValue2)
{
    //double currentValue = getGreyValue(imageVector[currentPixel], imageVector[currentPixel+1], imageVector[currentPixel+2]);
    if (gaussianValue1 > gaussianValue2) {
        return min(max( (int)((gaussianValue1 - gaussianValue2) * 8), 0), 255);
    } else {
        return min(max( (int)((gaussianValue2 - gaussianValue1) * 8), 0), 255);
    }
}

static int getPixelEnergySobel(unsigned char *imageVector, int imageWidth, int imageHeight, int pixelDepth, int currentPixel)
{
    int imageByteWidth = imageWidth * pixelDepth;
    int currentCol = currentPixel % imageByteWidth;
    int p1, p2, p3, p4, p6, p7, p8, p9;
    
    // get pixel locations within the image array
    // image border pixels have undefined (zero) energy
    if ((currentPixel > imageByteWidth) &&
        (currentPixel < (imageByteWidth * (imageHeight - 1))) &&
        (currentCol > 0) &&
        (currentCol < (imageByteWidth - 4))) {
        p1 = currentPixel - imageByteWidth - pixelDepth;
        p2 = currentPixel - imageByteWidth;
        p3 = currentPixel - imageByteWidth + pixelDepth;
        
        p4 = currentPixel - pixelDepth;
        //p5 = currentPixel;
        p6 = currentPixel + pixelDepth;
        
        p7 = currentPixel + imageByteWidth - pixelDepth;
        p8 = currentPixel + imageByteWidth;
        p9 = currentPixel + imageByteWidth + pixelDepth;
    } else {
        // TODO: consider attempting to evaluate border pixels
        return 33; // zero and INT_MAX are significant, so return 1
    }
    
    // get the pixel values from the image array
    double p1val = (double)(((double)imageVector[p1] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p1+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p1+2] * COLOR_TO_GREY_FACTOR_B));
    double p2val = (double)(((double)imageVector[p2] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p2+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p2+2] * COLOR_TO_GREY_FACTOR_B));
    double p3val = (double)(((double)imageVector[p3] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p3+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p3+2] * COLOR_TO_GREY_FACTOR_B));
    double p4val = (double)(((double)imageVector[p4] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p4+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p4+2] * COLOR_TO_GREY_FACTOR_B));
    double p6val = (double)(((double)imageVector[p6] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p6+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p6+2] * COLOR_TO_GREY_FACTOR_B));
    double p7val = (double)(((double)imageVector[p7] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p7+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p7+2] * COLOR_TO_GREY_FACTOR_B));
    double p8val = (double)(((double)imageVector[p8] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p8+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p8+2] * COLOR_TO_GREY_FACTOR_B));
    double p9val = (double)(((double)imageVector[p9] * COLOR_TO_GREY_FACTOR_R) +
                            ((double)imageVector[p9+1] * COLOR_TO_GREY_FACTOR_G) +
                            ((double)imageVector[p9+2] * COLOR_TO_GREY_FACTOR_B));
    /*
    double p1val = (double)max3(imageVector[p1], imageVector[p1+1], imageVector[p1+2]);
    double p2val = (double)max3(imageVector[p2], imageVector[p2+1], imageVector[p2+2]);
    double p3val = (double)max3(imageVector[p3], imageVector[p3+1], imageVector[p3+2]);
    double p4val = (double)max3(imageVector[p4], imageVector[p4+1], imageVector[p4+2]);
    double p6val = (double)max3(imageVector[p6], imageVector[p6+1], imageVector[p6+2]);
    double p7val = (double)max3(imageVector[p7], imageVector[p7+1], imageVector[p7+2]);
    double p8val = (double)max3(imageVector[p8], imageVector[p8+1], imageVector[p8+2]);
    double p9val = (double)max3(imageVector[p9], imageVector[p9+1], imageVector[p9+2]);
    */
    // apply the sobel filter
    double sobelX = (p3val + (p6val + p6val) + p9val - p1val - (p4val + p4val) - p7val);
    double sobelY = (p1val + (p2val + p2val) + p3val - p7val - (p8val + p8val) - p9val);
    
    // bounded gradient magnitude
    //printf("%f \n", sqrt((sobelX * sobelX) + (sobelY * sobelY)));
    return min(max( (int)(sqrt((sobelX * sobelX) + (sobelY * sobelY))/1) , 0), 255);
}

#pragma mark - horizontal methods

static void setPixelPathHorizontal(struct Pixel *image, int imageWidth, int imageHeight, int unsigned currentPixel, int currentRow)
{
    int pixelLeft = 0;
    int leftT = 0;
    int leftM = 0;
    int leftB = 0;
    int newValue = 0;
    
    pixelLeft = currentPixel - 1;
    // avoid falling off the top
    if (currentRow > 0) {
        // avoid falling off the bottom
        if (currentRow < (imageHeight - 1)) {
            leftT = image[pixelLeft - imageWidth].seamval;
            leftM = image[pixelLeft].seamval;
            leftB = image[pixelLeft + imageWidth].seamval;
            newValue = min3(leftT, leftM, leftB);
        } else {
            leftT = image[pixelLeft - imageWidth].seamval;
            leftM = image[pixelLeft].seamval;
            //leftB = INT_MAX;
            newValue = min(leftT, leftM);
        }
    } else {
        //leftT = INT_MAX;
        leftM = image[pixelLeft].seamval;
        leftB = image[pixelLeft + imageWidth].seamval;
        newValue = min(leftM, leftB);
    }
    image[currentPixel].seamval += newValue;
}

static void fillSeamMatrixHorizontal(struct Pixel *image, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    // do not process the first col, start with i=1
    // must be in reverse order from verticle seam, calulate colums as we move across (top down, left to right)
    for (int i = 1; i < imageWidth; ++i) {
        for (int j = 0; j < imageHeight; ++j) {
            currentPixel = (j * imageWidth) + i;
            if (image[currentPixel].seamval != INT_MAX) {
                image[currentPixel].seamval = image[currentPixel].energy;
                setPixelPathHorizontal(image, imageWidth, imageHeight, currentPixel, j);
            }
        }
    }
}

static void cutSeamHorizontal(struct Pixel *image, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    int minsFound = 0;
    int minValue = INT_MAX;
    int *minLocs = (int*)calloc((unsigned long)imageHeight, sizeof(int));
    
    for (int i = 1; i < imageHeight; ++i) {
        currentPixel = (i * imageWidth) - 1;
        if ((image[currentPixel].seamval > 0) && (image[currentPixel].seamval != INT_MAX)) {
            // find all minimum values
            if (image[currentPixel].seamval <= minValue) {
                // this is a new minimum, so clear the min list and store just this minimum
                if (image[currentPixel].seamval < minValue) {
                    minsFound = 0;
                    minValue = image[currentPixel].seamval;
                    minLocs[minsFound] = currentPixel;
                    
                // this is a duplicate minimum, so add it to the list
                } else {
                    ++minsFound;
                    minLocs[minsFound] = currentPixel;
                }
            }
        } else {
            break;
        }
    }
    
    int minLocation = minLocs[0];
    // when there is more than one seam with the same minimum value
    // randomly pick one of the minimums so that we do not have all
    // of the seams taken from the top of the image
    if (minsFound) {
        int minToTake = rand() % minsFound;
        minLocation = minLocs[minToTake];
    }
    free(minLocs);
    
    int *path = (int*)calloc((unsigned long)imageWidth, sizeof(int));
    int pixelLeft = 0;
    int currentRow = 0;
    int leftA = 0;
    int leftC = 0;
    int leftB = 0;
    int newValue = 0;
    
    currentPixel = minLocation;
    int loopEnd = (imageWidth - 1);
    for (int j = 0; j < loopEnd; ++j) {
        path[j] = currentPixel;
        pixelLeft = currentPixel - 1;
        
        // avoid falling off the top
        if ((currentPixel > imageWidth) && (image[pixelLeft - imageWidth].seamval > 0)) {
            // avoid falling off the right end
            if ((currentPixel < ((imageWidth * imageHeight) - imageWidth)) && (image[pixelLeft + imageWidth].seamval > 0)) {
                leftA = image[pixelLeft - imageWidth].seamval;
                leftC = image[pixelLeft].seamval;
                leftB = image[pixelLeft + imageWidth].seamval;
                newValue = min3(leftA, leftC, leftB);
            } else {
                leftA = image[pixelLeft - imageWidth].seamval;
                leftC = image[pixelLeft].seamval;
                //leftB = INT_MAX;
                newValue = min(leftA, leftC);
            }
        } else {
            //leftA = INT_MAX;
            leftC = image[pixelLeft].seamval;
            leftB = image[pixelLeft + imageWidth].seamval;
            newValue = min(leftC, leftB);
        }
        
        if (newValue == leftC) {
            currentPixel = pixelLeft;
        } else if (newValue == leftB) {
            currentPixel = pixelLeft + imageWidth;
        } else {
            currentPixel = pixelLeft - imageWidth;
        }
    }
    
    int outerEnd = (imageWidth-1);
    int innterEnd = (imageHeight - 1);
    for (int j = 0; j < outerEnd; ++j) {
        currentPixel = path[j];
        currentRow = currentPixel / imageWidth;
        
        for (int i = currentRow; i < innterEnd; ++i) {
            if ((image[currentPixel].seamval >= 0) && (image[currentPixel].seamval != INT_MAX)) {
                image[currentPixel] = image[currentPixel+imageWidth];
                currentPixel += imageWidth;
            } else {
                break;
            }
        }
        image[currentPixel].seamval = INT_MAX;
    }
    
    free(path);
}

#pragma mark - vertical methods

static void setPixelPathVertical(struct Pixel *image, int imageWidth, int imageHeight, int unsigned currentPixel, int currentCol)
{
    int pixelAbove = 0;
    int aboveL = 0;
    int aboveC = 0;
    int aboveR = 0;
    int newValue = 0;
    
    pixelAbove = currentPixel - imageWidth;
    // avoid falling off the left end
    if (currentCol > 0) {
        // avoid falling off the right end
        if (currentCol < imageWidth) {
            aboveL = image[pixelAbove - 1].seamval;
            aboveC = image[pixelAbove].seamval;
            aboveR = image[pixelAbove + 1].seamval;
            newValue = min3(aboveL, aboveC, aboveR);
        } else {
            aboveL = image[pixelAbove - 1].seamval;
            aboveC = image[pixelAbove].seamval;
            //aboveR = INT_MAX;
            newValue = min(aboveL, aboveC);
        }
    } else {
        //aboveL = INT_MAX;
        aboveC = image[pixelAbove].seamval;
        aboveR = image[pixelAbove + 1].seamval;
        newValue = min(aboveC, aboveR);
    }
    image[currentPixel].seamval += newValue;
}

static void fillSeamMatrixVertical(struct Pixel *image, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    // do not process the first row, start with j=1
    for (int j = 1; j < imageHeight; ++j) {
        for (int i = 0; i < imageWidth; ++i) {
            currentPixel = (j * imageWidth) + i;
            if (image[currentPixel].seamval != INT_MAX) {
                image[currentPixel].seamval = image[currentPixel].energy;
                setPixelPathVertical(image, imageWidth, imageHeight, currentPixel, i);
            }
        }
    }
}

static void cutSeamVertical(struct Pixel *image, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    int minsFound = 0;
    int minValue = INT_MAX;
    int *minLocs = (int*)calloc((unsigned long)imageHeight, sizeof(int));

    for (int i = 0; i < imageWidth; ++i) {
        currentPixel = ((imageHeight - 1) * imageWidth) + i;
        if ((image[currentPixel].seamval > 0) && (image[currentPixel].seamval != INT_MAX)) {
            // find all minimum values
            if (image[currentPixel].seamval <= minValue) {
                // this is a new minimum, so clear the min list and store just this minimum
                if (image[currentPixel].seamval < minValue) {
                    minsFound = 0;
                    minValue = image[currentPixel].seamval;
                    minLocs[minsFound] = currentPixel;
                    
                // this is a duplicate minimum, so add it to the list
                } else {
                    ++minsFound;
                    minLocs[minsFound] = currentPixel;
                }
            }
        } else {
            break;
        }
    }
    
    
    int minLocation = minLocs[0];
    // when there is more than one seam with the same minimum value
    // randomly pick one of the minimums so that we do not have all
    // of the seams taken from the left of the image
    if (minsFound) {
        int minToTake = rand() % minsFound;
        minLocation = minLocs[minToTake];
    }
    free(minLocs);
    
    int *path = (int*)calloc((unsigned long)imageHeight, sizeof(int));
    int pixelAbove = 0;
    int currentCol = 0;
    int aboveL = 0;
    int aboveC = 0;
    int aboveR = 0;
    int newValue = 0;
    
    currentPixel = minLocation;
    for (int j = 0; j < imageHeight; ++j) {
        path[j] = currentPixel;
        pixelAbove = currentPixel - imageWidth;
        currentCol = currentPixel % imageWidth;
        
        // avoid falling off the left end
        if ((currentCol > 0) && (image[pixelAbove - 1].seamval > 0)) {
            // avoid falling off the right end
            if ((currentCol < imageWidth) && (image[pixelAbove + 1].seamval > 0)) {
                aboveL = image[pixelAbove - 1].seamval;
                aboveC = image[pixelAbove].seamval;
                aboveR = image[pixelAbove + 1].seamval;
                newValue = min3(aboveL, aboveC, aboveR);
            } else {
                aboveL = image[pixelAbove - 1].seamval;
                aboveC = image[pixelAbove].seamval;
                //aboveR = INT_MAX;
                newValue = min(aboveL, aboveC);
            }
        } else {
            aboveL = INT_MAX;
            aboveC = image[pixelAbove].seamval;
            aboveR = image[pixelAbove + 1].seamval;
            newValue = min(aboveC, aboveR);
        }
        
        if (newValue == aboveC) {
            currentPixel = pixelAbove;
        } else if (newValue == aboveL) {
            currentPixel = pixelAbove - 1;
        } else {
            currentPixel = pixelAbove + 1;
        }
    }
    
    int loopEnd = (imageWidth - 1);
    for (int j = 0; j < imageHeight; ++j) {
        currentPixel = path[j];
        currentCol = currentPixel % imageWidth;
        
        for (int i = currentCol; i < loopEnd; ++i) {
            if ((image[currentPixel].seamval >= 0) && (image[currentPixel].seamval != INT_MAX)) {
                image[currentPixel] = image[currentPixel+1];
                ++currentPixel;
            } else {
                break;
            }
        }
        image[currentPixel].seamval = INT_MAX;
    }
    
    free(path);
}

#pragma mark -

void carveSeams(unsigned char *sImg, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int goHorizontal, int faceCount, int *faceBoundsArray)
{
    struct Pixel *image = (struct Pixel *)calloc(((size_t)sImgWidth * (size_t)sImgHeight), sizeof(struct Pixel));
    
    int sImgPixelLoc = 0;
    int pixelLocation = 0;
    int pixelWidth = sImgWidth * pixelDepth;
    for (int j = 0; j < sImgHeight; ++j) {
        for (int i = 0; i < sImgWidth; ++i) {
            sImgPixelLoc = (j * pixelWidth) + (i * pixelDepth);
            pixelLocation = (j * sImgWidth) + i;
            struct Pixel currentPixel;
            currentPixel.r = sImg[sImgPixelLoc];
            currentPixel.g = sImg[sImgPixelLoc+1];
            currentPixel.b = sImg[sImgPixelLoc+2];
            currentPixel.a = sImg[sImgPixelLoc+3];
            
            currentPixel.energy = getPixelEnergySobel(sImg, sImgWidth, sImgHeight, pixelDepth, sImgPixelLoc);
            //currentPixel.gauss1 = getPixelGaussian(sImg, sImgWidth, sImgHeight, pixelDepth, sImgPixelLoc, 14);
            //currentPixel.gauss2 = getPixelGaussian(sImg, sImgWidth, sImgHeight, pixelDepth, sImgPixelLoc, 10);
            //currentPixel.energy = getPixelEnergyDoG(sImg, sImgPixelLoc, currentPixel.gauss1, currentPixel.gauss2);
            //currentPixel.energy = currentPixel.gauss2;
            
            currentPixel.seamval = currentPixel.energy;
            image[pixelLocation] = currentPixel;
        }
    }
    
    int faceBeginX = 0;
    int faceBeginY = 0;
    int faceWidth = 0;
    int faceHeight = 0;
    int faceBoundLoc = 0;
    for (int i = 0; i < faceCount; ++i) {
        faceBeginX = faceBoundsArray[faceBoundLoc];
        ++faceBoundLoc;
        
        faceBeginY = faceBoundsArray[faceBoundLoc];
        ++faceBoundLoc;
        
        faceWidth = faceBoundsArray[faceBoundLoc];
        ++faceBoundLoc;
        
        faceHeight = faceBoundsArray[faceBoundLoc];
        ++faceBoundLoc;
        
        int xLoopBegin = faceBeginX;
        int yLoopBegin = sImgHeight - (faceBeginY + faceHeight);
        int xLoopEnd = (faceBeginX + faceWidth);
        int yLoopEnd = sImgHeight - faceBeginY;
        for (int j = yLoopBegin; j < yLoopEnd; ++j) {
            for (int k = xLoopBegin; k < xLoopEnd; ++k) {
                pixelLocation = (j * sImgWidth) + k;
                image[pixelLocation].energy = image[pixelLocation].energy * 2;
            }
        }
    }
    
    // rand() is used in seam cutting, but only need to seed it once per thread
    srand((int)time(0));
    
    int seamRemovalCount = 0;
    if (goHorizontal) {
        fillSeamMatrixHorizontal(image, sImgWidth, sImgHeight);
        
        seamRemovalCount = sImgHeight - tImgHeight;
        for (int i = 0; i < seamRemovalCount; ++i) {
            cutSeamHorizontal(image, sImgWidth, sImgHeight);
            if ((i % REFRESH_SEAM_MATRIX_EVERY) == 0) {
                fillSeamMatrixHorizontal(image, sImgWidth, sImgHeight);
            }
        }
    } else {
        fillSeamMatrixVertical(image, sImgWidth, sImgHeight);
        
        seamRemovalCount = sImgWidth - tImgWidth;
        for (int i = 0; i < seamRemovalCount; ++i) {
            cutSeamVertical(image, sImgWidth, sImgHeight);
            if ((i % REFRESH_SEAM_MATRIX_EVERY) == 0) {
                fillSeamMatrixVertical(image, sImgWidth, sImgHeight);
            }
        }
    }
    
    int tImgPixelLoc = 0;
    for (int j = 0; j < tImgHeight; ++j) {
        for (int i = 0; i < tImgWidth; ++i) {
            tImgPixelLoc = (j * (tImgWidth * pixelDepth)) + (i * pixelDepth);
            pixelLocation = (j * sImgWidth) + i;
            /*
            tImg[tImgPixelLoc]   = image[pixelLocation].r;
            tImg[tImgPixelLoc+1] = image[pixelLocation].g;
            tImg[tImgPixelLoc+2] = image[pixelLocation].b;
            tImg[tImgPixelLoc+3] = image[pixelLocation].a;
            */
            tImg[tImgPixelLoc]   = image[pixelLocation].energy;
            tImg[tImgPixelLoc+1] = image[pixelLocation].energy;
            tImg[tImgPixelLoc+2] = image[pixelLocation].energy;
            tImg[tImgPixelLoc+3] = 255;
            
        }
    }
    free(image);
}

#pragma mark - public functions

void carveSeamsHorizontal(unsigned char *sImg, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int faceCount, int *faceBoundsArray)
{
    carveSeams(sImg, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, pixelDepth, 1, faceCount, faceBoundsArray);
}

void carveSeamsVertical(unsigned char *sImg, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int faceCount, int *faceBoundsArray)
{
    carveSeams(sImg, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, pixelDepth, 0, faceCount, faceBoundsArray);
}
