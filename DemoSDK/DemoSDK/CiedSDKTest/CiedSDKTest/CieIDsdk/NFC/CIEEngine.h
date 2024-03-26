//
//  CIEEngine.h
//  CIESDK
//
//

#ifndef CIEEngine_h
#define CIEEngine_h

#include <stdio.h>
#include <openssl/crypto.h>
#include <openssl/objects.h>
#include <openssl/engine.h>

void engine_load_cie(void);

short sign(unsigned char* tosign, size_t len, unsigned char* signature, size_t* psiglen);
short read_certificate(unsigned char* cert, size_t* pLen);
short authenticate(void);
short verify_pin(unsigned char* pin, unsigned int len);

EVP_PKEY loadPrivateKey(void);

#endif /* CIEEngine_h */
