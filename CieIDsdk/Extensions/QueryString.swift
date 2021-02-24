//
//  QueryString.swift
//  sptester
//
//  Created by Eros Brienza on 15/01/21.
//

import Foundation

extension URL {
    
    public var parametersFromQueryString : [String: String]? {
        
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
    
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            
            result[item.name] = item.value
            
        }
        
    }
    
    public var appendSourceAppParameter : URL?{

        //Check if SP_URL key exists in info.plist
        let SP_URL_SCHEME_KEY : String = "SP_URL_SCHEME"
        if let urlSchemeString : String = Bundle.main.infoDictionary?[SP_URL_SCHEME_KEY] as? String{
            
            let SOURCE_APP : String = "sourceApp"
            return self.appendingPathComponent("&\(SOURCE_APP)=\(urlSchemeString)", isDirectory: false)
            
        }else{
            
            return nil
            
        }
        
    }
    
    public var addAppDomainPrefix : URL?{
    
        let APP_DOMAIN : String = "CIEID://"
        let finalURL = URL.init(string: "\(APP_DOMAIN)\(self.absoluteString)")
        return finalURL
            
    }
    
}
