//
//  TokenRSA.h
//  cieID
//
//  Copyright © 2021 IPZS. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TokenRSA : NSObject
-(void)createKeyPair;
-(NSString*)getPublicKey;
-(NSString*)getPrivateKey;

@end

NS_ASSUME_NONNULL_END
