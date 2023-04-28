//
//  CiedAuthDelegate.swift
//  DemoSDK
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation


protocol CiedAuthDelegate : class {
    func onSuccessAuth(with value: String)
    func onFailedAuth(with error: Error)
}
