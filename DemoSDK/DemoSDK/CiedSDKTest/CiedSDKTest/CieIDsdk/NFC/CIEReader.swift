//
//  PassportReader.swift
//  NFCTest
//
//

import UIKit
import CoreNFC

private enum Op: Int {
    case SSLAuthentication
}

public class CIEReader : NSObject, NFCTagReaderSessionDelegate {
    
    public var nis : String?
    public var fullName : String?
    public var signature : Data?
    public var certificate : Data?
    public var name : String?
    public var surname : String?
    private var readerSession: NFCTagReaderSession?
    private var cieTag: NFCISO7816Tag?
    private var cieTagReader : CIETagReader?
    private var completedHandler: ((TagError?)->())!
    private var operation: Op = .SSLAuthentication
    var deepLinkInfo: DeepLinkInfo?
    private var pin : String?
    private var pin2 : String?
    private var url : String?
    public var data : Data?
    public var params : String?
        
    public var messageForUserOnNewPukRequest : String?//case .NewPUKFirstRequest
    public var newPUK : String?//case .NewPUKOTPRequest
    public var nun : String?
    public var mail : String?
    public var tel : String?
    public var procedureId : String?
    public var OTP : String?

    override public init( ) {
        super.init()
        
        cieTag = nil
        cieTagReader = nil
        nis = nil
        url = nil
        fullName = nil
        operation = .SSLAuthentication
    }
    
    private func start(completed: @escaping (TagError?)->() ) {
        self.completedHandler = completed
        
        guard NFCTagReaderSession.readingAvailable else {
            completedHandler( TagError(errorType: "ABORT", errorDescription: "Questo smartphone non supporta la lettura NFC", errorDetails: nil))
            return
        }
        
        //Log.debug( "authenticate" )
        
        if NFCTagReaderSession.readingAvailable {
            //Log.debug( "readingAvailable" )
            readerSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
            
            
            switch self.operation{
            case .SSLAuthentication:
                self.readerSession?.alertMessage = "Appoggia la carta sul retro, nella parte superiore dello smartphone, per effettuare l'autenticazione."
            }
            
            readerSession?.begin()
        }
    }
    
    
    public func post(url: String, pin: String, sourceApp: String?,deepLinkInfo: DeepLinkInfo?, completed: @escaping (TagError?)->() ) {
        self.operation = .SSLAuthentication
        self.pin = pin
        self.url = url
        self.deepLinkInfo = deepLinkInfo
        self.start(completed: completed)
    
    }
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        //Log.debug( "tagReaderSessionDidBecomeActive" )
    }
            
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        //Log.debug( "tagReaderSession:didInvalidateWithError - \(error)" )
        
        
        //print("ERRORE: \(error.localizedDescription)")
        //VIBRA PER SEGNALARE ERRORE LETTURA
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        
        if(self.readerSession != nil)
        {
            self.readerSession = nil
            
            if (error.localizedDescription == "Session timeout"){//TIMEOUT

                self.completedHandler( TagError(errorType: "TIMEOUT", errorDescription: "Lo smartphone non ha rilevato la presenza della carta. Assicurati di avvicinare la carta allo smartphone e di tenerla a contatto fino al termine dell'operazione.", errorDetails: nil))
                
            }else if (error.localizedDescription == "Session invalidated by user"){//ANNULLATO DA UTENTE

                self.completedHandler( TagError(errorType: "ABORT", errorDescription: "Operazione annullata dall'utente", errorDetails: nil))
                
            }else if (error.localizedDescription == "Session invalidated unexpectedly" || error.localizedDescription == "System resource unavailable"){//NON RIESCO AD ATTIVARE NFC

                self.completedHandler( TagError(errorType: "ABORT_WITH_MESSAGE", errorDescription: "L'app non riesce ad attivare il lettore NFC. Se il problema persiste prova a riavviare lo smartphone.", errorDetails: nil))
                
            }else{
                self.completedHandler( TagError(errorType: "RESET_AND_RETRY", errorDescription: error.localizedDescription, errorDetails: nil))
            }
        }
        
        self.readerSession = nil
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        //Log.debug( "tagReaderSession:didDetect - \(tags[0])" )
        
        if tags.count > 1 {
            session.invalidate(errorMessage: "E' consentita la lettura di una carta per volta")
            return
        }
        
        let tag = tags.first!
        
        switch tags.first! {
        case let .iso7816(tag):
            cieTag = tag
        default:
            session.invalidate(errorMessage: "La carta utilizzata non è una Carta di Identità Elettronica")
            return
        }
        
        // Connect to tag
        session.connect(to: tag) { [unowned self] (error: Error?) in
            
            if error != nil {
                
                //print(error?.localizedDescription)
                session.restartPolling()
                //Restart polling al posto di invalidate è una soluzione per carta non trovata
                //session.invalidate(errorMessage: "La comunicazione con la carta si è interrotta. Riprova.")
                return
                
            }
            
            //VIBRA PER SEGNALARE INIZIO LETTURA
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            
            switch self.operation{
            case .SSLAuthentication:
                self.readerSession?.alertMessage = "AUTENTICAZIONE IN CORSO...\nTieni ferma la carta fino al termine dell'operazione"
            }
            
            self.cieTagReader = CIETagReader(tag:self.cieTag!)
            self.startReading()
        }
    }

    @objc func startReading()
    {
        
        //ATR is not available on IOS
        // print("iso7816Tag historical bytes \(String(data: self.passportTag!.historicalBytes!, encoding: String.Encoding.utf8))")
        //
        // print("iso7816Tag identifier \(String(data: self.passportTag!.identifier, encoding: String.Encoding.utf8))")
        //
        
        switch operation {
        case .SSLAuthentication:
            self.handleReadSevice()
            break;           
        }
    }
    
    
    private func handleCertificate() {
        self.rimuoviCIEs()
        self.cieTagReader?.abbina(pin: CiedSDK.current.getPin(), completed: { (nis, certificate, name, surname, error) in
            
//            let  session = self.readerSession
//            self.readerSession = nil
            
            if(error == nil)
            {
                
                self.nis = nis
                self.certificate = certificate
                self.name = name
                self.surname = surname
                
//                session?.alertMessage = "REGISTRAZIONE CARTA TERMINATA CON SUCCESSO"
//                session?.invalidate()
                self.handlePost()
//                self.completedHandler(nil)
            }
            else
            {
                self.readerSession?.invalidate(errorMessage: error!.errorDescription)
                self.completedHandler(error)
            }
        })
    }
    
    func rimuoviCIEs(){
        
        if let nisarray = KeychainHelper.getRegisteredNIS()
            
        {
                
            let registeredNIS = NSMutableArray(array: nisarray)
            
            for nis in registeredNIS {
                
                //print("ELIMINO NIS:\(nis)")
                KeychainHelper.delete(nis: nis as! String)
                
            }
            
        }
        
    }
    
    private func handleReadSevice() {
        self.cieTagReader?.readIDServizi(completed: { nis, error in
//            let  session = self.readerSession
//            self.readerSession = nil
            
            if(error == nil){
                
////                session?.alertMessage = "LETTURA NIS EFFETTUATA CON SUCCESSO"
//                session?.invalidate()
                self.nis = nis
                self.handleCertificate()
//                self.completedHandler(nil)
                
            }else{

                self.readerSession?.invalidate(errorMessage: error!.errorDescription)
                self.completedHandler(error)
                
            }
        })
    }
    
    
    private func handlePost() {
        self.pin = CiedSDK.current.getPin()
        self.cieTagReader?.post(url: url!, pin: pin ?? "", deepLinkInfo: self.deepLinkInfo, completed: { (data, error) in
//            let  session = self.readerSession
//            self.readerSession = nil
            
            if(error == nil)
            {
                self.readerSession?.alertMessage = "AUTENTICAZIONE ESEGUITA CON SUCCESSO\nApertura del browser in corso..."
                self.readerSession?.invalidate()
                self.readerSession = nil
                self.data = data
                self.completedHandler(nil)
            }
            else
            {
                self.readerSession?.invalidate(errorMessage: error!.errorDescription)
                self.completedHandler(error)
            }
        })
    }
    
}
