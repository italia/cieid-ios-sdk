//
//  PukRequestNetworkManager.swift
//  cieID
//
//  Created by Eros Brienza on 28/06/21.
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation

final class PukRequestNetworkManager: NSObject {
    
    //URL FIRST PUK REQUEST
    let PUK_BASEURL   =     "repukcol.ddns.net"
    let CERT_NAME   =       "recuperopuk.servizicie.interno.gov.it"
    let CERT_EXTENSION   =  "cer"
    let PUK_TIMEOUT : Double   =       20
    
    private lazy var certificates: [Data] = {
            let url = Bundle.main.url(forResource: CERT_NAME, withExtension: CERT_EXTENSION)!
            let data = try! Data(contentsOf: url)
            return [data]
        }()
    
    private var session: URLSession!
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func sendFirstDataForPUKRequest(nun: String!, nis: String!, addressSms: String!, addressEmail: String!, sod: NSMutableData!, modHEXString: String!, expHEXString: String!, completionHandler: @escaping (_ procedureId:String?,_ randomCode:String?, _ msg:String?, _ errorMessage: String?) -> ()) {
        
        guard KeyGen.shared.generateKeys() else {
            return
        }
        
        if EnviromentManager.enviroment == .MOCK {
            let jsonResponse = MockManager.firstCallPuk()
            let procedureId : String = jsonResponse["procedureId"] as? String ?? ""
            let randomCode : String  = jsonResponse["randomCode"] as? String ?? ""
            let msg : String  = jsonResponse["msg"] as? String ?? ""
            completionHandler(procedureId, randomCode, msg, nil)
            return
        }
        //VERIFICO DI ESSERE IN POSSESSO DI TUTTI I DATI
        if(nun.count > 0 && nis.count > 0 && (addressSms.count > 0 || addressEmail.count > 0) && modHEXString.count > 0 && expHEXString.count > 0 && !sod.isEmpty){
            
            var nisString = nis
            if (nisString!.count > 12){
                nisString = String(nisString!.prefix(12))
            }
            // CASO NO INTERNET CONNECTION
            if(TestConnessione.test() == true){
                            
                var queryItems = [URLQueryItem(name: "msgType", value: "A01"), URLQueryItem(name: "lng", value: "IT"), URLQueryItem(name: "nun", value: nun), URLQueryItem(name: "nis", value: nisString)]
                
                if (addressSms.count > 0){
                    queryItems.append(URLQueryItem(name: "addressSms", value: addressSms))
                }
                
                if (addressEmail.count > 0){
                    queryItems.append(URLQueryItem(name: "addressEmail", value: addressEmail))
                }
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = PUK_BASEURL
                urlComponents.path = "/repuk/api/repuks/"
                urlComponents.queryItems = queryItems
                if (addressSms.count > 0 || addressEmail.count > 0){
                    urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?
                        .replacingOccurrences(of: "+", with: "%2B")
                }
                                
                var request = URLRequest(url: urlComponents.url!)
                
                request.timeoutInterval = PUK_TIMEOUT
                request.httpMethod = "PUT"
                request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Accept")

                do {
                    // prepare json data
                    let publicKey = KeyGen.shared.generateModulusExponent()
                    let kPubExo = publicKey.exp?.hexEncodedString()
                    let kPubMod = publicKey.mod?.hexEncodedString()
                    let sodString = sod.base64EncodedString().replacingOccurrences(of: "\\/", with: "/")
                    let json: [String: Any] = [
                                                "sod": sodString,
                                                "kpubint": ["modulus":modHEXString!,                                     "exponent":expHEXString!
                                                          ],
                                                "kpubdev": ["modulus" : kPubMod,
                                                           "exponent": kPubExo,
                                                          ]
                                                ]
                                        
                    if JSONSerialization.isValidJSONObject(json) {
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: json)
                        request.httpBody = jsonData
                        
                    } else {
                        
                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil,nil,nil, erroreMsg)
                        return
                        
                    }
                }
                catch {
                    
                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                    completionHandler(nil,nil,nil, erroreMsg)
                    return

                }
                
                
                logRequest(number: 0, request: request)
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    if (error != nil) {
                        print(error?.localizedDescription)
                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil,nil,nil, erroreMsg)
                        return

                    }else{
                            
                        if let httpResponse = response as? HTTPURLResponse {
                            self.logResponse(number: 0, response: httpResponse)
                            if (httpResponse.statusCode == 200){
                            
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let procedureId : String = jsonResponse?["procedureId"] as? String ?? ""
                                        let randomCode : String  = jsonResponse?["randomCode"] as? String ?? ""
                                        let msg : String  = jsonResponse?["msg"] as? String ?? ""

                                        //SUCCESS - Abbiamo tutti i dati
                                        if (procedureId.count > 0 && randomCode.count > 0 && msg.count > 0){
                                        
                                            //SUCCESS
                                            completionHandler(procedureId, randomCode, msg, nil)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil,nil,nil, erroreMsg)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil,nil,nil, erroreMsg)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil,nil,nil, erroreMsg)
                                    return

                                }
                                    
                                
                            }else{
                            
                                if (data != nil){

                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any ]

                                        let reason = jsonResponse?["reason"] as? String ?? ""

                                        //Su A01 e A02 non servono
                                        //let resultCodes = jsonResponse?["resultCodes"] as? String ?? ""
                                        //let resetIsNecessary: Bool = jsonResponse?["closed"] as? Bool ?? false

                                        //ERROR CON MESSAGGIO
                                        if (reason.count > 0){
                                        
                                            let erroreMsg = reason
                                            completionHandler(nil,nil,nil, erroreMsg)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil,nil,nil, erroreMsg)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil,nil,nil, erroreMsg)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil,nil,nil, erroreMsg)
                                    return

                                }
                                

                            }
                            
                        }else{
                            
                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                            completionHandler(nil,nil,nil, erroreMsg)
                            return

                        }

                    }

                }
                
                dataTask.resume()

            }else{
                
                let erroreMsg = "Nessuna connessione ad internet rilevata"
                completionHandler(nil,nil,nil, erroreMsg)
                return

            }
            
        }else{
            
            let erroreMsg = "Dati obbligatori non presenti"
            completionHandler(nil,nil,nil, erroreMsg)
            return

        }
        
    }
    
    func sendSignedDataForPUKRequest(procedureId: String, randomCodeFirmato: NSMutableData, completionHandler: @escaping (_ procedureId:String?,_ errorMessage: String?) -> ()) {
        
        //VERIFICO DI ESSERE IN POSSESSO DI TUTTI I DATI
        if EnviromentManager.enviroment == .MOCK {
            let jsonResponse = MockManager.secondCallPuk()
            let procedureId = jsonResponse["procedureId"] as? String ?? ""
            completionHandler(procedureId,nil)
            return
        }
        
        if(procedureId.count > 0 && !randomCodeFirmato.isEmpty){
        
            // CASO NO INTERNET CONNECTION
            if(TestConnessione.test() == true){
                
                let randomCodeFirmatoBase64StringEncoded = randomCodeFirmato.base64EncodedString()
                let randomCodeFirmatoBase64URLEncoded = self.base64StringToBase64URL(base64String: randomCodeFirmatoBase64StringEncoded)
                let queryItems = [URLQueryItem(name: "msgType", value: "A02"), URLQueryItem(name: "lng", value: "IT"), URLQueryItem(name: "randomCodeEncrypted", value: randomCodeFirmatoBase64URLEncoded)]//Replacing di stringhe converte Base64String in Base64Url
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = PUK_BASEURL
                urlComponents.path = "/repuk/api/repuks/\(procedureId)"
                urlComponents.queryItems = queryItems
                                
                var request = URLRequest(url: urlComponents.url!)

                request.timeoutInterval = PUK_TIMEOUT
                request.httpMethod = "PUT"
                request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Accept")
                logRequest(number: 0, request: request)
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    if (error != nil) {

                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil, erroreMsg)
                        return

                    }else{
                            
                        if let httpResponse = response as? HTTPURLResponse {
                            self.logResponse(number: 0, response: httpResponse)

                            if (httpResponse.statusCode == 200){
                            
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let procedureId = jsonResponse?["procedureId"] as? String ?? ""

                                        //SUCCESS - Abbiamo tutti i dati
                                        if (procedureId.count > 0){
                                        
                                            //SUCCESS
                                            completionHandler(procedureId, nil)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg)
                                        return

                                    }
                                    
                                }else{
                                    
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg)
                                    return

                                }
                                    
                                
                            }else{//Status code != 200 ha anche un payload
                                
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let reason = jsonResponse?["reason"] as? String ?? ""
                                        
                                        //Su A01 e A02 non servono
                                        //let resultCodes = jsonResponse?["resultCodes"] as? String ?? ""
                                        //let resetIsNecessary: Bool = jsonResponse?["closed"] as? Bool ?? false

                                        //ERROR CON MESSAGGIO
                                        if (reason.count > 0){
                                        
                                            let erroreMsg = reason
                                            completionHandler(nil, erroreMsg)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg)
                                    return

                                }

                            }
                            
                        }else{
                            
                            let erroreMsg = "Status code non presente"
                            completionHandler(nil, erroreMsg)
                            return
                            
                        }

                    }

                }
                
                dataTask.resume()

            }else{
                
                let erroreMsg = "Nessuna connessione ad internet rilevata"
                completionHandler(nil, erroreMsg)
                return

            }
            
        }else{
            
            let erroreMsg = "Dati obbligatori non presenti"
            completionHandler(nil, erroreMsg)
            return
        }
        
    }
    
    func sendOTPForPUKRequest(nun: String, procedureId: String, totpHash: String, completionHandler: @escaping (_ randomCode:String?,_ errorMessage: String?, _ resetIsNecessary: Bool?) -> ()) {
        guard KeyGen.shared.getKeysFromKeychain() else {
            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
            completionHandler(nil, erroreMsg, false)
            return
        }
//
        //VERIFICO DI ESSERE IN POSSESSO DI TUTTI I DATI
        if(procedureId.count > 0 && nun.count > 0 && totpHash.count > 0){
            
            // CASO NO INTERNET CONNECTION
            if(TestConnessione.test() == true){
            
                let queryItems = [URLQueryItem(name: "msgType", value: "A03"), URLQueryItem(name: "lng", value: "IT"), URLQueryItem(name: "nun", value:nun)]
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = PUK_BASEURL
                urlComponents.path = "/repuk/api/repuks/\(procedureId)"
                urlComponents.queryItems = queryItems
                                
                var request = URLRequest(url: urlComponents.url!)

                request.timeoutInterval = PUK_TIMEOUT
                request.httpMethod = "PUT"
                request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Accept")

                
                do {
                    // prepare json data
                    let json: [String: Any] = ["totpHash": totpHash]
                    
                    if JSONSerialization.isValidJSONObject(json) {
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: json)
                        request.httpBody = jsonData
                        
                    } else {
                        
                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil, erroreMsg, false)
                        return
                        
                    }
                }
                catch {
                    
                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                    completionHandler(nil, erroreMsg, false)
                    return

                }
                
                logRequest(number: 0 , request: request)
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    if (error != nil) {

                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil, erroreMsg, false)
                        return

                    }else{
                            
                        if let httpResponse = response as? HTTPURLResponse {
                            self.logResponse(number: 0, response: httpResponse)

                            if (httpResponse.statusCode == 200){
                            
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let randomCode = jsonResponse?["randomCode"] as? String ?? ""

                                        //SUCCESS - Abbiamo tutti i dati
                                        if (randomCode.count > 0){
                                        
                                            //SUCCESS
                                            completionHandler(randomCode, nil, false)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg, false)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }
                                    
                                
                            }else{//Status code != 200 ha anche un payload
                                
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let reason : String = jsonResponse?["reason"] as! String
                                        //let resultCodes = jsonResponse?["resultCodes"] as? String ?? ""
                                        let resetIsNecessary: Bool = jsonResponse?["closed"] as? Bool ?? false

                                        //ERROR CON MESSAGGIO
                                        if (reason.count > 0){
                                        
                                            let erroreMsg = reason
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }

                            }
                            
                        }else{
                            
                            let erroreMsg = "Status code non presente"
                            completionHandler(nil, erroreMsg, false)
                            return
                            
                        }

                    }

                }
                
                dataTask.resume()

            }else{
                
                let erroreMsg = "Nessuna connessione ad internet rilevata"
                completionHandler(nil, erroreMsg, false)
                return

            }
            
        }else{
            
            let erroreMsg = "Dati obbligatori non presenti"
            completionHandler(nil, erroreMsg, false)
            return
        }
        
    }
    
    func base64StringToBase64URL(base64String: String) -> String {
        var base64URL = base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        if base64URL.count % 4 != 0 {
            base64URL.append(String(repeating: "=", count: 4 - base64URL.count % 4))
        }
        return base64URL
    }
    
    func sendSignedOTPForPUKRequest(nun: String, procedureId: String, randomCodeFirmato: NSMutableData, completionHandler: @escaping (_ puk:String?,_ errorMessage: String?, _ resetIsNecessary: Bool?) -> ()) {
//        if EnviromentManager.enviroment == .MOCK {
//            let jsonResponse = MockManager.fourthCallPuk()
//
//            let firstPartPuk = (jsonResponse["pukFirstHalfEncrypted"] as? String)?.data(using: .utf8)
//            let secondPartPuk = (jsonResponse["pukSecondHalfEncrypted"] as? String)?.data(using: .utf8)
//
//            //SUCCESS - Abbiamo tutti i dati
//            guard let firstPartPuk = firstPartPuk, let secondPartPuk = secondPartPuk, let dFirstPartPuk = KeyGen.shared.decryptData(data: firstPartPuk),let dSecondPartPuk = KeyGen.shared.decryptData(data: secondPartPuk) else {
//                return
//            }
////            let firstPukString = String(data: dFirstPartPuk, encoding: .utf8)
////            let secondPartString = String(data: dSecondPartPuk, encoding: .utf8)
//            let puk = "17324943"
//            //SUCCESS
//            completionHandler(puk, nil, true)
//            return
//        }
        //VERIFICO DI ESSERE IN POSSESSO DI TUTTI I DATI
        if(procedureId.count > 0 && nun.count > 0 && !randomCodeFirmato.isEmpty){
        
            // CASO NO INTERNET CONNECTION
            if(TestConnessione.test() == true){
            
                let randomCodeFirmatoBase64StringEncoded = randomCodeFirmato.base64EncodedString()
                let randomCodeFirmatoBase64URLEncoded = self.base64StringToBase64URL(base64String: randomCodeFirmatoBase64StringEncoded)

                
                let queryItems = [URLQueryItem(name: "msgType", value: "A04"), URLQueryItem(name: "lng", value: "IT"), URLQueryItem(name: "nun", value: nun), URLQueryItem(name: "randomCodeEncrypted", value: randomCodeFirmatoBase64URLEncoded)]//Replacing di stringhe converte Base64String in Base64Url
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = PUK_BASEURL
                urlComponents.path = "/repuk/api/repuks/\(procedureId)/puk"
                urlComponents.queryItems = queryItems
                                
                var request = URLRequest(url: urlComponents.url!)
                
                request.timeoutInterval = PUK_TIMEOUT
                request.httpMethod = "PUT"
                request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Content-Type")
                logRequest(number: 0, request: request)
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    if (error != nil) {

                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                        completionHandler(nil, erroreMsg, false)
                        return

                    }else{
                            
                        if let httpResponse = response as? HTTPURLResponse {
                            self.logResponse(number: 0, response: httpResponse)

                            if (httpResponse.statusCode == 200){
                            
                                if (data != nil){
                                  
                                    do {
//                                            let string = "zW4bAJVoXsHgEC+UksW079itQor++OUhpo2bSc++MNzEfrGWZwZBnVkbdIGoPCzL1m66rQYyWyEcQX4cIrg877UJZg3xri+Xrn9OH9gOCrVDKa0PZcimSffa0P8yYc+1F2ws0Y1E16BkvvNguMfPEncwQxnAIq1yI9x+/PyK6lnRHRDhVhrZq8zNKkzMpUtDRWxb/QoAWT3EuhtmKK8w4XOzGLaG4mqU8hpmlYUJiTV+L7AFcTV5iu1fRCdggNxndMvfOEIhGBlQaTi9BnDU2xKy5MFyYNdhZv0ideKKW/SWgB+FOa1Q+h8ZSeib7QMpmqoloRmXdkXN9VimNWeSEw=="
//                                        let data = Data(base64Encoded: string)
//                                        guard let message = KeyGen.shared.decryptData(data: data!) else {
//                                            return
//                                        }
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]
                                        print("RESPONSE: \(jsonResponse)")
                                        let firstPartPukString = jsonResponse?["pukFirstHalfEncrypted"] as? String
                                        let secondPartPukString = jsonResponse?["pukSecondHalfEncrypted"] as? String
                                        let firstPartPuk = Data(base64Encoded: firstPartPukString!, options: .ignoreUnknownCharacters)
                                        let secondPartPuk = Data(base64Encoded: secondPartPukString!, options: .ignoreUnknownCharacters)
//                                        //SUCCESS - Abbiamo tutti i dati
                                        guard let dFirstPartPuk = KeyGen.shared.decryptData(data: firstPartPuk!),let dSecondPartPuk = KeyGen.shared.decryptData(data: secondPartPuk!) else {
                                            return
                                        }
                                        if (firstPartPuk!.count > 0 && secondPartPuk!.count > 0){
                                            let firstPukString = String(data: dFirstPartPuk, encoding: .utf8)
                                            let secondPartString = String(data: dSecondPartPuk, encoding: .utf8)
                                            let puk = "\(firstPukString)\(secondPartString)"

                                            //SUCCESS
                                            completionHandler(puk, nil, true)
                                            return
                                        
//
                                        }else{

                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg, false)
                                            return

                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }
                                    
                                
                            }else{//Status code != 200 ha anche un payload
                                
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let reason = jsonResponse?["reason"] as? String ?? ""
                                        //let resultCodes = jsonResponse?["resultCodes"] as? String ?? ""
                                        let resetIsNecessary: Bool = jsonResponse?["closed"] as? Bool ?? false

                                        //ERROR CON MESSAGGIO
                                        if (reason.count > 0){
                                        
                                            let erroreMsg = reason
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di recupero del codice PUK fallita"
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }

                            }
                            
                        }else{
                            
                            let erroreMsg = "Status code non presente"
                            completionHandler(nil, erroreMsg, false)
                            return
                            
                        }

                    }

                }
                
                dataTask.resume()

            }else{
                
                let erroreMsg = "Nessuna connessione ad internet rilevata"
                completionHandler(nil, erroreMsg, false)
                return

            }
            
        }else{
            
            let erroreMsg = "Dati obbligatori non presenti"
            completionHandler(nil, erroreMsg, false)
            return
        }
        
    }
    
    func getStatusPUKRequest(nun: String, procedureId: String, completionHandler: @escaping (_ msg:String?,_ errorMessage: String?, _ resetIsNecessary: Bool?) -> ()) {
        
        //VERIFICO DI ESSERE IN POSSESSO DI TUTTI I DATI
        if(procedureId.count > 0 && nun.count > 0){
        
            // CASO NO INTERNET CONNECTION
            if(TestConnessione.test() == true){
            
                let queryItems = [URLQueryItem(name: "msgType", value: "A05"), URLQueryItem(name: "lng", value: "IT"), URLQueryItem(name: "nun", value: nun)]
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = PUK_BASEURL
                urlComponents.path = "/repuk/api/repuks/\(procedureId)"
                urlComponents.queryItems = queryItems
                                
                var request = URLRequest(url: urlComponents.url!)

                request.timeoutInterval = PUK_TIMEOUT
                request.httpMethod = "GET"
                request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
                request.setValue("application/vnd.cnsd.api.repukbo.v1+json", forHTTPHeaderField: "Content-Type")
                logRequest(number: 0, request: request)
                let dataTask = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                    if (error != nil) {

                        let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                        print("ERRORE: ")
                        print(error?.localizedDescription ?? "NO LOCALIZED DESCRIPTION")
                        completionHandler(nil, erroreMsg, false)
                        return

                    }else{
                            
                        if let httpResponse = response as? HTTPURLResponse {
                            self.logResponse(number: 0, response: httpResponse)
                            self.logResponse(number: 0, response: httpResponse)

                            if (httpResponse.statusCode == 200){
                            
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]
                                        
                                        let msg = jsonResponse?["msg"] ?? ""

                                        //SUCCESS - Abbiamo tutti i dati
                                        if ((msg as! String).count > 0){
                                        
                                            //SUCCESS
                                            completionHandler((msg as! String), nil, false)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                            completionHandler(nil, erroreMsg, false)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    
                                    let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }
                                    
                                
                            }else{//Status code != 200 ha anche un payload
                                
                                if (data != nil){
                                  
                                    do {
                                        
                                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:Any]

                                        let reason = jsonResponse?["reason"] as? String ?? ""
                                        //let resultCodes = jsonResponse?["resultCodes"] as? String ?? ""
                                        let resetIsNecessary: Bool = jsonResponse?["closed"] as? Bool ?? false
                                        
                                        //ERROR CON MESSAGGIO
                                        if (reason.count > 0){
                                        
                                            let erroreMsg = reason
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return

                                        }else{
                                            
                                            let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                            completionHandler(nil, erroreMsg, resetIsNecessary)
                                            return
                                            
                                        }

                                    } catch {
                                        
                                        let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                        completionHandler(nil, erroreMsg, false)
                                        return

                                    }
                                    
                                }else{
                                    
                                    let erroreMsg = "Richiesta di verifica della pratica di recupero PUK fallita, riprova."
                                    completionHandler(nil, erroreMsg, false)
                                    return

                                }

                            }
                            
                        }else{
                            
                            let erroreMsg = "Status code non presente"
                            completionHandler(nil, erroreMsg, false)
                            return
                            
                        }

                    }

                }
                
                dataTask.resume()

            }else{
                
                let erroreMsg = "Nessuna connessione ad internet rilevata"
                completionHandler(nil, erroreMsg, false)
                return

            }
            
        }else{
            
            let erroreMsg = "Dati obbligatori non presenti"
            completionHandler(nil, erroreMsg, false)
            return
            
        }
        
    }
}

// MARK: - URLSessionDelegate
extension PukRequestNetworkManager: URLSessionDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let urlCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential,urlCredential)
//        if let trust = challenge.protectionSpace.serverTrust, SecTrustGetCertificateCount(trust) > 0 {
//
//            if let certificate = SecTrustGetCertificateAtIndex(trust, 0) {
//
//                let data = SecCertificateCopyData(certificate) as Data
//
//                if certificates.contains(data) {
//
//                    completionHandler(.useCredential, URLCredential(trust: trust))
//                    return
//                }
//            }
//        }
//
//        Analytics.logger.logPukCertPinningFailed()
//        completionHandler(.cancelAuthenticationChallenge, nil)
        
    }
    
    
    private func logRequest(number: Int, request: URLRequest) {
        print("START REQUEST------\n")
        print("\(request.url!)")
        print(request.allHTTPHeaderFields!)
        if let body = request.httpBody {
            print(String(data: body, encoding: .utf8)!)
        }
        print("END REQUEST------\n")
    }
    
    private func logResponse(number: Int, response: HTTPURLResponse) {
        print("START REQUEST------\n")
        print("\(response.statusCode)")
        print(response)
        print("END REQUEST------\n")
    }
}
