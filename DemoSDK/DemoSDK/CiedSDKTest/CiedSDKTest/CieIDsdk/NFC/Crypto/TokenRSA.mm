//
//  TokenRSA.m
//  cieID
//
//

#import <Foundation/Foundation.h>
#import "TokenRSA.h"
#import "../RSA.h"
@interface TokenRSA()
@property CRSA* rsa;
@end

@implementation TokenRSA
-(TokenRSA*)init {
    self = [super init];
    _rsa = new CRSA();
    return self;

}
-(void)createKeyPair {
    _rsa->createKeyPair();
//    CRSA::createKeyPair();
}

-(NSString*)getPublicKey {
    unsigned char* keys = _rsa->getPubKey();
    NSString* pubKey = [NSString stringWithUTF8String:(char *)keys];
    return pubKey;
}

-(NSString*)getPrivateKey {
    unsigned char* keys = _rsa->getPrivKey();
    NSString* privKey = [NSString stringWithUTF8String:(char *)keys];
    return privKey;
}
@end
