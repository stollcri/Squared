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
@property ASN1_OCTET_STRING *asn1OctetString;

@property NSString *receiptBundleID;
@property NSString *receiptBundleVersion;
@property NSString *receiptOpaqueValue;
@property NSString *receiptHashValue;

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

- (BOOL)validateBundleIdentifier:(NSString *)identifier
{
    BOOL bundleIdentifierIsValid = NO;
    
    if ([identifier isEqualToString:APP_BUNDLE_IDENTIFIER]) {
        bundleIdentifierIsValid = YES;
    }
    
    return bundleIdentifierIsValid;
}

- (BOOL)validateRootCertificateData:(NSData *)data
{
    BOOL rootCertificateDataIsValid = NO;
    
    NSString *rootCertHash = [self MD5fromData:data];
    if ([rootCertHash isEqualToString:APPLE_ROOT_CERT_MD5]) {
        rootCertificateDataIsValid = YES;
    }
    
    return rootCertificateDataIsValid;
}

- (BOOL)validateMainBundleReceipt
{
    BOOL mainBundleReceiptIsValid = NO;
    
    BOOL receiptDataSignatureIsValid = NO;
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (self.appleRootCertificate) {
        receiptDataSignatureIsValid = [self validateSignatureOfReceiptData:receiptData withCertificate:self.appleRootCertificate];
    }
    
    [self parseReceiptASN1OctetString:self.asn1OctetString];
    BOOL bundleIdentifierIsValid = [self validateBundleIdentifier:self.receiptBundleID];
    
    BOOL receiptBelongsToDevice = NO;
    if (self.receiptBundleID && self.receiptOpaqueValue && self.receiptHashValue) {
        NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        receiptBelongsToDevice = [self verifyReceiptForBundle:self.receiptBundleID matchesDevice:deviceID usingOpaqueValue:self.receiptOpaqueValue andHash:self.receiptHashValue];
    }
    
    if (receiptDataSignatureIsValid && bundleIdentifierIsValid && receiptBelongsToDevice) {
        mainBundleReceiptIsValid = YES;
    }
    
    return mainBundleReceiptIsValid;
}

- (BOOL)validateSignatureOfReceiptData:(NSData *)receiptData withCertificate:(NSData *)certificate
{
    BOOL receiptDataSignatureIsValid = NO;
    
    // the receipt
    BIO *b_receipt = BIO_new_mem_buf((void *)[receiptData bytes], (int)[receiptData length]);
    // get PKCS7 representation of receipt
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
        receiptDataSignatureIsValid = YES;
        self.asn1OctetString = p7->d.sign->contents->d.data;
    }
    // For additional security, you may verify the fingerprint of the root certificate and verify the OIDs of the intermediate certificate and signing certificate. The OID in the certificate policies extension of the intermediate certificate is (1 2 840 113635 100 5 6 1), and the marker OID of the signing certificate is (1 2 840 113635 100 6 11 1).
    
    // cleanup signature block variables
    BIO_free(b_receiptPayload);
    
    // cleanup root CA block variables
    X509_STORE_free(store);
    X509_free(b_x509);
    EVP_cleanup();
    
    // cleanupi receipt block variables
    PKCS7_free(p7);
    BIO_free(b_receipt);
    
    return receiptDataSignatureIsValid;
}

- (void)parseReceiptASN1OctetString:(ASN1_OCTET_STRING *)octetString
{
    NSString *bundleId;
    NSString *bundleVersion;
    NSString *opaqueValue;
    NSString *hashValue;
    
    const unsigned char *p = octetString->data;
    long length = 0;
    int type = 0;
    int xclass = 0;
    const unsigned char *end = p + octetString->length;
    
    ASN1_get_object(&p, &length, &type, &xclass, end - p); // Top-level (Receipt)
    while (p < end) {
        ASN1_get_object(&p, &length, &type, &xclass, end - p); // Attribute
        const unsigned char *seq_end = p + length;
        int attr_type = 0;
        int attr_version = 0;
        
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p); // Type
        if ((type == V_ASN1_INTEGER) && (length == 1)) {
            attr_type = p[0];
        }
        p += length;
        
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p); // Version
        if ((type == V_ASN1_INTEGER) && (length == 1)) {
            attr_version = p[0];
        }
        p += length;
        
        ASN1_get_object(&p, &length, &type, &xclass, seq_end - p); // Object
        switch (attr_type) {
            case 2: { // Bundle ID
                int str_type = 0;
                long str_length = 0;
                const unsigned char *str_p = p;
                ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                bundleId = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                break;
            }
            case 3: { // Bundle Version
                int str_type = 0;
                long str_length = 0;
                const unsigned char *str_p = p;
                ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                bundleVersion = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                break;
            }
            case 4: { // Opaque
                int str_type = 0;
                long str_length = 0;
                const unsigned char *str_p = p;
                ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                opaqueValue = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                break;
            }
            case 5: { // Hash
                int str_type = 0;
                long str_length = 0;
                const unsigned char *str_p = p;
                ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                hashValue = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                break;
            }
            case 17: { // In-App Purchase
                // 1701: Quantity
                // 1702: Product ID
                // 1703: Transaction ID
                // 1704: Purchase Date
                break;
            }
            case 19: { // Original Application Version
                // For switch from paid to freemium,
                // can see if the app was purchased
                // at a version which was paid for
                break;
            }
            default:
                break;
        }
    }
    
    self.receiptBundleID = bundleId;
    self.receiptBundleVersion = bundleVersion;
    self.receiptOpaqueValue = opaqueValue;
    self.receiptHashValue = hashValue;
}

- (BOOL)verifyReceiptForBundle:(NSString *)bundle matchesDevice:(NSString *)device usingOpaqueValue:(NSString *)opaque andHash:(NSString *)hash
{
    BOOL receiptBelongsToDevice = NO;
    
    //
    
    return receiptBelongsToDevice;
}

@end
