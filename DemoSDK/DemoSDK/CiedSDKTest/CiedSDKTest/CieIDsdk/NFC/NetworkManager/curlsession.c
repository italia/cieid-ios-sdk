//
//  curlsession.c
//  CIESDK
//
//

#include "curlsession.h"
#include <stdio.h>
#include <curl/curl.h>
#include <openssl/engine.h>

#define KEY_NAME        "auth"
#define KEY_TYPE        "ENG"
#define ENGINE_NAME     "CIE"

int initssl_engine()
{
    ENGINE_load_builtin_engines();
    
    ENGINE* e = ENGINE_by_id(ENGINE_NAME);
    
    if(e == NULL)
        return -1;
    
    
    return 0;
}


int httpspost(char* szUrl, char* szPIN, unsigned char* data, unsigned int length, void* callback)
{
    CURL *curl;
    CURLcode res;
    
    const char *pKeyName;
    const char *pKeyType;
    const char *pEngine;

    pKeyName = KEY_NAME;
    pKeyType = KEY_TYPE;
    pEngine = ENGINE_NAME;
    
    curl_global_init(CURL_GLOBAL_DEFAULT);

    curl = curl_easy_init();
    if (curl)
    {
        /* what call to write: */
        curl_easy_setopt(curl, CURLOPT_URL, szUrl);
        
        //set POST method
        curl_easy_setopt(curl, CURLOPT_POST, 1);

        //give the data you want to post
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data);

        //give the data lenght
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, length);
        
        struct curl_slist *chunk = NULL;
        
        /* Remove a header curl would otherwise add by itself */
        chunk = curl_slist_append(chunk, "User-Agent: Mozilla/5.0");
    
        /* set our custom set of headers */
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);
        //curl_easy_setopt(curl, CURLOPT_HEADERDATA, headerfile);

        /* use crypto engine */
        if (curl_easy_setopt(curl, CURLOPT_SSLENGINE, pEngine) != CURLE_OK) {
            /* load the crypto engine */
            fprintf(stderr, "can't set crypto engine\n");
        }
        
        /* cert is stored PEM coded in file... */
        /* since PEM is default, we needn't set it for PEM */
        //curl_easy_setopt(curl, CURLOPT_SSLCERTTYPE, "DER");

        /* set the cert for client authentication */
//        curl_easy_setopt(curl, CURLOPT_SSLCERT, pCertFile);

//        /* sorry, for engine we must set the passphrase
//           (if the key has one...) */
//        if (pPassphrase)
//            curl_easy_setopt(curl, CURLOPT_KEYPASSWD, pPassphrase);

        /* if we use a key stored in a crypto engine,
           we must set the key type to "ENG" */
        curl_easy_setopt(curl, CURLOPT_SSLKEYTYPE, pKeyType);

        /* set the private key (file or ID in engine) */
        curl_easy_setopt(curl, CURLOPT_SSLKEY, pKeyName);

//            /* set the file with the certs vaildating the server */
//            curl_easy_setopt(curl, CURLOPT_CAINFO, pCACertFile);

        /* disconnect if we can't validate server's cert */
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);

        /* Perform the request, res will get the return code */
        res = curl_easy_perform(curl);
        /* Check for errors */
        if (res != CURLE_OK)
            fprintf(stderr, "curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
            
        /* always cleanup */
        curl_easy_cleanup(curl);
                
        /* free the custom headers */
        curl_slist_free_all(chunk);
    }

    curl_global_cleanup();

    return 0;
}
