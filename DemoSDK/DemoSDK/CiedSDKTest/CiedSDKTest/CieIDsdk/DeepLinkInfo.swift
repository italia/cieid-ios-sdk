//
//  DeepLinkInfo.swift
//  CiedSDKTest
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation


public class DeepLinkInfo {
    var nextUrl : String?
    var value : String?
    var name : String?
    var authReq: String?
    init(with url: String) {
        guard let url = URL(string: url) else { return }
        //PROD
        let baseURL = "https://ios.idserver.servizicie.interno.gov.it/"
        //PREPROD
        //let baseURL = "https://ios.preproduzione.idserver.servizicie.interno.gov.it/"
        let noCieID = url.absoluteString.replacingOccurrences(of: baseURL, with: "https://www.dominio.it/parametro?")
        let urlNext = URL(string: noCieID)
        self.value = urlNext?.queryParameters[Constants.KEY_VALUE] ?? ""
        self.name = urlNext?.queryParameters[Constants.KEY_NAME] ?? ""
        self.nextUrl = urlNext?.queryParameters[Constants.KEY_NEXT_UTL] ?? ""
        self.authReq = urlNext?.queryParameters[Constants.KEY_AUTHN_REQUEST_STRING] ?? ""
    }
    
}
