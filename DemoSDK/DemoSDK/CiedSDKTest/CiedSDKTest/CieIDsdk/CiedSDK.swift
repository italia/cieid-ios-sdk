//
//  CiedSDK.swift
//  DemoSDK
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation
import UIKit
typealias CiedView = CiedAuthDelegate & UIViewController
class CiedSDK {
    static var current = CiedSDK()
    var view: CiedView?
    private var logger: CiedLogger = CiedLogger()
    private var urlService: String = ""
    private var pin: String = ""
    var deepLinkInfo: DeepLinkInfo?
    let callerApp = ""
    func start(with view: CiedView, loggedEnable: Bool = false) {
        self.view = view
        self.logger.isEnableLogger = loggedEnable
    }
    
    final func setURL(url: String) {
        self.urlService = url
        self.deepLinkInfo = DeepLinkInfo(with: url)
       
    }
    
    final func getPin() -> String {
        return self.pin
    }
    
    final func setPin(pin: String, completion: ((Bool) -> Void) = { _ in } ) {
        let regex = try! NSRegularExpression(pattern: "^[0-9]{8}$",
                                             options: [.caseInsensitive])
        let value =  regex.firstMatch(in: pin, options:[],
                                      range: NSMakeRange(0, pin.count)) != nil
        if value {
            self.pin = pin
        }
        completion(value)
    }
    
    final func authenticate(completion: @escaping((Bool, String?) -> Void)) {
        let reader = CIEReader()
        reader.post(url: self.urlService, pin: self.pin, sourceApp: nil, deepLinkInfo: self.deepLinkInfo) { error in
            guard error == nil else {
                self.logger.dubugLog(with: error?.localizedDescription ?? "Errore Generico")
                completion(false,error?.localizedDescription)
                return
            }
            self.logger.dubugLog(with: "OnSuccess")
            let response = reader.data! as Data
            let responseString = String(decoding: response, as: UTF8.self)
            let serverCode = responseString.replacingOccurrences(of: "codice:", with: "")
            let nextURL: String = self.deepLinkInfo?.nextUrl ?? ""
            guard let name = self.deepLinkInfo?.name, let value = self.deepLinkInfo?.value else { completion(false,nil); return }
            let url = nextURL + "?" + name + "=" + value + "&login=1&codice=" + serverCode
            completion(true,url)
        }
    }
}

