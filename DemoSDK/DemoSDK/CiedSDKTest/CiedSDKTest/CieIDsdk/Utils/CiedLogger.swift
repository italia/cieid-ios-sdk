//
//  CiedLogger.swift
//  DemoSDK
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation

class CiedLogger {
    var isEnableLogger : Bool = false
    final func dubugLog(with messagge: String) {
        if isEnableLogger {
            print("[CIED LOGGER]: " + messagge)
        }
    }
}
