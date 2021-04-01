//
//  Symbols.swift
//  DigiByte
//
//  Created by Yoshi Jäger on 25.05.20.
//  Copyright © 2020 DigiByte Foundation NZ Limited. All rights reserved.
//

import Foundation

enum Symbols {
    static let bits = "\u{018A}"
    static let btc = "\u{018A}"
    static let narrowSpace = " "
    static let lock = "\u{1F512}"
    static let redX = "\u{274C}"
    static func currencyButtonTitle(maxDigits: Int) -> String {
        switch maxDigits {
        case 2:
            return "dgBits\(Symbols.narrowSpace)(m\(Symbols.bits))"
        case 5:
            return "mDGB\(Symbols.narrowSpace)(m\(Symbols.bits))"
        case 8:
            return "DGB\(Symbols.narrowSpace)(\(Symbols.btc))"
        default:
            return "mDGB\(Symbols.narrowSpace)(m\(Symbols.bits))"
        }
    }
}
