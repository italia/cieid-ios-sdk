//
//  Token.swift
//  e-id
//
//

import Foundation
import CoreNFC

public struct ResponseAPDU {
    
    public var data : [UInt8]
    public var sw1 : UInt8
    public var sw2 : UInt8

    public init(data: [UInt8], sw1: UInt8, sw2: UInt8) {
        self.data = data
        self.sw1 = sw1
        self.sw2 = sw2
    }
}


@objc public class NFCToken : NSObject {
    
    
    var tag : NFCISO7816Tag
    
    @objc init( tag: NFCISO7816Tag) {
        self.tag = tag
    }

    @objc public func transmit(apdu: Data) -> Data
    {
        let cmd : NFCISO7816APDU = NFCISO7816APDU(data: apdu)!
        var responseAPDU : ResponseAPDU? = nil
        let semaphore = DispatchSemaphore(value: 0)
        var error : Error? = nil
        
        let concurrentQueue = DispatchQueue(label: "nfcthread", qos: .background, attributes: .concurrent)
        
        concurrentQueue.async {
            
//            print("async")
            
            self.send(cmd: cmd) { (respAPDU, err) in
                if(err == nil)
                {
                    responseAPDU = respAPDU!
                }
                else
                {
                    //print("error")
                    //print(error ?? "error")
                    error = err
                }
            
//                print("signal")
                semaphore.signal()
            }
        }
                
        if(responseAPDU == nil)
        {
//            print("wait")
            semaphore.wait()//timeout: .init(uptimeNanoseconds: 3000000))
        }

//        print("stop waiting")
        if(error == nil)
        {
            var response : Data = Data();
            
//            print("SW1SW2")
//            print(responseAPDU!.sw1)
//            print(responseAPDU!.sw2)
            
            response.append(contentsOf: responseAPDU!.data)
            response.append(responseAPDU!.sw1)
            response.append(responseAPDU!.sw2)

            return response
        }
        
        return Data();
    }
    
    func send( cmd: NFCISO7816APDU, completed: @escaping (ResponseAPDU?, Error?)->() ) {
                    
        tag.sendCommand(apdu: cmd) { (data, sw1, sw2, error) in
            if error == nil
            {
                let rep = ResponseAPDU(data: [UInt8](data), sw1: sw1, sw2: sw2)
                completed( rep, nil )
            }
            else
            {
                completed( nil, error)
            }
        }
    }
        
    
    @objc public static func decodeError( sw1sw2: UInt16) -> [String: String] {
                
        let sw1 : UInt8 = (UInt8)((sw1sw2 >> 8) & 0x00FF);
        let sw2 : UInt8 = (UInt8)((sw1sw2) & 0x00FF);
        
        return decodeError(sw1: sw1, sw2: sw2)
    }
        
    @objc public static func decodeHTTPError( err:UInt16 ) -> [String: String] {

        return ["errType":"","errorMsg":"HTTP Error \(err)"]
        //return "HTTP Error \(err)"
    }
    
    @objc public static func decodeError( sw1: UInt8, sw2:UInt8 ) -> [String: String] {

        //Dettaglio errore
        let errors : [UInt8 : [UInt8:String]] = [
            0x62: [0x00:"No information given",
                   0x81:"Part of returned data may be corrupted",
                   0x82:"End of file/record reached before reading Le bytes",
                   0x83:"Selected file invalidated",
                   0x84:"FCI not formatted according to ISO7816-4 section 5.1.5"],
            
            0x63: [0x00:"No information given",
                   0x81:"File filled up by the last write",
                   0x82:"Card Key not supported",
                   0x83:"Reader Key not supported",
                   0x84:"Plain transmission not supported",
                   0x85:"Secured Transmission not supported",
                   0x86:"Volatile memory not available",
                   0x87:"Non Volatile memory not available",
                   0x88:"Key number not valid",
                   0x89:"Key length is not correct",
                   0xC0:"LA CARTA E' BLOCCATA\nPer sbloccarla munisciti del codice PUK e utilizza l'apposita funzione in Gestione Carta",//ERRTYPE = CIE_MANAGER
                   0xC1:"Hai digitato un PIN ERRATO.\nHai un ultimo tentativo a disposizione",//ERRTYPE = RESET_AND_RETRY
                   0xC2:"Hai digitato un PIN ERRATO.\nHai ancora 2 tentativi"],//ERRTYPE = RESET_AND_RETRY
            0x65: [0x00:"No information given",
                   0x81:"Memory failure"],
            0x67: [0x00:"Wrong length"],
            0x68: [0x00:"No information given",
                   0x81:"Logical channel not supported",
                   0x82:"Secure messaging not supported"],
            0x69: [0x00:"No information given",
                   0x81:"Command incompatible with file structure",
                   0x82:"Security status not satisfied",
                   0x83:"LA CARTA E' BLOCCATA\nPer sbloccarla munisciti del codice PUK e utilizza l'apposita funzione in Gestione Carta",//ERRTYPE = CIE MANAGER
                   0x84:"Referenced data invalidated",
                   0x85:"Conditions of use not satisfied",
                   0x86:"Command not allowed (no current EF)",
                   0x87:"Expected SM data objects missing",
                   0x88:"SM data objects incorrect"],
            0x6A: [0x00:"No information given",
                   0x80:"Incorrect parameters in the data field",
                   0x81:"Function not supported",
                   0x82:"La smart card utilizzata non è una Carta di Identità Elettronica.\nL'operazione verrà annullata.",//File not found",//ERRTYPE = ABORT
                   0x83:"Record not found",
                   0x84:"Not enough memory space in the file",
                   0x85:"Lc inconsistent with TLV structure",
                   0x86:"Incorrect parameters P1-P2",
                   0x87:"Lc inconsistent with P1-P2",
                   0x88:"Referenced data not found"],
            0x6B: [0x00:"Wrong parameter(s) P1-P2]"],
            0x6D: [0x00:"Instruction code not supported or invalid"],
            0x6E: [0x00:"Class not supported"],
            0x6F: [0x00:"Errore sconosciuto"],
            0x90: [0x00:"Success"], //No further qualification
            0xFF: [0x01:"Il certificato di questa Carta di Identità Elettronica non è valido. L'operazione verrà annullata.",//ERRTYPE = ABORT
                   0x02:"Carta di Identità Elettronica già registrata. L'operazione verrà annullata.", //ERRTYPE = ABORT
                   0x03:"Carta di Identità Elettronica non registrata. Registra questa carta prima procedere.", //ERRTYPE = ABORT
                   0x04:"CIE non trovata.\nL'operazione verrà annullata.", //ERRTYPE = ABORT
                   0xC0:"LA CARTA E' BLOCCATA\nE' necessario richiederne la sostituzione", //ERRTYPE = SUPPORT
                   0xC1:"Hai digitato un PUK ERRATO.\nHai un ultimo tentativo a disposizione",//ERRTYPE = RESET_AND_RETRY
                   0xC2:"Hai digitato un PUK ERRATO.\nHai ancora 2 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC3:"Hai digitato un PUK ERRATO.\nHai ancora 3 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC4:"Hai digitato un PUK ERRATO.\nHai ancora 4 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC5:"Hai digitato un PUK ERRATO.\nHai ancora 5 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC6:"Hai digitato un PUK ERRATO.\nHai ancora 6 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC7:"Hai digitato un PUK ERRATO.\nHai ancora 7 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC8:"Hai digitato un PUK ERRATO.\nHai ancora 8 tentativi",//ERRTYPE = VAI_AL_COMUNE
                   0xC9:"Hai digitato un PUK ERRATO.\nHai ancora 9 tentativi",//ERRTYPE = RESET_AND_RETRY
                   0x83:"LA CARTA E' BLOCCATA\nE' necessario richiederne la sostituzione",//ERRTYPE = SUPPORT
                   0xFB:"Nuovo PIN e vecchio PIN non possono essere uguali. RIPETI L'OPERAZIONE",//ERRTYPE = RESET_AND_RETRY
                   0xFC:"I PIN non corrispondono",//ERRTYPE = RESET_AND_RETRY
                   0xFD:"Il PIN/PUK deve essere composto da 8 numeri",//ERRTYPE = RESET_AND_RETRY
                   0xFE:"Il nuovo PIN non deve avere cifre uguali o consecutive",//ERRTYPE = RESET_AND_RETRY
                   0xFF:"Hai rimosso la carta troppo presto\nRIPROVA"]//ERRTYPE = RETRY
        ]
        
        // Special cases - where sw2 isn't an error but contains a value
        if sw1 == 0x61 {
            return ["errType":"","errorMsg":"SW2 indicates the number of response bytes still available - (\(sw2) bytes still available)"]
            //return "SW2 indicates the number of response bytes still available - (\(sw2) bytes still available)"
        } else if sw1 == 0x64 {
            return ["errType":"","errorMsg":"State of non-volatile memory unchanged (SW2=00, other values are RFU)"]
            //return "State of non-volatile memory unchanged (SW2=00, other values are RFU)"
        } else if sw1 == 0x6C {
            return ["errType":"","errorMsg":"Wrong length Le: SW2 indicates the exact length - (exact length :\(sw2))"]
            //return "Wrong length Le: SW2 indicates the exact length - (exact length :\(sw2))"
        }

        //Gli errori previsti sono gestiti qui
        if let dict = errors[sw1], let errorMsg = dict[sw2] {
            
            return ["errorType": getErrorType(sw1: sw1, sw2: sw2), "errorMsg":errorMsg]
            //return errorMsg

        }
        
        return ["errType":"","errorMsg":"Unknown error - sw1: \(sw1), sw2: \(sw2)"]//"Unknown error - sw1: \(sw1), sw2: \(sw2)"
        
    }
    
    //Metodo che mi restituisce, in base al tipo di errore, ErrType: il tipo di comportamento da avere con le interfacce
    @objc static func getErrorType(sw1: UInt8, sw2:UInt8) -> String{
        
        //Uso questo enum per sapere come gestire l'errore
        enum errType: String {
            
            case Abort = "ABORT"// ABORT OPERAZIONE
            case AbortWithMessage = "ABORT_WITH_MESSAGE"// ABORT OPERAZIONE, mostra UIALertView
            case ConnectionLost = "CONNECTION_LOST"//Riprova con lo stesso pin inserito
            case ResetAndRetry = "RESET_AND_RETRY"//DEFAULT - Pulisci Pin View e riprova
            case VaiAlComune = "VAI_AL_COMUNE"//DEFAULT - Pulisci Pin View, mostra UIALertView e riprova
            case Support = "SUPPORT"//Mostra pagina assistenza
            case CieManager = "CIE_MANAGER"//Vai in gestione carta
            case Timeout = "TIMEOUT"//Come con connectionLost ma con messaggio dedicato
            case NoNetwork = "NO_NETWORK"//Come con connectionLost ma con messaggio dedicato
            case Biometric = "BIOMETRIC_ERROR"//Errore prodotto in KeychainHelper

        }
                
        switch sw1{
        case 0x63:
            
            switch sw2 {
            case 0xC0://PIN ERRATO - PUK NECESSARIO
                return errType.CieManager.rawValue
            case 0xC1://PIN ERRATO - UN TENTATIVO
                return errType.ResetAndRetry.rawValue
            case 0xC2://PIN ERRATO - DUE TENTATIVI
                return errType.ResetAndRetry.rawValue
            default:
                return ""
            }
            
        case 0x69:
            
            switch sw2 {
            case 0x83://CIE BLOCCATA - PUK NECESSARIO
                return errType.CieManager.rawValue
            default:
                return ""
            }
            
        case 0x6A:
            
            switch sw2 {
            case 0x82://IS NOT CIE
                return errType.Abort.rawValue
            default:
                return ""
            }
            
        case 0xFF:
            
            switch sw2 {
            case 0x01://CERT NOT VALID
                return errType.Abort.rawValue
            case 0x02://CIE GIA' REGISTRATA
                return errType.Abort.rawValue
            case 0x03://CIE NON REGISTRATA REGISTRATA
                return errType.Abort.rawValue
            case 0x04://CIE NON TROVATA
                return errType.Abort.rawValue
            case 0xC0://CIE BLOCCATA
                return errType.Support.rawValue
            case 0xC1://PUK ERRATO - 1 TENTATIVO
                return errType.VaiAlComune.rawValue
            case 0xC2://PUK ERRATO - 2 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC3://PUK ERRATO - 3 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC4://PUK ERRATO - 4 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC5://PUK ERRATO - 5 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC6://PUK ERRATO - 6 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC7://PUK ERRATO - 7 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC8://PUK ERRATO - 8 TENTATIVI
                return errType.VaiAlComune.rawValue
            case 0xC9://PUK ERRATO - 9 TENTATIVI
                return errType.ResetAndRetry.rawValue
            case 0x83://CIE BLOCCATA
                return errType.Support.rawValue
            case 0xFB://PIN VECCHIO E NUOVO UGUALI
                return errType.ResetAndRetry.rawValue
            case 0xFC://PIN NUOVO 1 e PIN NUOVO 2 DIVERSI
                return errType.ResetAndRetry.rawValue
            case 0xFD://PIN NON CONFORME/
                return errType.ResetAndRetry.rawValue
            case 0xFE://PIN NON CONFORME
                return errType.ResetAndRetry.rawValue
            case 0xFF://COMUNICAZIONE INTERROTTA
                return errType.ConnectionLost.rawValue
            default:
                return ""
            }
            
        default:
            
            return ""
            
        }
        
    }
    
}

