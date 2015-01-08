//
//  PurchaseUtils.m
//  Squared
//
//  Created by Christopher Stoll on 1/2/15.
//  Copyright (c) 2015 Christopher Stoll. All rights reserved.
//
// Ref: https://github.com/rmaddy/VerifyStoreReceiptiOS/blob/master/VerifyStoreReceipt.m
// Ref: https://github.com/AlanQuatermain/mac-app-store-validation-sample/blob/master/main.m
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

@property BOOL mainBundleReceiptIsValid;

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
    CC_MD5([data bytes], (unsigned int)[data length], md5Buffer);
    
    // Convert unsigned char buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", md5Buffer[i]];
    }
    
    return output;
}

- (id)init
{
    self = [super init];
    if (self) {
        //
    }
    return self;
}

- (BOOL)loadAppleRootCertificate
{
    BOOL rootCertificateLoaded = YES;
    
    NSURL *certificateURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    self.appleRootCertificate = [NSData dataWithContentsOfURL:certificateURL];
    if (![self validateRootCertificateData:self.appleRootCertificate]) {
        self.appleRootCertificate = nil;
        rootCertificateLoaded = NO;
    }
    
    return rootCertificateLoaded;
}

- (NSString *)getRootCertificateMD5
{
    if (!self.appleRootCertificate) {
        [self loadAppleRootCertificate];
    }
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
    
    BOOL loadedValidRootCert = NO;
    loadedValidRootCert = [self loadAppleRootCertificate];
    
    BOOL receiptSignatureIsValid = NO;
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (loadedValidRootCert && self.appleRootCertificate) {
        receiptSignatureIsValid = [self validateSignatureOfReceiptData:receiptData withCertificate:self.appleRootCertificate];
    }
    
    BOOL receiptBelongsToDevice = NO;
    if (receiptSignatureIsValid && self.asn1OctetString) {
        NSUUID *deviceID = [[UIDevice currentDevice] identifierForVendor];
        receiptBelongsToDevice = [self verifyReceipt:self.asn1OctetString forBundle:APP_BUNDLE_IDENTIFIER matchesDevice:deviceID];
    }
    
    BOOL bundleIdentifierIsValid = NO;
    if (receiptBelongsToDevice && self.receiptBundleID) {
        bundleIdentifierIsValid = [self validateBundleIdentifier:self.receiptBundleID];
    }
    
    if (receiptSignatureIsValid && receiptBelongsToDevice && bundleIdentifierIsValid) {
        self.mainBundleReceiptIsValid = YES;
        mainBundleReceiptIsValid = YES;
    }
    
    return mainBundleReceiptIsValid;
}

- (BOOL)validateSignatureOfReceiptData:(NSData *)receiptData withCertificate:(NSData *)certificate
{
    BOOL receiptDataSignatureIsValid = NO;
    
    // add active digests
    OpenSSL_add_all_digests();
    
    // the receipt
    BIO *b_receipt = BIO_new_mem_buf((void *)[receiptData bytes], (int)[receiptData length]);
    // get PKCS7 representation of receipt
    PKCS7 *p7 = d2i_PKCS7_bio(b_receipt, NULL);
    
    if (PKCS7_type_is_signed(p7) && PKCS7_type_is_data(p7->d.sign->contents)) {
        // Apple's Root Certificate
        const unsigned char *certificateBytes = (unsigned char *)[certificate bytes];
        X509 *b_x509 = d2i_X509(NULL, &certificateBytes, (long)[certificate length]);
        
        if (b_x509) {
            // create a certificate store
            X509_STORE *store = X509_STORE_new();
            
            if (store) {
                X509_STORE_add_cert(store, b_x509);
                
                // verify the signature
                BIO *b_receiptPayload = BIO_new(BIO_s_mem());
                int result = PKCS7_verify(p7, NULL, store, NULL, b_receiptPayload, 0);
                
                if (result == 1) {
                    // receipt signature is valid
                    receiptDataSignatureIsValid = YES;
                    //self.asn1OctetString = p7->d.sign->contents->d.data;
                    // better copy the data, otherwise you *might* have a bad pointer
                    self.asn1OctetString = ASN1_STRING_dup(p7->d.sign->contents->d.data);
                }
                // For additional security, you may verify the fingerprint of the root certificate and verify the OIDs of the intermediate certificate and signing certificate. The OID in the certificate policies extension of the intermediate certificate is (1 2 840 113635 100 5 6 1), and the marker OID of the signing certificate is (1 2 840 113635 100 6 11 1).
                
                // cleanup signature block variables
                BIO_free(b_receiptPayload);
            }
            
            // clean up certificate store
            X509_STORE_free(store);
        }
        
        // cleanup root CA block variables
        X509_free(b_x509);
    }
    
    // cleanup receipt block variables
    PKCS7_free(p7);
    BIO_free(b_receipt);
    
    // clean up digests
    EVP_cleanup();
    
    return receiptDataSignatureIsValid;
}

- (BOOL)verifyReceipt:(ASN1_OCTET_STRING *)receipt forBundle:(NSString *)bundle matchesDevice:(NSUUID *)device
{
    BOOL receiptBelongsToDevice = NO;
    
    if (!receipt) {
        return receiptBelongsToDevice;
    }
    
    NSString *receiptBundleIdString;
    NSString *receiptBundleVersionString;
    NSData *receiptBundleId;
    NSData *receiptOpaqueValue;
    NSData *receiptHashValue;
    //unsigned int receiptOpaqueValueSize;
    //unsigned int receiptHashValueSize;
    
    const unsigned char *p = receipt->data;
    long length = 0;
    int type = 0;
    int xclass = 0;
    const unsigned char *end = p + receipt->length;
    
    ASN1_get_object(&p, &length, &type, &xclass, (end - p)); // Top-level (Receipt)
    if (type == V_ASN1_SET) {
        while (p < end) {
            ASN1_get_object(&p, &length, &type, &xclass, (end - p)); // Attribute
            
            if (type != V_ASN1_SEQUENCE) {
                break;
            }
            
            const unsigned char *seq_end = p + length;
            int attr_type = 0;
            int attr_version = 0;
            
            ASN1_get_object(&p, &length, &type, &xclass, (seq_end - p)); // Type
            if ((type == V_ASN1_INTEGER) && (length == 1)) {
                attr_type = p[0];
            }
            p += length;
            
            ASN1_get_object(&p, &length, &type, &xclass, (seq_end - p)); // Version
            if ((type == V_ASN1_INTEGER) && (length == 1)) {
                attr_version = p[0];
                attr_version = attr_version;
            }
            p += length;
            
            if ((attr_type >= 2 && attr_type <= 5) || (attr_type == 17) || (attr_type == 19)) {
                ASN1_get_object(&p, &length, &type, &xclass, (seq_end - p)); // Object
                if (type == V_ASN1_OCTET_STRING) {
                    switch (attr_type) {
                        case 2:  // Bundle ID
                        {
                            receiptBundleId = [NSData dataWithBytes:p length:(NSUInteger)length];
                            int str_type = 0;
                            long str_length = 0;
                            const unsigned char *str_p = p;
                            ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                            receiptBundleIdString = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                            break;
                        }
                        case 3: // Bundle Version
                        {
                            int str_type = 0;
                            long str_length = 0;
                            const unsigned char *str_p = p;
                            ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                            receiptBundleVersionString = [[NSString alloc] initWithBytes:str_p length:str_length encoding:NSUTF8StringEncoding];
                            break;
                        }
                        case 4: // Opaque
                        {
                            //int str_type = 0;
                            //long str_length = 0;
                            //const unsigned char *str_p = p;
                            //ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                            //receiptOpaqueValue = (unsigned char *)str_p;
                            //receiptOpaqueValueSize = (unsigned int)str_length;
                            //receiptOpaqueValue = [NSData dataWithBytes:str_p length:str_length];
                            receiptOpaqueValue = [NSData dataWithBytes:p length:(NSUInteger)length];
                            break;
                        }
                        case 5: // Hash
                        {
                            //int str_type = 0;
                            //long str_length = 0;
                            //const unsigned char *str_p = p;
                            //ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                            //receiptHashValue = (unsigned char *)str_p;
                            //receiptHashValueSize = (unsigned int)str_length;
                            //receiptHashValue = [NSData dataWithBytes:str_p length:str_length];
                            receiptHashValue = [NSData dataWithBytes:p length:(NSUInteger)length];
                            break;
                        }
                        case 17: // In-App Purchase
                        {
                            // 1701: Quantity
                            // 1702: Product ID
                            // 1703: Transaction ID
                            // 1704: Purchase Date
                            break;
                        }
                        case 19: // Original Application Version
                        {
                            // For switch from paid to freemium,
                            // can see if the app was purchased
                            // at a version which was paid for
                            break;
                        }
                        default:
                            break;
                    }
                }
                p += length;
            }
            
            while (p < seq_end) {
                ASN1_get_object(&p, &length, &type, &xclass, (seq_end - p));
                p += length;
            }
        }
    }
    
    self.receiptBundleID = receiptBundleIdString;
    self.receiptBundleVersion = receiptBundleVersionString;
    
    //
    // All the data is gathered, now verify the hash
    //
    
    unsigned char uuidBytes[16];
    [device getUUIDBytes:uuidBytes];
    
    NSMutableData *input = [NSMutableData data];
    [input appendBytes:uuidBytes length:sizeof(uuidBytes)];
    [input appendData:receiptOpaqueValue];
    [input appendData:receiptBundleId];
    
    NSMutableData *hash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
    SHA1([input bytes], [input length], [hash mutableBytes]);
    
    if ([hash isEqualToData:receiptHashValue]) {
        receiptBelongsToDevice = YES;
    }
    
    return receiptBelongsToDevice;
}

@end
