//
//  HTTPSConnection.m
//  CIESDK
//
//

#import "HTTPSConnection.h"

#include <curl/curl.h>
#include <openssl/engine.h>
#include <openssl/bio.h>
#include <openssl/ssl.h>
#include "CIEEngine.h"

#define KEY_NAME                "auth"
#define KEY_TYPE                "ENG"
#define ENGINE_NAME             "CIE"
#define CACERT_NAME             "CIESDK_DSTX3Root-updated"
#define CACERT_FORMAT           "pem"
#define CURLOPT_SSLCERT_NAME    "cie"
#define CURLOPT_SSLKEY_NAME     "cie"
#define ENGINE_ID               "cie"

struct data {
  char trace_ascii; /* 1 or 0 */
};
 
extern unsigned char* cie_certificate;
extern unsigned int cie_certlen;
extern char* cie_pin;
extern unsigned long cie_pinlen;
extern unsigned short cie_error;

void dump(const char *text,
          FILE *stream, unsigned char *ptr, size_t size,
          char nohex)
{
  size_t i;
  size_t c;
 
  unsigned int width = 0x10;
 
  if(nohex)
    /* without the hex output, we can fit more on screen */
    width = 0x40;
 
    
  fprintf(stream, "%s, %10.10lu bytes (0x%8.8lx)\n",
          text, (unsigned long)size, (unsigned long)size);
 
  for(i = 0; i<size; i += width) {
      
    fprintf(stream, "%4.4lx: ", (unsigned long)i);
 
    if(!nohex) {
      /* hex not disabled, show it */
      for(c = 0; c < width; c++)
        if(i + c < size)
          fprintf(stream, "%02x ", ptr[i + c]);
        else
          fputs("   ", stream);
    }
 
    for(c = 0; (c < width) && (i + c < size); c++) {
      /* check for 0D0A; if found, skip past and start a new line of output */
      if(nohex && (i + c + 1 < size) && ptr[i + c] == 0x0D &&
         ptr[i + c + 1] == 0x0A) {
        i += (c + 2 - width);
        break;
      }

    fprintf(stream, "%c",
              (ptr[i + c] >= 0x20) && (ptr[i + c]<0x80)?ptr[i + c]:'.');
      /* check again for 0D0A, to avoid an extra \n if it's at width */
      if(nohex && (i + c + 2 < size) && ptr[i + c + 1] == 0x0D &&
         ptr[i + c + 2] == 0x0A) {
        i += (c + 3 - width);
        break;
      }
    }
    fputc('\n', stream); /* newline */
  }
  fflush(stream);
}
 
static
int my_trace(CURL *handle, curl_infotype type,
             char *data, size_t size,
             void *userp)
{
  struct data *config = (struct data *)userp;
  const char *text;
  (void)handle; /* prevent compiler warning */
 
  switch(type) {
  case CURLINFO_TEXT:

    //MARK: DECOMMENTAMI PER IL LOG LIBCURL
    //fprintf(stderr, "== Info: %s", data);
          
          if(strstr(data, "certificate revoked"))
              // certificato revocato
              cie_error = CURL_LAST + 1;
                
          if(strstr(data, "unknown ca"))
          // certificato revocato
              cie_error = CURL_LAST + 2;

    /* FALLTHROUGH */
  default: /* in case a new one is introduced to shock us */
    return 0;
 
  case CURLINFO_HEADER_OUT:
    text = "=> Send header";
    break;
  case CURLINFO_DATA_OUT:
    text = "=> Send data";
    break;
  case CURLINFO_SSL_DATA_OUT:
    text = "=> Send SSL data";
    break;
  case CURLINFO_HEADER_IN:
    text = "<= Recv header";
    break;
  case CURLINFO_DATA_IN:
    text = "<= Recv data";
    break;
  case CURLINFO_SSL_DATA_IN:
    text = "<= Recv SSL data";
    break;
  }
 
    //MARK: DECOMMENTAMI PER IL LOG LIBCURL
  //dump(text, stderr, (unsigned char *)data, size, config->trace_ascii);

    //MARK: DECOMMENTAMI PER IL LOG LIBCURL
  //dump(text, stderr, (unsigned char *)data, size, 0);
  return 0;
}




//CALLBACK_API_C(void, completed)(unsigned char* data, unsigned int len);

int init_ssl_engine()
{
    ENGINE_load_builtin_engines();
    
    ENGINE* e = ENGINE_by_id(ENGINE_ID);
    
    if(e == NULL)
    {
        engine_load_cie();
        //ENGINE_load_builtin_engines();
        e = ENGINE_by_id(ENGINE_ID);
    }
    
    if(e == NULL)
    {
        return -1;
    }
    
    return 0;
}

struct MemoryStruct {
  char *memory;
  size_t size;
};

static size_t
write_memory_callback(void *contents, size_t size, size_t nmemb, void *userp)
{
  size_t realsize = size * nmemb;
  struct MemoryStruct *mem = (struct MemoryStruct *)userp;
 
  char *ptr = realloc(mem->memory, mem->size + realsize + 1);
  if(ptr == NULL) {
    /* out of memory! */
    //printf("not enough memory (realloc returned NULL)\n");
    return 0;
  }
 
  mem->memory = ptr;
    
    if(mem->size + realsize + 1 < realsize)
        return 0;

  memcpy(&(mem->memory[mem->size]), contents, realsize);
  mem->size += realsize;
  mem->memory[mem->size] = 0;
 
  return realsize;
}

long bio_dump_callback(BIO *bio, int cmd, const char *argp,
                       int argi, long argl, long ret)
{
    BIO *out;

    out = (BIO *)BIO_get_callback_arg(bio);
    if (out == NULL)
        return (ret);

    if (cmd == (BIO_CB_READ | BIO_CB_RETURN)) {
        BIO_printf(out, "read from %p [%p] (%lu bytes => %ld (0x%lX))\n",
                   (void *)bio, (void *)argp, (unsigned long)argi, ret, ret);
        BIO_dump(out, argp, (int)ret);
        return (ret);
    } else if (cmd == (BIO_CB_WRITE | BIO_CB_RETURN)) {
        BIO_printf(out, "write to %p [%p] (%lu bytes => %ld (0x%lX))\n",
                   (void *)bio, (void *)argp, (unsigned long)argi, ret, ret);
        BIO_dump(out, argp, (int)ret);
    }
    return (ret);
}

int https_post(char* szUrl, char* szPIN, unsigned char* certificate, unsigned int certlen, char* data, unsigned int length, unsigned char* response, unsigned long* pLength)
{
    CURL *curl;
    CURLcode res = CURLE_OK;
    
    cie_certlen = certlen;
    cie_certificate = certificate;
    cie_pin = szPIN;
    cie_pinlen = strlen(szPIN);
    
    const char *pKeyName;
    const char *pKeyType;
    const char *pEngine;

    pKeyName = "auth";
    pKeyType = "ENG";
    pEngine = "cie";
        
    curl_global_init(CURL_GLOBAL_DEFAULT);

    struct data config;
    config.trace_ascii = 1; /* enable ascii tracing */
    
    struct MemoryStruct chunk;
    chunk.memory = malloc(1);  /* will be grown as needed by the realloc above */
    chunk.size = 0;    /* no data at this point */
    
    curl = curl_easy_init();
    if (curl)
    {
        curl_easy_setopt(curl, CURLOPT_DEBUGFUNCTION, my_trace);
        curl_easy_setopt(curl, CURLOPT_DEBUGDATA, &config);
        curl_easy_setopt(curl, CURLOPT_SSLCERT,CURLOPT_SSLCERT_NAME);
        curl_easy_setopt(curl, CURLOPT_SSLKEY,CURLOPT_SSLKEY_NAME);
        curl_easy_setopt(curl, CURLOPT_VERBOSE,1);
        curl_easy_setopt(curl, CURLOPT_USE_SSL,CURLUSESSL_ALL);
        
        //CERTIFICATE PINNING START
        
        /*
         VERIFY HOST 2:
         This option determines whether libcurl verifies that the server cert is for the server it is known as.
         When negotiating TLS and SSL connections, the server sends a certificate indicating its identity.
         When CURLOPT_SSL_VERIFYHOST is 2, that certificate must indicate that the server is the server to which you meant to connect, or the connection fails. Simply put, it means it has to have the same name in the certificate as is in the URL you operate against.
         Curl considers the server the intended one when the Common Name field or a Subject Alternate Name field in the certificate matches the host name in the URL to which you told Curl to connect.
         OPTION 2:
         This option controls checking the server's certificate's claimed identity. The server could be lying. To control lying, see CURLOPT_SSL_VERIFYPEER.
         */
        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST,2);

        NSString* cacert = [[NSBundle mainBundle] pathForResource:@CACERT_NAME ofType:@CACERT_FORMAT];
        if(cacert){
            
            /*
             SET CA INFO:
             set the file with the certs vaildating the server
             */
            curl_easy_setopt(curl, CURLOPT_CAINFO, cacert.UTF8String);//Setto il certificato da verificare per il comando successivo: VERIFY PEER
            
            /*
             VERIFY PEER TRUE:
             When negotiating a TLS or SSL connection, the server sends a certificate indicating its identity. Curl verifies whether the certificate is authentic, i.e. that you can trust that the server is who the certificate says it is. This trust is based on a chain of digital signatures, rooted in certification authority (CA) certificates you supply. curl uses a default bundle of CA certificates (the path for that is determined at build time) and you can specify alternate certificates with the CURLOPT_CAINFO option or the CURLOPT_CAPATH option.
             When CURLOPT_SSL_VERIFYPEER is enabled, and the verification fails to prove that the certificate is authentic, the connection fails. When the option is zero, the peer certificate verification succeeds regardless.
             Authenticating the certificate is not enough to be sure about the server. You typically also want to ensure that the server is the server you mean to be talking to. Use CURLOPT_SSL_VERIFYHOST for that. The check that the host name in the certificate is valid for the host name you're connecting to is done independently of the CURLOPT_SSL_VERIFYPEER option.
             */
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1);
            
            /*
             PINNED PUBILC KEY
             When negotiating a TLS or SSL connection, the server sends a certificate indicating its identity. A public key is extracted from this certificate and if it does not exactly match the public key provided to this option, curl will abort the connection before sending or receiving any data.
             */
            //curl_easy_setopt(curl, CURLOPT_PINNEDPUBLICKEY, cacert.UTF8String);
            

        }
        
        //CERTIFICATE PINNING END
        curl_easy_setopt(curl, CURLOPT_SSLENGINE,ENGINE_NAME);
        curl_easy_setopt(curl, CURLOPT_SSLKEYTYPE,KEY_TYPE);
        curl_easy_setopt(curl, CURLOPT_SSLCERTTYPE,KEY_TYPE);
        
        /* is redirected, so we tell libcurl to follow redirection */
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        
        //curl_easy_setopt(curl, CURLOPT_TRANSRANSFER, 1);
        //curl_easy_setopt(curl, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1);
        curl_easy_setopt(curl, CURLOPT_SSLVERSION, CURL_SSLVERSION_MAX_TLSv1_2);


        //            /* set the file with the certs vaildating the server */
        //            curl_easy_setopt(curl, CURLOPT_CAINFO, pCACertFile);

        
        /* send all data to this function  */
         curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_memory_callback);
        
        /* we pass our 'chunk' struct to the callback function */
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);
        
        /* what call to write: */
        curl_easy_setopt(curl, CURLOPT_URL, szUrl);
        
        //set POST method
        curl_easy_setopt(curl, CURLOPT_POST, 1);

        //give the data you want to post
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data);

        //give the data lenght
        //curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, length);
        
        
        struct curl_slist *headers = NULL;
            
        /* Remove a header curl would otherwise add by itself */
        headers = curl_slist_append(headers, "User-Agent: Mozilla/5.0");
        headers = curl_slist_append(headers, "Content-Type: application/x-www-form-urlencoded");
        
        /* set our custom set of headers */
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        /* use crypto engine */
        if (curl_easy_setopt(curl, CURLOPT_SSLENGINE, pEngine) != CURLE_OK) {
            /* load the crypto engine */
            
            fprintf(stderr, "can't set crypto engine\n");
        }
                

//            /* set the file with the certs vaildating the server */
//            curl_easy_setopt(curl, CURLOPT_CAINFO, pCACertFile);

        /* Perform the request, res will get the return code */
        res = curl_easy_perform(curl);
        /* Check for errors */
        if (res != CURLE_OK)
        {
            
            fprintf(stderr, "curl_easy_perform() failed: %d, %s\n", res, curl_easy_strerror(res));
            
            if(cie_error != 0)
                res = cie_error;
        }
        else
        {
            long codeop;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &codeop);
            
            res = (CURLcode)codeop;
        }
        
        /* always cleanup */
        curl_easy_cleanup(curl);
                
        /* free the custom headers */
        curl_slist_free_all(headers);
        
        if(chunk.size <= *pLength)
        {
            memcpy(response, chunk.memory, chunk.size);
            *pLength = chunk.size;
        }
        else
        {
            *pLength = 0;
        }


    }

    free(chunk.memory);
    curl_global_cleanup();

    return res;
}

@implementation HTTPSConnection

- (id) init
{
    self = [super init];
    if(self)
    {
        init_ssl_engine();
    }
    
    return self;
}

- (void) postTo: (NSString*) url withPIN: (NSString*) pin withCertificate: (NSData*) certificate withData: ( NSString* _Nullable ) data  callback: (void(^) (int code, NSData* respData)) callback
{
    const char* szUrl = url.UTF8String;
    const char* szPin = pin.UTF8String;
    
    unsigned char response[5000];
    long len = 5000;
    int res;
    if(data)
        res = https_post(szUrl, szPin, certificate.bytes, certificate.length, data.UTF8String, data.length, response, &len);
    else
        res = https_post(szUrl, szPin, certificate.bytes, certificate.length, NULL, NULL, response, &len);
    
    if(res == CURLE_COULDNT_RESOLVE_HOST || res == CURLE_OPERATION_TIMEDOUT)
    {
       callback(1000 + res, NULL);
    }
    else if(res == CURLE_OK || (res >= 200 && res < 400))    {
        callback(CURLE_OK, [NSData dataWithBytes:response length:len]);
    }
    else
    {
        callback(res, NULL);
    }

}


@end
