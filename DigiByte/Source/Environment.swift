//
//  Environment.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

struct E {
    static let isTestnet: Bool = {
        // ProcessInfo.processInfo.environment
        #if Testnet
            print("TESTNET=1 !")
            return true
        #else
            let testnet = ProcessInfo.processInfo.environment["TESTNET"]
            print("TESTNET=\(testnet ?? "0")")
            return testnet == "1"
        #endif
    }()
    static let isTestFlight: Bool = {
        #if Testflight
            return true
        #else
            return false
        #endif
    }()
    static let isSimulator: Bool = {
        #if arch(i386) || arch(x86_64)
            return true
        #else
            return false
        #endif
    }()
    static let isDebug: Bool = {
        #if Debug
            return true
        #else
            return false
        #endif
    }()
    static let isScreenshots: Bool = {
        #if Screenshots
            return true
        #else
            return false
        #endif
    }()
    static var is320wDevice: Bool {
        return UIScreen.main.bounds.width == 320.0
    }
    static var isIPhone4: Bool {
        return UIApplication.shared.keyWindow?.bounds.height == 480.0
    }
    static var isIPhone5: Bool {
        return (UIApplication.shared.keyWindow?.bounds.height == 568.0) && (E.is32Bit)
    }
    static let isIPhoneX: Bool = {
        return (UIScreen.main.bounds.size.height == 812.0)
    }()
    static let isIphoneXsMax: Bool = {
        return (UIScreen.main.bounds.size.height == 896.0)
    }()
    static let is32Bit: Bool = {
        return MemoryLayout<Int>.size == MemoryLayout<UInt32>.size
    }()
    
    static let isIPhoneXOrGreater: Bool = {
        return E.isIPhoneX || E.isIphoneXsMax
    }()
    
    static let scaleFactor: CGFloat = {
        switch UIScreen.main.scale {
            case 2:
                return 1.35
            case 3:
                return 1.5
            default:
                return 1
        }
    }()
}
