//
//  HTTPSConnection.h
//  CIESDK
//
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface HTTPSConnection : NSObject

- (void) postTo: (NSString*) url withPIN: (NSString*) pin withCertificate: (NSData*) certificate withData: ( NSString* _Nullable ) data  callback: (void(^) (int code, NSData* respData)) callback;

@end

NS_ASSUME_NONNULL_END

