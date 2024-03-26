//
//  Token.m
//  e-id
//
//

//#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "Token.h"
#import "wintypes.h"
#import <CiedSDKTest/CiedSDKTest-Swift.h>
#import "HTTPSConnection.h"
#import "IAS.h"
#import "util.h"

@interface CIEToken()
    @property NFCToken* token;
    @property ByteDynArray idServiziData;
    @property ByteDynArray kPubEFServiziData;
    @property ByteDynArray sodData;
    @property ByteDynArray serialData;
    @property ByteDynArray certificateData;
    @property IAS* ias;
@end

CIEToken* cieToken;

extern "C" {

short authenticate()
{
    return [cieToken authenticate];
    
}

//MARK: RIMUOVIMI DOPO AVER RISOLTO IAS CRASH
void logToCrashlitics(const char* log)
{
    NSDictionary *detail = @{@"IAS LOG":[NSString stringWithUTF8String:log]};
        NSError *error = [NSError errorWithDomain:@"IAS LOG" code:0 userInfo:detail];

}
//MARK: RIMUOVIMI DOPO AVER RISOLTO IAS CRASH
void exceptionToCrashlitics(const char* error)
{
    
    NSDictionary *detail = @{@"IAS EXCEPTION":[NSString stringWithUTF8String:error]};
    NSError *errorException = [NSError errorWithDomain:@"IAS EXCEPTION" code:0 userInfo:detail];
    
}

short verify_pin(unsigned char* pin, unsigned int len)
{
    ByteArray bapin((BYTE*)pin, len);
    
    try
    {
        StatusWord sw = cieToken.ias->VerifyPIN(bapin);
        
        return sw;
    }
    catch (scard_error err)
    {
        
        return err.sw;
    }
}

short sign(unsigned char* data, size_t len, unsigned char* signature, size_t *pSignatureLen)
{
    
    //printf("sign\n");
    ByteArray toSign((BYTE*)data, len);
        
    ByteDynArray sig;
        
    try
    {
        //printf("tosig: %ld, %s", toSign.size(), dumpHexData(toSign).c_str());
        
        cieToken.ias->Sign(toSign, sig);
    
        //printf("signk\n");
        
        if(*pSignatureLen < sig.size())
            return 0xFFFF;
        
        memcpy(signature, sig.data(), sig.size());
        *pSignatureLen = sig.size();
        
        //NSLog(@"sig: %ld, %s", sig.size(), dumpHexData(sig).c_str());
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}

}


StatusWord Transmit(ByteArray apdu, ByteDynArray *resp)
{
    
    NSData *data = [NSData dataWithBytes:apdu.data() length:apdu.size()];
    
    NSData* response = [cieToken transmit:data];
        
    StatusWord sw;
    if(response.length > 0)
    {
        ByteArray baresp((unsigned char*)response.bytes, response.length - 2);
            
        resp->append(baresp);
        
        sw = ((unsigned char*)response.bytes)[response.length - 2] * 256 + ((unsigned char*)response.bytes)[response.length - 1];
    }
    else
    {
        sw = 0xFFFF;
    }
    
    return sw;
}



@implementation CIEToken

bool authenticated = false;

- (CIEToken*) initWithNFCToken: (NFCToken*) token
{
    self = [super init];
    if(self)
    {
        self.token = token;
    }
    
    cieToken = self;
    
    _ias = new IAS(&Transmit);
    
    return self;
}

- (UInt16) authenticate
{
    try
    {
        _ias->SelectAID_IAS();
        _ias->SelectAID_CIE();
        _ias->InitDHParam();
        
        ByteDynArray IdServizi;
        _ias->ReadIdServizi(IdServizi);
        _idServiziData = IdServizi.left(12);
        _idServiziData.push(0);
    
        ByteDynArray data;
        _ias->ReadDappPubKey(data);
        _ias->InitExtAuthKeyParam();
        _ias->DHKeyExchange();
        _ias->DAPP();
                                
        authenticated = true;
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}

- (UInt16) verifyPIN: (NSString*) pin
{
    
    if(pin.length != 8)
    {
        return 0xFFFD;
    }
    
    //uint8_t pin[] = {0x31,0x31, 0x32, 0x32, 0x33, 0x33, 0x34, 0x34};
    ByteArray bapin((BYTE*)pin.UTF8String, pin.length);
    
    try
    {
        StatusWord sw = _ias->VerifyPIN(bapin);
        //NSLog(@"sw: %x", sw);
        return sw;
    }
    catch (scard_error err)
    {
        
        return err.sw;
    }
}

- (UInt16) changePIN: (NSString*) pin withPIN: (NSString*) newpin
{
    if(pin.length != 8 || newpin.length != 8)
    {
        return 0xFFFD;
    }
        
    if([newpin isEqualToString:pin])
    {
        return 0xFFFB;
    }
    
    unichar c = [pin characterAtIndex:0];
    
    int i = 1;
    for(i = 1; i < pin.length && (c >= '0' && c <= '9'); i++)
    {
        c = [pin characterAtIndex:i];
    }
    
    if(!(c >= '0' && c <= '9'))
    {
        return 0xFFFD;
    }
    
    c = [newpin characterAtIndex:0];
    
    for(i = 1; i < newpin.length && (c >= '0' && c <= '9'); i++)
    {
        c = [newpin characterAtIndex:i];
    }
    
    if(!(c >= '0' && c <= '9'))
    {
        return 0xFFFD;
    }
    
    c = [newpin characterAtIndex:0];
    unichar lastchar = c;
    
    for(i = 1; i < newpin.length && c == lastchar; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar)
    {
        return 0xFFFE;
    }
    
    c = [newpin characterAtIndex:0];
    lastchar = c - 1;
    
    for(i = 1; i < newpin.length && c == lastchar + 1; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar + 1)
    {
        return 0xFFFE;
    }
    
    c = [newpin characterAtIndex:0];
    lastchar = c + 1;
    
    for(i = 1; i < newpin.length && c == lastchar - 1; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar - 1)
    {
        return 0xFFFE;
    }
        
    ByteArray baoldpin((BYTE*)pin.UTF8String, pin.length);
    ByteArray banewpin((BYTE*)newpin.UTF8String, newpin.length);
    
    try
    {
        StatusWord sw = _ias->VerifyPIN(baoldpin);
        
         if(sw == 0x9000)
         {
             sw = _ias->ChangePIN(baoldpin, banewpin);
         }
        
        return sw;
    }
    catch (scard_error err)
    {
        
        return err.sw;
    }
}

- (UInt16) unlockPIN: (NSString*) puk withPIN: (NSString*) newpin
{
    
    if(puk.length != 8 || newpin.length != 8)
    {
        return 0xFFFD;
    }

    unichar c = [newpin characterAtIndex:0];
    
    int i = 0;
    
    for(i = 1; i < newpin.length && (c >= '0' && c <= '9'); i++)
    {
        c = [newpin characterAtIndex:i];
    }
    
    if(!(c >= '0' && c <= '9'))
    {
        return 0xFFFD;
    }
    
    c = [newpin characterAtIndex:0];
    unichar lastchar = c;
    
    for(i = 1; i < newpin.length && c == lastchar; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar)
    {
        return 0xFFFE;
    }
    
    c = [newpin characterAtIndex:0];
    lastchar = c - 1;
    
    for(i = 1; i < newpin.length && c == lastchar + 1; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar + 1)
    {
        return 0xFFFE;
    }
    
    c = [newpin characterAtIndex:0];
    lastchar = c + 1;
    
    for(i = 1; i < newpin.length && c == lastchar - 1; i++)
    {
        lastchar = c;
        c = [newpin characterAtIndex:i];
    }
    
    if(c == lastchar - 1)
    {
        return 0xFFFE;
    }
    
    //uint8_t pin[] = {0x31,0x31, 0x32, 0x32, 0x33, 0x33, 0x34, 0x34};
    ByteArray bapuk((BYTE*)puk.UTF8String, puk.length);
    ByteArray banewpin((BYTE*)newpin.UTF8String, newpin.length);
    
    try
    {
        StatusWord sw = _ias->VerifyPUK(bapuk);
        
        if(sw == 0x9000)
        {
            sw = _ias->ChangePIN(banewpin);
        }
        
        return sw;
    }
    catch (scard_error err)
    {
        
        return err.sw;
    }
}

- (UInt16) serial: (NSMutableData*) serial
{
    try
    {
        ByteDynArray Serial;
        _ias->ReadSerialeCIE(Serial);
        ByteDynArray serialData = Serial.left(9);
        
        [serial appendData:[NSData dataWithBytes:serialData.data() length:serialData.size()]];
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}


- (UInt16) idServizi: (NSMutableData*) idServizi
{
    if(_idServiziData.size() != 0)
    {
        [idServizi appendData:[NSData dataWithBytes:_idServiziData.data() length:_idServiziData.size()]];
        return 0x9000;
    }
    
    try
    {
        _ias->SelectAID_IAS();
        _ias->SelectAID_CIE();
        ByteDynArray IdServizi;
        _ias->ReadIdServizi(IdServizi);
        _idServiziData = IdServizi.left(12);
        _idServiziData.push(0);
        
        [idServizi appendData:[NSData dataWithBytes:_idServiziData.data() length:_idServiziData.size()]];
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}

- (UInt16) kPubEFServizi: (NSMutableData*) kPubEFServizi
{
    if(_kPubEFServiziData.size() != 0)
    {
        [kPubEFServizi appendData:[NSData dataWithBytes:_kPubEFServiziData.data() length:_kPubEFServiziData.size()]];
        return 0x9000;
    }
    
    try
    {
        
        _ias->ReadServiziPubKey(_kPubEFServiziData);
        
        [kPubEFServizi appendData:[NSData dataWithBytes:_kPubEFServiziData.data() length:_kPubEFServiziData.size()]];

        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}

- (UInt16) getModuleAndExpFromkPubEFServizi: (NSMutableData*) kPubEFServizi mod: (NSMutableData*) mod exp: (NSMutableData*) exp{
    
    
    if(_kPubEFServiziData.size() == 0){
        
        try{
            
            _ias->ReadServiziPubKey(_kPubEFServiziData);
        
            
        }catch (scard_error err){
            return err.sw;
        }
        
    }
    
    [kPubEFServizi appendData:[NSData dataWithBytes:_kPubEFServiziData.data() length:_kPubEFServiziData.size()]];
        
    ByteDynArray kPubModuleData = _ias->GetModuleFromPubKey(_kPubEFServiziData);
    //printf("kPubModuleData: %ld, %s", kPubModuleData.size(), dumpHexData(kPubModuleData).c_str());


    try{
            
        [mod appendData:[NSData dataWithBytes:kPubModuleData.data() length:kPubModuleData.size()]];

        ByteDynArray kPubExpData = _ias->GetExpFromPubKey(_kPubEFServiziData);
        //printf("kPubExpData: %ld, %s", kPubModuleData.size(), dumpHexData(kPubModuleData).c_str());

        try{
                
            [exp appendData:[NSData dataWithBytes:kPubExpData.data() length:kPubExpData.size()]];
            
            return 0x9000;
            
        }catch (scard_error err){
               
            return err.sw;
            
        }
            
    }catch (scard_error err){
        
        return err.sw;
        
    }

}

- (UInt16) sod: (NSMutableData*) sod
{
    if(_sodData.size() != 0)
    {
        [sod appendData:[NSData dataWithBytes:_sodData.data() length:_sodData.size()]];
        return 0x9000;
    }
    
    try
    {
        _ias->ReadSOD(_sodData);
        [sod appendData:[NSData dataWithBytes:_sodData.data() length:_sodData.size()]];

        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
    }
}

- (UInt16) certificate: (NSMutableData*) certificate
{
    if(_certificateData.size() != 0)
    {
        [certificate appendData:[NSData dataWithBytes:_certificateData.data() length:_certificateData.size()]];
        
        return 0x9000;
    }
    
    try
    {
        _ias->ReadCertCIE(_certificateData);
                
        [certificate appendData:[NSData dataWithBytes:_certificateData.data() length:_certificateData.size()]];
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        
        return err.sw;
    }
}

//- (NSData*) certificate
//{
//    NSData* certData = [NSData dataWithBytes:_certificateData.data() length:_certificateData.size()];
//
//    return certData;
//}

- (UInt16) sign: (NSData*) data signature: (NSMutableData*) signedData
{
    //printf("sign\n");
    ByteArray toSign((BYTE*)data.bytes, data.length);
    
    ByteDynArray signature;
    
    try
    {
        _ias->Sign(toSign, signature);
    
        //printf("signk\n");
        
        NSData* signatureData = [NSData dataWithBytes:signature.data() length:signature.size()];
        
        [signedData appendData:signatureData];
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
//        if (error != NULL)
//        {
//            NSMutableDictionary* details = [[NSMutableDictionary alloc] init];
//            [details setValue:[NSString stringWithUTF8String:err.what()] forKey:NSLocalizedDescriptionKey];
//            // populate the error object with the details
//            *error = [NSError errorWithDomain:@"smartcard" code:err.sw userInfo:details];
//        }
//
//        return nil;
    }
        
    
}

- (UInt16) signIntAuth: (NSData*) data signature: (NSMutableData*) signedData{
    
    //printf("signIntAuth\n");
    ByteArray toSign((BYTE*)data.bytes, data.length);
    
    ByteDynArray signature;
    
    try
    {
        
        _ias->SelectAID_IAS();
        _ias->SelectAID_CIE();
        _ias->SignIntAuth(toSign, signature);
    
        //printf("signk\n");
        
        NSData* signatureData = [NSData dataWithBytes:signature.data() length:signature.size()];
        
        [signedData appendData:signatureData];
        
        return 0x9000;
    }
    catch (scard_error err)
    {
        return err.sw;
//        if (error != NULL)
//        {
//            NSMutableDictionary* details = [[NSMutableDictionary alloc] init];
//            [details setValue:[NSString stringWithUTF8String:err.what()] forKey:NSLocalizedDescriptionKey];
//            // populate the error object with the details
//            *error = [NSError errorWithDomain:@"smartcard" code:err.sw userInfo:details];
//        }
//
//        return nil;
    }
        
    
}


- (UInt16) post: (NSString*) url pin: (NSString*) pin certificate: (NSData*) certificate data: ( NSString* _Nullable ) data response: (NSMutableData*) response
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    if(pin.length != 8)
    {
        return 0xFFFD;
    }

    __block UInt16 errcode;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        HTTPSConnection* https = [[HTTPSConnection alloc] init];
        
        [https postTo:url withPIN:pin withCertificate:certificate withData:data callback:^(int code, NSData * _Nonnull respData) {
            //NSLog(@"%d, %@", code, respData);
            
            errcode = code;
            
            if(errcode == 0)
            {
                [response appendData:respData];
            }
            
            dispatch_semaphore_signal(semaphore);
        }];
    });
                   
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return errcode;
}

- (NSData*) transmit: (NSData*) apdu
{
    NSData* resp = [self.token transmitWithApdu: apdu];
    
    return resp;
    
//    return ByteDynArray(resp.bytes, resp.bytes.count);
}

@end
