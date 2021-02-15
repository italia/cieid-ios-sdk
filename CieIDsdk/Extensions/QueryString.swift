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
    
}
