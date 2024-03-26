//
//  NSData_SHA1.h
//  SwiftyRSA
//
//

#import <Foundation/Foundation.h>

@interface NSData (NSData_SwiftyRSASHA)

- (nonnull NSData*) SwiftyRSASHA1;
- (nonnull NSData*) SwiftyRSASHA224;
- (nonnull NSData*) SwiftyRSASHA256;
- (nonnull NSData*) SwiftyRSASHA384;
- (nonnull NSData*) SwiftyRSASHA512;

@end
