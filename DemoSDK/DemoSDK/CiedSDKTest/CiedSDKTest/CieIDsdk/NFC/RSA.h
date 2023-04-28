#pragma once

#ifdef WIN32
#include <bcrypt.h>
#else
#include <openssl/rsa.h>
#endif
#include "wintypes.h"
#include "Array.h"

class CRSA
{
#ifdef WIN32
	BCRYPT_KEY_HANDLE key;
    void GenerateKey(DWORD size, ByteDynArray &module, ByteDynArray &pubexp, ByteDynArray &privexp);
#else
	RSA* keyPriv;
    DWORD GenerateKey(DWORD size, ByteDynArray &module, ByteDynArray &pubexp, ByteDynArray &privexp);

#endif
    EVP_PKEY* create_rsa_key(RSA *pRSA);
    void saveCertifateKey(EVP_PKEY* pPrivKey, EVP_PKEY* pPubKey);
public:
	CRSA(ByteArray &mod, ByteArray &exp);
    CRSA(void);
	~CRSA(void);
    void encrypt(RSA* keypair);
	ByteDynArray RSA_PURE(ByteArray &data);
    unsigned char* getPubKey();
    unsigned char* getPrivKey();
    void createKeyPair(void);
	size_t KeySize;
};
