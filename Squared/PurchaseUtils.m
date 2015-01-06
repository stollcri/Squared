//
//  PurchaseUtils.m
//  Squared
//
//  Created by Christopher Stoll on 1/2/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//

#import "PurchaseUtils.h"
#import "SquaredDefines.h"

#import <CommonCrypto/CommonDigest.h>

// make sure we are statically linking
#import <openssl/pkcs7.h>
#import <openssl/x509.h>

@interface PurchaseUtils ()

@property NSData *appleRootCertificate;

@end

@implementation PurchaseUtils

+ (NSArray *)listProductIdentifiers
{
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Products" ofType:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfFile:plistPath];
    return productIdentifiers;
}

- (NSString*)MD5fromData:(NSData *)data
{
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(data.bytes, data.length, md5Buffer);
    
    // Convert unsigned char buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x",md5Buffer[i]];
    }
    
    return output;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSURL *certificateURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
        self.appleRootCertificate = [NSData dataWithContentsOfURL:certificateURL];
        if (![self validateRootCertificateData:self.appleRootCertificate]) {
            self.appleRootCertificate = nil;
        }
    }
    return self;
}

- (NSString *)getRootCertificateMD5
{
    return [self MD5fromData:self.appleRootCertificate];
}

- (BOOL)validateRootCertificateData:(NSData *)data
{
    BOOL rootCertificateDataIsValid = NO;
    
    NSString *rootCertHash = [self MD5fromData:self.appleRootCertificate];
    if ([rootCertHash isEqualToString:APPLE_ROOT_CERT_MD5]) {
        rootCertificateDataIsValid = YES;
    }
    
    return rootCertificateDataIsValid;
}

- (BOOL)validateMainBundleReceipt
{
    BOOL mainBundleReceiptIsValid = NO;
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (self.appleRootCertificate) {
        mainBundleReceiptIsValid = [self validateReceiptData:receiptData withCertificate:self.appleRootCertificate];
    }
    
    return mainBundleReceiptIsValid;
}

- (BOOL)validateReceiptData:(NSData *)receiptData withCertificate:(NSData *)certificate
{
    BOOL receiptDataIsValid = NO;
    
    // the receipt
    BIO *b_receipt = BIO_new_mem_buf((void *)[receiptData bytes], (int)[receiptData length]);
    // get PKCS#7 representation of receipt
    PKCS7 *p7 = d2i_PKCS7_bio(b_receipt, NULL);
    
    // Apple's Root Certificate
    const uint8_t *certificateBytes = (uint8_t *)[certificate bytes];
    X509 *b_x509 = d2i_X509(NULL, &certificateBytes, (long)[certificate length]);
    // create a certificate store
    X509_STORE *store = X509_STORE_new();
    X509_STORE_add_cert(store, b_x509);
    
    // verify the signature
    BIO *b_receiptPayload = BIO_new(BIO_s_mem());
    int result = PKCS7_verify(p7, NULL, store, NULL, b_receiptPayload, 0);
    if (result == 1) {
        // receipt signature is valid
        receiptDataIsValid = YES;
    }
    
    return receiptDataIsValid;
}

@end
