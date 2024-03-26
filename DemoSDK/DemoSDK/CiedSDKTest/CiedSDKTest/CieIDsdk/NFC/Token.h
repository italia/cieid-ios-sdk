//
//  Token.h
//  e-id
//
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface CIEToken : NSObject


- (CIEToken*) initWithNFCToken: (NSObject*) token;

- (UInt16) authenticate;
- (UInt16) verifyPIN: (NSString*) pin;
- (UInt16) unlockPIN: (NSString*) puk withPIN: (NSString*) newpin;
- (UInt16) changePIN: (NSString*) oldpin withPIN: (NSString*) newpin;
- (UInt16) serial: (NSMutableData*) serial;
- (UInt16) certificate: (NSMutableData*) certificate;
- (UInt16) sign: (NSData*) data signature: (NSMutableData*) signature;
- (UInt16) idServizi: (NSMutableData*) idServizi;
- (UInt16) kPubEFServizi: (NSMutableData*) kPubEFServizi;
- (UInt16) post: (NSString*) url pin: (NSString*) pin certificate: (NSData*) certificate data: ( NSString* _Nullable ) data response: (NSMutableData*) response;
- (NSData*) transmit: (NSData*) apdu;
//USATI PER RECUPERO PUK
- (UInt16) getModuleAndExpFromkPubEFServizi: (NSMutableData*) kPubEFServizi mod: (NSMutableData*) mod exp: (NSMutableData*) exp;
- (UInt16) sod: (NSMutableData*) sod;
- (UInt16) signIntAuth: (NSData*) data signature: (NSMutableData*) signature;
//




@end

NS_ASSUME_NONNULL_END
