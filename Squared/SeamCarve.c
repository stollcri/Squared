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

static int getPixelEnergySobel(char *imageVector, int imageWidth, int imageHeight, int pixelDepth, int currentPixel)
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
        p4 = currentPixel;
        p6 = currentPixel + pixelDepth;
        
        p7 = currentPixel + imageByteWidth - pixelDepth;
        p8 = currentPixel + imageByteWidth;
        p9 = currentPixel + imageByteWidth + pixelDepth;
    } else {
        // TODO: consider attempting to evaluate border pixels
        return 1; // zero and INT_MAX are significant, so return 1
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
    
    // bounded gradient magnitude
    return min(max( (int)(sqrt((sobelX * sobelX) + (sobelY * sobelY))/4) , 0), 255);
}

#pragma mark - horizontal methods

static void setPixelPathHorizontal(int *imageSeams, int imageWidth, int imageHeight, int unsigned currentPixel, int currentCol)
{
    // avoid falling off the right
    if (currentCol < imageWidth) {
        int pixelLeft = 0;
        int leftT = 0;
        int leftM = 0;
        int leftB = 0;
        int newValue = 0;
        
        pixelLeft = currentPixel - 1;
        // avoid falling off the top
        if (currentPixel > imageWidth) {
            // avoid falling off the bottom
            if (currentPixel < ((imageWidth * imageHeight) - imageWidth)) {
                leftT = imageSeams[pixelLeft - imageWidth];
                leftM = imageSeams[pixelLeft];
                leftB = imageSeams[pixelLeft + imageWidth];
                newValue = min3(leftT, leftM, leftB);
            } else {
                leftT = imageSeams[pixelLeft - imageWidth];
                leftM = imageSeams[pixelLeft];
                leftB = INT_MAX;
                newValue = min(leftT, leftM);
            }
        } else {
            leftT = INT_MAX;
            leftM = imageSeams[pixelLeft];
            leftB = imageSeams[pixelLeft + imageWidth];
            newValue = min(leftM, leftB);
        }
        imageSeams[currentPixel] += newValue;
    }
}

static void fillSeamMatrixHorizontal(int *imageEnergies, int *imageSeams, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    // do not process the first row, start with j=1
    // must be in reverse order from verticle seam, calulate colums as we move across (top down, left to right)
    for (int i = 0; i < imageWidth; ++i) {
        for (int j = 1; j < imageHeight; ++j) {
            currentPixel = (j * imageWidth) + i;
            if (imageSeams[currentPixel] != INT_MAX) {
                imageSeams[currentPixel] = imageEnergies[currentPixel];
                setPixelPathHorizontal(imageSeams, imageWidth, imageHeight, currentPixel, i);
            }
        }
    }
}

static void cutSeamHorizontal(int *imageEnergies, int *imageSeams, char *imageColor, int imageWidth, int imageHeight)
{
    int *path = (int*)malloc((unsigned long)imageHeight * sizeof(int));
    
    int currentPixel = 0;
    int minValue = INT_MAX;
    int minLocation = 0;
    
    //for (int i = 0; i < imageWidth; ++i) {
    for (int i = 0; i < imageHeight; ++i) {
        currentPixel = ((imageHeight - 1) * imageWidth) + i;
        if ((imageSeams[currentPixel] > 0) && (imageSeams[currentPixel] != INT_MAX)) {
            if (imageSeams[currentPixel] <= minValue) {
                minValue = imageSeams[currentPixel];
                minLocation = currentPixel;
            }
        } else {
            break;
        }
    }
    
    int pixelLeft = 0;
    int currentRow = 0;
    int leftA = 0;
    int leftC = 0;
    int leftB = 0;
    int newValue = 0;
    
    currentPixel = minLocation;
    //for (int j = 0; j < imageHeight; ++j) {
    for (int j = 0; j < imageWidth; ++j) {
        path[j] = currentPixel;
        pixelLeft = currentPixel - 1;
        currentRow = currentPixel / imageWidth;
        
        // avoid falling off the top
        if ((currentRow > 0) && (imageSeams[pixelLeft - imageWidth] != 0)) {
            // avoid falling off the right end
            if ((currentRow < imageHeight) && (imageSeams[pixelLeft + imageWidth] != 0)) {
                leftA = imageSeams[pixelLeft - imageWidth];
                leftC = imageSeams[pixelLeft];
                leftB = imageSeams[pixelLeft + imageWidth];
                newValue = min3(leftA, leftC, leftB);
            } else {
                leftA = imageSeams[pixelLeft - imageWidth];
                leftC = imageSeams[pixelLeft];
                leftB = INT_MAX;
                newValue = min(leftA, leftC);
            }
        } else {
            leftA = INT_MAX;
            leftC = imageSeams[pixelLeft];
            leftB = imageSeams[pixelLeft + imageWidth];
            newValue = min(leftC, leftB);
        }
        
        if (newValue == leftC) {
            currentPixel = pixelLeft;
        } else if (newValue == leftA) {
            currentPixel = pixelLeft - imageWidth;
        } else {
            currentPixel = pixelLeft + imageWidth;
        }
    }
    
    int colorPixel = 0;
    //for (int j = 0; j < imageHeight; ++j) {
    for (int j = 0; j < imageWidth; ++j) {
        currentPixel = path[j];
        currentRow = currentPixel / imageWidth;
        
        //for (int i = currentCol; i < (imageWidth - 1); ++i) {
        for (int i = currentRow; i < (imageHeight - 1); ++i) {
            if ((imageSeams[currentPixel] > 0) && (imageSeams[currentPixel] != INT_MAX)) {
                imageEnergies[currentPixel] = imageEnergies[currentPixel+imageWidth];
                imageSeams[currentPixel] = imageSeams[currentPixel+imageWidth];
                
                colorPixel = currentPixel * 4;
                imageColor[colorPixel] = imageColor[colorPixel+4];
                imageColor[colorPixel+1] = imageColor[colorPixel+5];
                imageColor[colorPixel+2] = imageColor[colorPixel+6];
                imageColor[colorPixel+3] = imageColor[colorPixel+7];
                
                ++currentPixel;
            } else {
                break;
            }
        }
        imageSeams[currentPixel] = INT_MAX;
    }
}

#pragma mark - vertical methods

static void setPixelPathVertical(int *imageSeams, int imageWidth, int imageHeight, int unsigned currentPixel, int currentCol)
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
            aboveL = imageSeams[pixelAbove - 1];
            aboveC = imageSeams[pixelAbove];
            aboveR = imageSeams[pixelAbove + 1];
            newValue = min3(aboveL, aboveC, aboveR);
        } else {
            aboveL = imageSeams[pixelAbove - 1];
            aboveC = imageSeams[pixelAbove];
            aboveR = INT_MAX;
            newValue = min(aboveL, aboveC);
        }
    } else {
        aboveL = INT_MAX;
        aboveC = imageSeams[pixelAbove];
        aboveR = imageSeams[pixelAbove + 1];
        newValue = min(aboveC, aboveR);
    }
    imageSeams[currentPixel] += newValue;
}

static void fillSeamMatrixVertical(int *imageEnergies, int *imageSeams, int imageWidth, int imageHeight)
{
    int currentPixel = 0;
    // do not process the first row, start with j=1
    for (int j = 1; j < imageHeight; ++j) {
        for (int i = 0; i < imageWidth; ++i) {
            currentPixel = (j * imageWidth) + i;
            if (imageSeams[currentPixel] != INT_MAX) {
                imageSeams[currentPixel] = imageEnergies[currentPixel];
                setPixelPathVertical(imageSeams, imageWidth, imageHeight, currentPixel, i);
            }
        }
    }
}

static void cutSeamVertical(int *imageEnergies, int *imageSeams, char *imageColor, int imageWidth, int imageHeight)
{
    int *path = (int*)malloc((unsigned long)imageHeight * sizeof(int));
    
    int currentPixel = 0;
    int minValue = INT_MAX;
    int minLocation = 0;
    
    for (int i = 0; i < imageWidth; ++i) {
        currentPixel = ((imageHeight - 1) * imageWidth) + i;
        if ((imageSeams[currentPixel] > 0) && (imageSeams[currentPixel] != INT_MAX)) {
            if (imageSeams[currentPixel] <= minValue) {
                minValue = imageSeams[currentPixel];
                minLocation = currentPixel;
            }
        } else {
            break;
        }
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
        
        // avoid falling off the left end
        if ((currentCol > 0) && (imageSeams[pixelAbove - 1] != 0)) {
            // avoid falling off the right end
            if ((currentCol < imageWidth) && (imageSeams[pixelAbove + 1] != 0)) {
                aboveL = imageSeams[pixelAbove - 1];
                aboveC = imageSeams[pixelAbove];
                aboveR = imageSeams[pixelAbove + 1];
                newValue = min3(aboveL, aboveC, aboveR);
            } else {
                aboveL = imageSeams[pixelAbove - 1];
                aboveC = imageSeams[pixelAbove];
                aboveR = INT_MAX;
                newValue = min(aboveL, aboveC);
            }
        } else {
            aboveL = INT_MAX;
            aboveC = imageSeams[pixelAbove];
            aboveR = imageSeams[pixelAbove + 1];
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
    
    int colorPixel = 0;
    for (int j = 0; j < imageHeight; ++j) {
        currentPixel = path[j];
        currentCol = currentPixel % imageWidth;
        
        for (int i = currentCol; i < (imageWidth - 1); ++i) {
            if ((imageSeams[currentPixel] > 0) && (imageSeams[currentPixel] != INT_MAX)) {
                imageEnergies[currentPixel] = imageEnergies[currentPixel+1];
                imageSeams[currentPixel] = imageSeams[currentPixel+1];
                
                colorPixel = currentPixel * 4;
                imageColor[colorPixel] = imageColor[colorPixel+4];
                imageColor[colorPixel+1] = imageColor[colorPixel+5];
                imageColor[colorPixel+2] = imageColor[colorPixel+6];
                imageColor[colorPixel+3] = imageColor[colorPixel+7];
                
                ++currentPixel;
            } else {
                break;
            }
        }
        imageSeams[currentPixel] = INT_MAX;
        /*
        colorPixel = currentPixel * 4;
        imageColor[colorPixel] = 0;
        imageColor[colorPixel+1] = 0;
        imageColor[colorPixel+2] = 0;
        imageColor[colorPixel+3] = 255;
        */
    }
}

#pragma mark -

void carveSeams(char *sImg, int sImgWidth, int sImgHeight, char *tImg, int tImgWidth, int tImgHeight, int goHorizontal)
{
    int bytesPerPixel = 4;
    
    int *newImageEnergy = (int*)malloc((unsigned long)sImgWidth * (unsigned long)sImgHeight * sizeof(int));
    int *newImageSeams = (int*)malloc((unsigned long)sImgWidth * (unsigned long)sImgHeight * sizeof(int));
    char *newImageColor = (char*)malloc((unsigned long)sImgWidth * (unsigned long)sImgHeight * (unsigned long)bytesPerPixel * sizeof(char));
    
    int colorPixelLocation = 0;
    int bwPixelLocation = 0;

    for (int j = 0; j < sImgHeight; ++j) {
        for (int i = 0; i < sImgWidth; ++i) {
            colorPixelLocation = (j * (sImgWidth * bytesPerPixel)) + (i * bytesPerPixel);
            bwPixelLocation = (j * sImgWidth) + i;
            
            newImageEnergy[bwPixelLocation] = getPixelEnergySobel(sImg, sImgWidth, sImgHeight, bytesPerPixel, colorPixelLocation);
            newImageSeams[bwPixelLocation] = newImageEnergy[bwPixelLocation];
            
            newImageColor[colorPixelLocation] = sImg[colorPixelLocation];
            newImageColor[colorPixelLocation+1] = sImg[colorPixelLocation+1];
            newImageColor[colorPixelLocation+2] = sImg[colorPixelLocation+2];
            newImageColor[colorPixelLocation+3] = sImg[colorPixelLocation+3];
        }
    }
    
    int seamRemovalCount = 0;
    if (goHorizontal) {
        fillSeamMatrixHorizontal(newImageEnergy, newImageSeams, sImgWidth, sImgHeight);
        
        seamRemovalCount = sImgHeight - tImgHeight;
        for (int i = 0; i < seamRemovalCount; ++i) {
            cutSeamHorizontal(newImageEnergy, newImageSeams, newImageColor, sImgWidth, sImgHeight);
            if ((i % REFRESH_SEAM_MATRIX_EVERY) == 0) {
                fillSeamMatrixHorizontal(newImageEnergy, newImageSeams, sImgWidth, sImgHeight);
            }
        }
    } else {
        fillSeamMatrixVertical(newImageEnergy, newImageSeams, sImgWidth, sImgHeight);
        
        seamRemovalCount = sImgWidth - tImgWidth;
        for (int i = 0; i < seamRemovalCount; ++i) {
            cutSeamVertical(newImageEnergy, newImageSeams, newImageColor, sImgWidth, sImgHeight);
            if ((i % REFRESH_SEAM_MATRIX_EVERY) == 0) {
                fillSeamMatrixVertical(newImageEnergy, newImageSeams, sImgWidth, sImgHeight);
            }
        }
    }
    
    int newColorPixelLocation = 0;
    for (int j = 0; j < tImgHeight; ++j) {
        for (int i = 0; i < tImgWidth; ++i) {
            colorPixelLocation = (j * (sImgWidth * bytesPerPixel)) + (i * bytesPerPixel);
            newColorPixelLocation = (j * (tImgWidth * bytesPerPixel)) + (i * bytesPerPixel);
            
            tImg[newColorPixelLocation] = newImageColor[colorPixelLocation];
            tImg[newColorPixelLocation+1] = newImageColor[colorPixelLocation+1];
            tImg[newColorPixelLocation+2] = newImageColor[colorPixelLocation+2];
            tImg[newColorPixelLocation+3] = newImageColor[colorPixelLocation+3];
        }
    }
    
    free(newImageEnergy);
    free(newImageSeams);
    free(newImageColor);
}

#pragma mark - public functions

void carveSeamsHorizontal(char *sImg, int sImgWidth, int sImgHeight, char *tImg, int tImgWidth, int tImgHeight)
{
    carveSeams(sImg, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, 1);
}

void carveSeamsVertical(char *sImg, int sImgWidth, int sImgHeight, char *tImg, int tImgWidth, int tImgHeight)
{
    carveSeams(sImg, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, 0);
}
