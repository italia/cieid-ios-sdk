//
//  TagHandler.swift
//  NFCTest
//
//

import Foundation
import CoreNFC
import CryptoKit

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
    
    static func dataWithHexString(hex: String) -> Data {
        var hex = hex
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
}

public class TagError : Error {
    init(errorType: String, errorDescription: String, errorDetails: String?)
    {
        self.errorDescription = errorDescription
        self.errorType = errorType
        self.errorDetails = errorDetails

    }

    public var errorDescription: String
    public var errorType: String
    public var errorDetails: String?

}

public class CIETagError : TagError {
    
    //Li riconosce entrambi scaduti - ERRORE 56
    let ERR_CERT_REVOKED = 98
    let ERR_CERT_EXPIRED = 99
    
    init(sw1sw2: UInt16, message: String?)
    {
        self.sw1sw2 = sw1sw2
        //print(sw1sw2)
        if(sw1sw2 == ERR_CERT_REVOKED)
        {
            super.init(errorType: "ABORT",errorDescription: "Carta non valida: certificato revocato", errorDetails: nil)
        }
        else if(sw1sw2 == ERR_CERT_EXPIRED)
        {
            super.init(errorType: "ABORT",errorDescription: "Carta non valida: certificato scaduto", errorDetails: nil)
            
        }
        else if(sw1sw2 < 1000)
        {
            super.init(errorType: "", errorDescription: NFCToken.decodeHTTPError(err: sw1sw2)["errorMsg"]!, errorDetails: nil)
            
        }
        else if (sw1sw2 == 1999) //PUK REQUEST ERROR
        {
            var errorDetails = "Richiesta di recupero del codice PUK fallita"//DEFAULT
            if (message != nil){
                if (message!.count > 0){
                    errorDetails = message!
                }
            }
            super.init(errorType: "ABORT_WITH_MESSAGE", errorDescription: "Richiesta di recupero del codice PUK fallita", errorDetails: errorDetails)
            
        }else if (sw1sw2 < 2000) //CURL ERROR
        {
            super.init(errorType: "NO_NETWORK", errorDescription: "Nessuna connessione ad internet rilevata", errorDetails: nil)
        }
        else
        {
            //super.init(errorDescription: NFCToken.decodeError(sw1sw2: sw1sw2))
            super.init(errorType: NFCToken.decodeError(sw1sw2: sw1sw2)["errorType"]!, errorDescription: NFCToken.decodeError(sw1sw2: sw1sw2)["errorMsg"]!, errorDetails: nil)
        }
        
    }
    
    public var sw1sw2 : UInt16
}

extension URL {
    var queryParameters: QueryParameters { return QueryParameters(url: self) }
}

class QueryParameters {
    let queryItems: [URLQueryItem]
    init(url: URL?) {
        queryItems = URLComponents(string: url?.absoluteString ?? "")?.queryItems ?? []
        //print(queryItems)
    }
    subscript(name: String) -> String? {
        return queryItems.first(where: { $0.name == name })?.value
    }
}

struct Constants {
    
    static let KEY_VALUE = "value"
    static let KEY_AUTHN_REQUEST_STRING = "authnRequestString"
    static let KEY_NAME = "name"
    static let KEY_NEXT_UTL = "nextUrl"
    static let KEY_OP_TEXT = "OpText"
    static let KEY_LOGO = "imgUrl"
    static let generaCodice = "generaCodice"
    static let authnRequest = "authnRequest"

    //sviluppo, collaudo sotto VPN , preproduzione senza VPN
    /*"https:\//preproduzione.idserver.servizicie.interno.gov.it/idp/Authn/SSL/Login2"
    https:\//preproduzione.idserver.servizicie.interno.gov.it/idp/Authn/SSL/X509AuthIbrido*/
    
    static let BASE_URL_IDP = "https://idserver.servizicie.interno.gov.it/idp/Authn/SSL/Login2"
    static let BASE_URL_IDP_IBRIDO = "https://idserver.servizicie.interno.gov.it/idp/Authn/SSL/X509AuthIbrido"

}

public class CIETagReader {
    var tag : NFCISO7816Tag
    var nfcToken : NFCToken
    let cieToken : CIEToken
    
    init( tag: NFCISO7816Tag) {
        self.tag = tag
        nfcToken = NFCToken(tag: self.tag)
        cieToken = CIEToken(nfcToken: nfcToken)
    }

    
    
    public func readIDServizi( completed: @escaping (String?, CIETagError?)->() )  {
        
        let concurrentQueue = DispatchQueue(label: "nfcthread", qos: .userInteractive, attributes: .concurrent)
        
        //print("start reading idServizi")
        concurrentQueue.async {
            
            let idServizi = NSMutableData()
            let sw = self.cieToken.idServizi(idServizi)
            
            if(sw != 0x9000)
            {
                
                // err = NFCToken.decodeError(sw1sw2: sw)
                //print("error \(err)")
               
                let error = CIETagError(sw1sw2: sw, message: nil)// NSError(domain:"smartcard", code:100, userInfo:[NSLocalizedDescriptionKey: err])
                
                completed(nil, error)
           }
           else
           {
                let idser = String(data: idServizi as Data, encoding: String.Encoding.utf8)
               print(idser)
                //print("idServizi: \(idser)")
           
                completed(idser, nil)
           }
        }
    }
    
    
    public func abbina(pin: String, completed: @escaping (String?, Data?, String?, String?, CIETagError?)->() )  {
        
        let concurrentQueue = DispatchQueue(label: "nfcthread", qos: .userInteractive, attributes: .concurrent)
        
        //print("start abbinamento")
        
        concurrentQueue.async {
    
            let idServizi = NSMutableData()
            var sw = self.cieToken.idServizi(idServizi)
            if(sw != 0x9000)
            {
                
                //let err = NFCToken.decodeError(sw1sw2: sw)
                //print("error \(err)")b
                
                let error = CIETagError(sw1sw2: sw, message: nil)
        
                completed(nil, nil, nil, nil, error)
                return;
            }
            
            let nis = String(data: idServizi as Data, encoding: String.Encoding.utf8)
//            KeychainHelper.delete(nis: nis)
            if(KeychainHelper.contains(nis: nis))
            {
                let error = CIETagError(sw1sw2: 0xFF02, message: nil)  // CIE già abbinata
                completed(nil, nil, nil, nil, error)
                return;
            }
            
            // autenticazione
            sw = self.cieToken.authenticate()
            if(sw != 0x9000)
            {
                
                //let err = NFCToken.decodeError(sw1sw2: sw)
                //print("error \(err)")
               
                let error = CIETagError(sw1sw2: sw, message: nil)
                                
                completed(nil, nil, nil, nil, error)
            }
            else
            {
                // verifica PIN
                sw = self.cieToken.verifyPIN(pin)

                if(sw != 0x9000)
                {

                    //let err = NFCToken.decodeError(sw1sw2: sw)
                    //print("error \(err)")

                    let error = CIETagError(sw1sw2: sw, message: nil)

                    completed(nil, nil, nil, nil, error)
                }
                else
                {
                    // lettura certificato
                    let cert = NSMutableData()
                    let sw = self.cieToken.certificate(cert)
                    if(sw != 0x9000)
                    {
                        
                        //let err = NFCToken.decodeError(sw1sw2: sw)
                        //print("error \(err)")
                        
                        let error = CIETagError(sw1sw2: sw, message: nil)
                
                        completed(nil, nil, nil, nil, error)
                    }
                    else
                    {
                        let certificate : SecCertificate = SecCertificateCreateWithData(nil, cert)!

                        let subject = SecCertificateCopyNormalizedSubjectSequence(certificate)

                        let hexstr = (subject! as Data).hexEncodedString().uppercased();
                        
                        //print(hexstr)

                        let posGivenName = hexstr.range(of: "55042A")
                        let posSurName = hexstr.range(of: "550404")
                                                
                        if(posGivenName == nil || posSurName == nil)
                        {
                            let error = CIETagError(sw1sw2: 0xFF01, message: nil)
                            completed(nil, nil, nil, nil, error)
                            return;
                        }
                        
                        let givennameHex = hexstr[posGivenName!.upperBound..<hexstr.endIndex]
                        let surnameHex = hexstr[posSurName!.upperBound..<hexstr.endIndex]

                        //print(givennameHex)
                        //print(surnameHex)
                                                
                        var givenname = Data.dataWithHexString(hex: String(givennameHex) as String)
                        var surname = Data.dataWithHexString(hex: String(surnameHex) as String)
                                                
                        var len = givenname[1] + 2
                        givenname = givenname[2..<len]
                        
                        len = surname[1] + 2
                        surname = surname[2..<len]
                        
                        let givennameStr = String(data: givenname, encoding: String.Encoding.utf8)
                        let surnameStr = String(data: surname, encoding: String.Encoding.utf8)
                        
                        //print(givennameStr)
                        //print(surnameStr)
                                                
                        // TODO: aggiungere certificato in cache con la prima parte del PIN
                        
                        let halfpin = pin.dropLast(4)
                        
                        /*
                        Prima di memorizzare i dati elimino eventuali precedenti abbinamenti, ciò evita che utenti che in passato utilizzavano la biometria in una precedente installazione dell'app e che decidono di registrare la stessa CIE senza biometria su una nuova installazione, trovino invece la biometria configurata
                        */
                        KeychainHelper.delete(nis: nis)
                        //Registro i dati della CIE
                        KeychainHelper.add(nis: nis)
                        KeychainHelper.saveCertificate(nis: nis, nome: givennameStr, cognome: surnameStr, certificate: cert as Data)
                        KeychainHelper.saveHalfPIN(nis: nis, pin: String(halfpin))
                        completed(nis, cert as Data, givennameStr, surnameStr, nil)
                        
                    }
                }
           }
        }
    }
    
    public func post(url: String, pin: String, deepLinkInfo: DeepLinkInfo?,completed: @escaping (Data?, CIETagError?)->() )  {
    //        let nextUrl = url1!.queryParameters[Constants.KEY_NEXT_UTL]!
    //        let opText = url1!.queryParameters[Constants.KEY_OP_TEXT]!
    //        let logo = url1?.queryParameters[Constants.KEY_LOGO]!
        guard let name = deepLinkInfo?.name , let value = deepLinkInfo?.value, let req = deepLinkInfo?.authReq else {
            completed(nil,nil)
            return
        }
        let params = "\(name)=\(value)&\(Constants.authnRequest)=\(req)&\(Constants.generaCodice)=1"
            
            let concurrentQueue = DispatchQueue(label: "nfcthread", qos: .userInteractive, attributes: .concurrent)
                
            //print("start autenticazione SSL")
            
            concurrentQueue.async {
        
                 let idServizi = NSMutableData()
                 var sw = self.cieToken.idServizi(idServizi)
                 if(sw != 0x9000)
                 {
                     //let err = NFCToken.decodeError(sw1sw2: sw)

                     //print("error \(err)")

                     let error = CIETagError(sw1sw2: sw, message: nil)

                     completed(nil, error)
                     return;
                 }

                 let nis = String(data: idServizi as Data, encoding: String.Encoding.utf8)

                 let halfpin = KeychainHelper.getHalfPIN(nis: nis)
                 if(halfpin == nil)
                 {
                     let error = CIETagError(sw1sw2: 0xFF03, message: nil)  // CIE non abbinata
                     completed(nil, error)
                     return;
                 }

                guard let certificate = KeychainHelper.getCertificate(nis: nis) else {
                    completed(nil, nil)
                    return;
                }

                 sw = self.cieToken.authenticate()
                 if(sw != 0x9000)
                 {
                     let error = CIETagError(sw1sw2: sw, message: nil)
                     completed(nil, error)
                     return;
                 }

                 sw = self.cieToken.verifyPIN(CiedSDK.current.getPin())
                 if(sw != 0x9000)
                 {
                     let error = CIETagError(sw1sw2: sw, message: nil)
                     completed(nil, error)
                     return
                 }

                
                print("parameters: \(params)")
                                                                        
                 // post
                
                let respone = NSMutableData()
                sw = self.cieToken.post(Constants.BASE_URL_IDP, pin: CiedSDK.current.getPin(), certificate: certificate, data: params, response: respone)
                if(sw != 0)
                {
                    //print("error \(sw)")
                   
                    let error = CIETagError(sw1sw2: sw, message: nil)
           
                    completed(nil, error)
                }
                else
                {
                    completed(respone as Data, nil)
                }
            }
        }
    
    
    private func readServizi(completion: @escaping((String?, CIETagError?) -> Void)) {
        let idServizi = NSMutableData()
        let sw = self.cieToken.idServizi(idServizi)
        if(sw != 0x9000)
        {
            
            // err = NFCToken.decodeError(sw1sw2: sw)
            //print("error \(err)")
           
            let error = CIETagError(sw1sw2: sw, message: nil)// NSError(domain:"smartcard", code:100, userInfo:[NSLocalizedDescriptionKey: err])
            
            completion(nil, error)
       }
       else
       {
            let idser = String(data: idServizi as Data, encoding: String.Encoding.utf8)
            //print("idServizi: \(idser)")
       
           completion(idser, nil)
       }
    }
}

