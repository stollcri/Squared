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

static inline double min(double a, double b)
{
    if (a < b) {
        return a;
    } else {
        return b;
    }
}

static inline double min3(double a, double b, double c)
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

static double getPixelEnergySobel(unsigned char *imageVector, int imageWidth, int imageHeight, int pixelDepth, int currentPixel)
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
    
    // apply the sobel filter
    double sobelX = (p3val + (p6val + p6val) + p9val - p1val - (p4val + p4val) - p7val);
    double sobelY = (p1val + (p2val + p2val) + p3val - p7val - (p8val + p8val) - p9val);
    
    return sqrt((sobelX * sobelX) + (sobelY * sobelY));
    // bounded gradient magnitude
    //return min(max((int)(sqrt((sobelX * sobelX) + (sobelY * sobelY))/2) , 0), 255);
}

static double getPixelEnergyGaussian(struct Pixel *imageVector, int imageWidth, int imageHeight, int pixelDepth, int currentPixel, int sigma)
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
        } else if (points[i] >= (imageHeight * imageWidth)) {
            points[i] = (imageHeight * imageWidth) - pixelDepth;
        }
    }
    
    // get the pixel values from the image array
    pointValues[0] = (double)imageVector[points[0]].bright;
    pointValues[1] = (double)imageVector[points[1]].bright;
    pointValues[2] = (double)imageVector[points[2]].bright;
    pointValues[3] = (double)imageVector[points[3]].bright;
    pointValues[4] = (double)imageVector[points[4]].bright;
    pointValues[5] = (double)imageVector[points[5]].bright;
    pointValues[6] = (double)imageVector[points[6]].bright;
    pointValues[7] = (double)imageVector[points[7]].bright;
    pointValues[8] = (double)imageVector[points[8]].bright;
    pointValues[9] = (double)imageVector[points[9]].bright;
    pointValues[10] = (double)imageVector[points[10]].bright;
    pointValues[11] = (double)imageVector[points[11]].bright;
    pointValues[12] = (double)imageVector[points[12]].bright;
    pointValues[13] = (double)imageVector[points[13]].bright;
    pointValues[14] = (double)imageVector[points[14]].bright;
    pointValues[15] = (double)imageVector[points[15]].bright;
    pointValues[16] = (double)imageVector[points[16]].bright;
    pointValues[17] = (double)imageVector[points[17]].bright;
    pointValues[18] = (double)imageVector[points[18]].bright;
    pointValues[19] = (double)imageVector[points[19]].bright;
    pointValues[20] = (double)imageVector[points[20]].bright;
    pointValues[21] = (double)imageVector[points[21]].bright;
    pointValues[22] = (double)imageVector[points[22]].bright;
    pointValues[23] = (double)imageVector[points[23]].bright;
    pointValues[24] = (double)imageVector[points[24]].bright;
    
    double gaussL1 = 0.0;
    double gaussL2 = 0.0;
    double gaussL3 = 0.0;
    double gaussL4 = 0.0;
    double gaussL5 = 0.0;
    double gaussAll = 0.0;
    double gaussDvsr = 1.0;
    double weights[25];
    
    if (sigma == 10) {
        gaussDvsr = 273;
        weights[0]  = 1;
        weights[1]  = 4;
        weights[2]  = 7;
        weights[6]  = 16;
        weights[7]  = 26;
        weights[12] = 41;
    } else if (sigma == 12) {
        weights[0]  = 0.008173;
        weights[1]  = 0.021861;
        weights[2]  = 0.030337;
        weights[6]  = 0.058473;
        weights[7]  = 0.081144;
        weights[12] = 0.112606;
    } else if (sigma == 13) {
        weights[0]  = 0.010534;
        weights[1]  = 0.024530;
        weights[2]  = 0.032508;
        weights[6]  = 0.057120;
        weights[7]  = 0.075698;
        weights[12] = 0.100318;
    } else if (sigma == 14) {
        gaussDvsr = 159;
        weights[0]  = 2;
        weights[1]  = 4;
        weights[2]  = 5;
        weights[6]  = 9;
        weights[7]  = 12;
        weights[12] = 15;
    } else if (sigma == 16) {
        weights[0]  = 0.017056;
        weights[1]  = 0.030076;
        weights[2]  = 0.036334;
        weights[6]  = 0.053035;
        weights[7]  = 0.064071;
        weights[12] = 0.077404;
    }
    // line 1 has 2 duplicated values
    weights[3] = weights[1];
    weights[4] = weights[0];
    // line 2 has 3 duplicated values
    weights[5] = weights[1];
    weights[8] = weights[6];
    weights[9] = weights[5];
    // line 3 has 4 duplicated values
    weights[10] = weights[2];
    weights[11] = weights[7];
    weights[13] = weights[11];
    weights[14] = weights[10];
    // line 4 is the same as line 2
    weights[15] = weights[5];
    weights[16] = weights[6];
    weights[17] = weights[7];
    weights[18] = weights[8];
    weights[19] = weights[9];
    // line 5 is the  same as line 1
    weights[20] = weights[0];
    weights[21] = weights[1];
    weights[22] = weights[2];
    weights[23] = weights[3];
    weights[24] = weights[4];
    
    gaussL1 = (weights[1]  * pointValues[0])  + (weights[1]  * pointValues[1])  + (weights[2]  * pointValues[2])  + (weights[3]  * pointValues[3])  + (weights[4]  * pointValues[4]);
    gaussL2 = (weights[5]  * pointValues[5])  + (weights[6]  * pointValues[6])  + (weights[7]  * pointValues[7])  + (weights[8]  * pointValues[8])  + (weights[9]  * pointValues[9]);
    gaussL3 = (weights[10] * pointValues[10]) + (weights[11] * pointValues[11]) + (weights[12] * pointValues[12]) + (weights[13] * pointValues[13]) + (weights[14] * pointValues[14]);
    gaussL4 = (weights[15] * pointValues[15]) + (weights[16] * pointValues[16]) + (weights[17] * pointValues[17]) + (weights[18] * pointValues[18]) + (weights[19] * pointValues[19]);
    gaussL5 = (weights[20] * pointValues[20]) + (weights[21] * pointValues[21]) + (weights[22] * pointValues[22]) + (weights[23] * pointValues[23]) + (weights[24] * pointValues[24]);
    gaussAll = (gaussL1 + gaussL2 + gaussL3 + gaussL4 + gaussL5) / gaussDvsr;
    
    return gaussAll;
    //return min(max((int)gaussAll, 0), 255);
}

#pragma mark - vertical methods

static void setPixelPathVertical(struct Pixel *image, int imageWidth, int imageHeight, int unsigned currentPixel, int currentCol)
{
    int pixelAbove = 0;
    double aboveL = 0;
    double aboveC = 0;
    double aboveR = 0;
    double newValue = 0;
    
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
    if (image[currentPixel].seamval > 1) {
        if (image[currentPixel].seamval < 255) {
            image[currentPixel].seamval -= SEAM_MOVE_COST;
        //} else {
            //image[currentPixel].seamval = 255;
        }
    }
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
            } else {
                break;
            }
        }
    }
}

static void cutSeamVertical(struct Pixel *image, int imageWidth, int imageHeight, int *minLocs, int *path)
{
    int currentPixel = 0;
    int minsFound = 0;
    int minValue = INT_MAX;

    for (int i = 0; i < imageWidth; ++i) {
        currentPixel = ((imageHeight * imageWidth) - imageWidth) + i;
        if ((image[currentPixel].seamval > 0) && (image[currentPixel].seamval != INT_MAX)) {
            // find all minimum values
            if (image[currentPixel].seamval <= minValue) {
                // this is a new minimum, so clear the min list and store just this minimum
                if (image[currentPixel].seamval < minValue) {
                    minValue = image[currentPixel].seamval;
                    minLocs[0] = currentPixel;
                    minsFound = 1;
                    
                // this is a duplicate minimum, so add it to the list
                } else {
                    minLocs[minsFound] = currentPixel;
                    ++minsFound;
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
    if (minsFound > 1) {
        int minToTake = rand() % minsFound;
        minLocation = minLocs[minToTake];
    }
    
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
        
        if (pixelAbove < 0) {
            break;
        }
        
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
}

#pragma mark -

void carveSeams(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount, int goHorizontal)
{
    // rand() is used in seam cutting, but only need to seed it once per thread
    srand((int)time(0));
    
    fillSeamMatrixVertical(sImgPixels, sImgWidth, sImgHeight);
    
    int *minLocs = (int*)calloc((unsigned long)sImgWidth, sizeof(int));
    int *path = (int*)calloc((unsigned long)sImgHeight, sizeof(int));
    
    for (int i = 0; i < carveCount; ++i) {
        cutSeamVertical(sImgPixels, sImgWidth, sImgHeight, minLocs, path);
    }
    
    free(path);
    free(minLocs);
    
    int tImgPixelLoc = 0;
    int pixelLocation = 0;
    for (int j = 0; j < tImgHeight; ++j) {
        for (int i = 0; i < tImgWidth; ++i) {
            tImgPixelLoc = (j * (tImgWidth * pixelDepth)) + (i * pixelDepth);
            pixelLocation = (j * sImgWidth) + i;
            
            tImg[tImgPixelLoc]   = sImgPixels[pixelLocation].r;
            tImg[tImgPixelLoc+1] = sImgPixels[pixelLocation].g;
            tImg[tImgPixelLoc+2] = sImgPixels[pixelLocation].b;
            tImg[tImgPixelLoc+3] = sImgPixels[pixelLocation].a;
            
            /*
            tImg[tImgPixelLoc]   = (int)sImgPixels[pixelLocation].seamval;
            tImg[tImgPixelLoc+1] = (int)sImgPixels[pixelLocation].seamval;
            tImg[tImgPixelLoc+2] = (int)sImgPixels[pixelLocation].seamval;
            tImg[tImgPixelLoc+3] = 255;
            */
            /*
            tImg[tImgPixelLoc]   = (int)sImgPixels[pixelLocation].energy;
            tImg[tImgPixelLoc+1] = (int)sImgPixels[pixelLocation].energy;
            tImg[tImgPixelLoc+2] = (int)sImgPixels[pixelLocation].energy;
            tImg[tImgPixelLoc+3] = 255;
            */
        }
    }
}

#pragma mark - public functions

struct Pixel *createImageData(unsigned char *sImg, int sImgWidth, int sImgHeight, int pixelDepth, unsigned char *sImgMask, int faceCount, int *faceBoundsArray)
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
            currentPixel.bright = (int)(((double)sImg[sImgPixelLoc] * COLOR_TO_GREY_FACTOR_R) +
                                        ((double)sImg[sImgPixelLoc+1] * COLOR_TO_GREY_FACTOR_G) +
                                        ((double)sImg[sImgPixelLoc+2] * COLOR_TO_GREY_FACTOR_B));
            currentPixel.sobelA = getPixelEnergySobel(sImg, sImgWidth, sImgHeight, pixelDepth, sImgPixelLoc);
            currentPixel.energy = 1.0;
            currentPixel.seamval = 1.0;
            
            image[pixelLocation] = currentPixel;
        }
    }
    
    for (int j = 0; j < sImgHeight; ++j) {
        for (int i = 0; i < sImgWidth; ++i) {
            pixelLocation = (j * sImgWidth) + i;
            //image[pixelLocation].gaussA = getPixelEnergyGaussian(image, sImgWidth, sImgHeight, pixelDepth, pixelLocation, 12);
            //image[pixelLocation].gaussB = getPixelEnergyGaussian(image, sImgWidth, sImgHeight, pixelDepth, pixelLocation, 13);
            image[pixelLocation].gaussA = getPixelEnergyGaussian(image, sImgWidth, sImgHeight, pixelDepth, pixelLocation, 14);
            image[pixelLocation].gaussB = getPixelEnergyGaussian(image, sImgWidth, sImgHeight, pixelDepth, pixelLocation, 16);
        }
    }
    
    int energyGwthS;
    //int energyGandS;
    for (int j = 0; j < sImgHeight; ++j) {
        for (int i = 0; i < sImgWidth; ++i) {
            sImgPixelLoc = (j * pixelWidth) + (i * pixelDepth);
            pixelLocation = (j * sImgWidth) + i;
            double gaussianValue1 = image[pixelLocation].gaussA;
            double gaussianValue2 = image[pixelLocation].gaussB;
            double gaussianDifference = abs(gaussianValue1 - gaussianValue2);
            
            energyGwthS = (gaussianDifference + (image[pixelLocation].sobelA / 100) * 20);
            //energyGandS = 0;//((int)gaussianDifference & (int)(image[pixelLocation].sobelA / 100)) * 32;
            //image[pixelLocation].energy = min(max((energyGwthS + energyGandS), 0), 255);
            image[pixelLocation].energy = min(max(energyGwthS, 0), 255);
            
            // handle freeze/melt masks
            if (sImgMask[sImgPixelLoc] >= 255) {
                // if it just zero then the seams become straight and more unnatural
                image[pixelLocation].energy = (image[pixelLocation].energy / 97);
            }
            if (sImgMask[sImgPixelLoc+2] >= 255) {
                image[pixelLocation].energy = ((image[pixelLocation].energy + 1) * 13);
            }
        }
    }
    
    // handle faces
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
                image[pixelLocation].energy = ((image[pixelLocation].energy + 1) * 7);
            }
        }
    }
    
    return image;
}

void carveSeamsVertical(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount)
{
    carveSeams(sImgPixels, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, pixelDepth, carveCount, 0);
}
