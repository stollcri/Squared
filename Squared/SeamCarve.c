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
    
    // apply the sobel filter
    double sobelX = (p3val + (p6val + p6val) + p9val - p1val - (p4val + p4val) - p7val);
    double sobelY = (p1val + (p2val + p2val) + p3val - p7val - (p8val + p8val) - p9val);
    
    // bounded gradient magnitude
    return min(max((int)(sqrt((sobelX * sobelX) + (sobelY * sobelY))/2) , 0), 255);
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
            } else {
                break;
            }
        }
    }
}

static void cutSeamHorizontal(struct Pixel *image, int imageWidth, int imageHeight, int *minLocs, int *path)
{
    int currentPixel = 0;
    int minsFound = 0;
    int minValue = INT_MAX;
    
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
    int innerEnd = (imageHeight - 1);
    for (int j = 0; j < outerEnd; ++j) {
        currentPixel = path[j];
        currentRow = currentPixel / imageWidth;
        
        for (int i = currentRow; i < innerEnd; ++i) {
            if ((image[currentPixel].seamval >= 0) && (image[currentPixel].seamval != INT_MAX)) {
                image[currentPixel] = image[currentPixel+imageWidth];
                currentPixel += imageWidth;
            } else {
                break;
            }
        }
        image[currentPixel].seamval = INT_MAX;
    }
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
}

#pragma mark -

void carveSeams(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount, int goHorizontal)
{
    // rand() is used in seam cutting, but only need to seed it once per thread
    srand((int)time(0));
    
    if (goHorizontal) {
        fillSeamMatrixHorizontal(sImgPixels, sImgWidth, sImgHeight);
        
        int *minLocs = (int*)calloc((unsigned long)sImgHeight, sizeof(int));
        int *path = (int*)calloc((unsigned long)sImgWidth, sizeof(int));
        
        for (int i = 0; i < carveCount; ++i) {
            cutSeamHorizontal(sImgPixels, sImgWidth, sImgHeight, minLocs, path);
        }
        
        free(path);
        free(minLocs);
    } else {
        fillSeamMatrixVertical(sImgPixels, sImgWidth, sImgHeight);
        
        int *minLocs = (int*)calloc((unsigned long)sImgWidth, sizeof(int));
        int *path = (int*)calloc((unsigned long)sImgHeight, sizeof(int));
        
        for (int i = 0; i < carveCount; ++i) {
            cutSeamVertical(sImgPixels, sImgWidth, sImgHeight, minLocs, path);
        }
        
        free(path);
        free(minLocs);
    }
    
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
            tImg[tImgPixelLoc]   = image[pixelLocation].energy;
            tImg[tImgPixelLoc+1] = image[pixelLocation].energy;
            tImg[tImgPixelLoc+2] = image[pixelLocation].energy;
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
            currentPixel.energy = getPixelEnergySobel(sImg, sImgWidth, sImgHeight, pixelDepth, sImgPixelLoc);
            currentPixel.seamval = currentPixel.energy;
            
            // handle freeze/melt masks
            if (sImgMask[sImgPixelLoc] >= 255) {
                //currentPixel.energy = (int)(currentPixel.energy / 29);
                currentPixel.energy = 0;
            }
            if (sImgMask[sImgPixelLoc+2] >= 255) {
                currentPixel.energy = (int)(currentPixel.energy * 7);
            }
            
            image[pixelLocation] = currentPixel;
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
                image[pixelLocation].energy = image[pixelLocation].energy * 3;
            }
        }
    }
    
    return image;
}

void carveSeamsHorizontal(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount)
{
    carveSeams(sImgPixels, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, pixelDepth, carveCount, 1);
}

void carveSeamsVertical(struct Pixel *sImgPixels, int sImgWidth, int sImgHeight, unsigned char *tImg, int tImgWidth, int tImgHeight, int pixelDepth, int carveCount)
{
    carveSeams(sImgPixels, sImgWidth, sImgHeight, tImg, tImgWidth, tImgHeight, pixelDepth, carveCount, 0);
}
