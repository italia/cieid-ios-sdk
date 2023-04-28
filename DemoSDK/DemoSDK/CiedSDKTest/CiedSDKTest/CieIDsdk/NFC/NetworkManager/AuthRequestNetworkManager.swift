//
//  AuthRequestNetworkManager.swift
//  cieID
//
//

    
import Foundation

//HYBRID
let IDP_NAME    =       "IdPName"
let OP_TEXT_H   =       "opText"
let OP_TYPE     =       "opType"
let OP_ID       =       "opId"
let USER_ID     =       "userId"
let SP_NAME     =       "SPName"
let SP_LOGO     =       "SPLogo"
//MOBILE
let NAME        =       "name"
let OP_TEXT_M   =       "OpText"
let IMG_URL     =       "imgUrl"
let VALUE       =       "value"
let AUTHN_REQ   =       "authnRequestString"
let NEXT_URL    =       "nextUrl"
//APP2APP
let SOURCE_APP  =       "sourceApp"
let PARAM_TO_REMOVE  =       "/&sourceApp"
//URL UNIVERSAL LINK MINISTERO
let URL_ULINK   =       "https://ios.idserver.servizicie.interno.gov.it/"

class AuthRequestNetworkManager: NSObject {
    
    //Metodo che verifica l'url e restituisce i parametri dall'URL Hybrid auth
    class func urlHybridParams(urlString: String)-> (String/*opText*/, String/*opLogo*/, String/*opId*/){
        
        var opText: String = ""
        var opLogo: String = ""
        var opId: String = ""

        if (urlHybridIsValid(urlString: urlString)){
                        
            let url = URL.init(string: urlString.replacingOccurrences(of: " ", with: "_"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]
                   
            opText = (urlParameters[OP_TEXT_H]?.replacingOccurrences(of: "_", with: " "))!//Rimetto gli _ ad opText
            opId = urlParameters[OP_ID]!
            
            //Parametro logo non è obbligatorio, se non esiste lo inizializzo a ""
            if(urlParameters[SP_LOGO] == nil){
                
                opLogo = ""
                
            }else{
                
                opLogo = urlParameters[SP_LOGO]!
                
            }
            
            
        }
        
        return (opText, opLogo, opId)
        
    }
    
    //Metodo che verifica se l'URL Hybrid auth è valido
    class func urlHybridIsValid(urlString: String)-> (Bool){

        if (urlString.count > 0){
            
            //Tolgo gli spazi se presenti altrimenti l'url non potrebbe essere valorizzato
            if (URL.init(string: urlString.replacingOccurrences(of: " ", with: "_")) == nil){
                
                return false

            }
            
            let url = URL.init(string: urlString.replacingOccurrences(of: " ", with: "_"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]
                                                
            //Verifico che campi obbligatori esistono
            if(urlParameters[IDP_NAME] != nil && urlParameters[OP_TEXT_H] != nil && urlParameters[OP_TYPE] != nil && urlParameters[OP_ID] != nil && urlParameters[USER_ID] != nil && urlParameters[SP_NAME] != nil){
            
                //Verifico che campi obbligatori non sono vuoti
                if(urlParameters[IDP_NAME]!.count > 0 && urlParameters[OP_TEXT_H]!.count > 0 && urlParameters[OP_TYPE]!.count > 0 && urlParameters[OP_ID]!.count > 0 && urlParameters[USER_ID]!.count > 0 && urlParameters[SP_NAME]!.count > 0){
                
                    return true
                    
                }
                 
                
            }
            
        }
        
        return false
        
    }
    
    //Metodo che verifica la corretta formattazione dell'URI e ne restituisce i parametri
    class func urlParams(urlString: String)-> (String/*opText*/, String/*opLogo*/, String/*nextUrl*/, String/*name*/, String/*value*/){
                
        var opText: String = ""
        var opLogo: String = ""
        var nextUrl: String = ""
        var name: String = ""
        var value: String = ""

        if (urlIsValid(urlString: urlString)){
                          
            let noCieID = urlString.replacingOccurrences(of: URL_ULINK, with: "https://www.dominio.it/parametro?")
            let urlStringPercentDecoded = NSString(string: noCieID.removingPercentEncoding!)
            
            let urlStringNoSpace = String.init(urlStringPercentDecoded).replacingOccurrences(of: " ", with: "_")
            let url: URL = URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]
                
            nextUrl = urlParameters[NEXT_URL]!
            name = urlParameters[NAME]!
            value = urlParameters[VALUE]!
                    
            opText = urlParameters[OP_TEXT_M]!
            opText = opText.replacingOccurrences(of: "identita", with: "identità")
            opText = opText.replacingOccurrences(of: "_", with: " ")
                    
            //Parametro logo non è obbligatorio, se non esiste lo inizializzo a ""
            if(urlParameters[SP_LOGO] == nil){
                        
                opLogo = ""
                    
            }else{
                        
                opLogo = urlParameters[SP_LOGO]!
                        
            }
            
        }
        
        return (opText, opLogo, nextUrl, name, value)
        
    }
    
    //Metodo che verifica la corretta formattazione dell'URI
    class func urlIsValid(urlString: String)-> Bool{
            
        if (urlString.count > 0){
              
            //Formatto stringa per farla accettare da URLType
            let noCieID = urlString.replacingOccurrences(of: URL_ULINK, with: "https://www.dominio.it/parametro?")
            let urlStringPercentDecoded = NSString(string: noCieID.removingPercentEncoding!)
            
            let urlStringNoSpace = String.init(urlStringPercentDecoded).replacingOccurrences(of: " ", with: "_")
            
            //Verifico se è un URL VALIDO
            if (URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a")) == nil){
                
                return false

            }
            
            let url: URL = URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]

            //Verifico che campi obbligatori esistono
            if(urlParameters[OP_TEXT_M] != nil && urlParameters[NAME] != nil && urlParameters[IMG_URL] != nil && urlParameters[VALUE] != nil && urlParameters[AUTHN_REQ] != nil && urlParameters[NEXT_URL] != nil){
            
                //Verifico che campi obbligatori non sono vuoti
                if(urlParameters[OP_TEXT_M]!.count > 0 && urlParameters[NAME]!.count > 0 && urlParameters[IMG_URL]!.count > 0 && urlParameters[VALUE]!.count > 0 && urlParameters[AUTHN_REQ]!.count > 0 && urlParameters[NEXT_URL]!.count > 0){
                
                    return true
                    
                }
                
            }
            
        }
        
        return false
        
    }
    
    //Metodo che verifica la corretta formattazione dell'URI App2App
    class func urlApp2AppParams(urlString: String)-> (String/*opText*/, String/*opLogo*/, String/*nextUrl*/, String/*name*/, String/*value*/, String/*sourceApp*/, String/*challenge*/){
                
        var opText: String = ""
        var opLogo: String = ""
        var nextUrl: String = ""
        var name: String = ""
        var value: String = ""
        var sourceApp: String = ""
        var challenge: String = ""//L'URL App2App contiene un parametro sourceApp da rimuovere

        if (urlApp2AppIsValid(urlString: urlString)){
              
            //Formatto stringa per farla accettare da URLType
            
            let noCieID = urlString.replacingOccurrences(of: URL_ULINK, with: "https://www.dominio.it/parametro?")
            let urlStringPercentDecoded = NSString(string: noCieID.removingPercentEncoding!)
            
            let urlStringNoSpace = String.init(urlStringPercentDecoded).replacingOccurrences(of: " ", with: "_")
            let url: URL = URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]
                
            nextUrl = urlParameters[NEXT_URL]!
            name = urlParameters[NAME]!
            value = urlParameters[VALUE]!
            sourceApp = urlParameters[SOURCE_APP]!
                    
            //Rimuovo parametro /&sourceApp da challenge
            if let index = urlString.range(of: PARAM_TO_REMOVE)?.lowerBound {
                let substring = urlString[..<index]
                challenge = String(substring)
            }

            opText = urlParameters[OP_TEXT_M]!
            opText = opText.replacingOccurrences(of: "identita", with: "identità")
            opText = opText.replacingOccurrences(of: "_", with: " ")
                    
            //Parametro logo non è obbligatorio, se non esiste lo inizializzo a ""
            if(urlParameters[SP_LOGO] == nil){
                        
                opLogo = ""
                        
            }else{
                        
            opLogo = urlParameters[SP_LOGO]!
                        
                }
                
            }
        
        return (opText, opLogo, nextUrl, name, value, sourceApp, challenge)
        
    }
    
    //Metodo che verifica la corretta formattazione dell'URI App2App
    class func urlApp2AppIsValid(urlString: String)-> (Bool){

        if (urlString.count > 0){
              
            //Formatto stringa per farla accettare da URLType
            
            let noCieID = urlString.replacingOccurrences(of: URL_ULINK, with: "https://www.dominio.it/parametro?")
            let urlStringPercentDecoded = NSString(string: noCieID.removingPercentEncoding!)
            
            let urlStringNoSpace = String.init(urlStringPercentDecoded).replacingOccurrences(of: " ", with: "_")
            
            //Verifico se è un URL VALIDO
            if (URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a")) == nil){
                
                return false//Non è un URL valido

            }
            
            let url: URL = URL.init(string: urlStringNoSpace.replacingOccurrences(of: "à", with: "a"))!
            
            let urlParameters = url.parametersFromQueryString ?? ["":""]

            //Verifico che campi obbligatori esistono
            if(urlParameters[OP_TEXT_M] != nil && urlParameters[NAME] != nil && urlParameters[IMG_URL] != nil && urlParameters[VALUE] != nil && urlParameters[AUTHN_REQ] != nil && urlParameters[NEXT_URL] != nil && urlParameters[SOURCE_APP] != nil){
            
                //Verifico che campi obbligatori non sono vuoti
                if(urlParameters[OP_TEXT_M]!.count > 0 && urlParameters[NAME]!.count > 0 && urlParameters[IMG_URL]!.count > 0 && urlParameters[VALUE]!.count > 0 && urlParameters[AUTHN_REQ]!.count > 0 && urlParameters[NEXT_URL]!.count > 0 && urlParameters[SOURCE_APP]!.count > 0){
                
                    return true
                    
                }
                
            }
            
        }
        
        return false
        
    }
    
}
