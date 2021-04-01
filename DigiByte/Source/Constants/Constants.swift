//
//  Constants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

let π: CGFloat = .pi

struct Padding {
    subscript(multiplier: Int) -> CGFloat {
        get {
            return CGFloat(multiplier) * 8.0
        }
    }
}

struct C {
    static let padding = Padding()
    struct Sizes {
        static let buttonHeight: CGFloat = 64.0
        static let headerHeight: CGFloat = 48.0
        static let footerHeight: CGFloat = 56.0
        static let largeHeaderHeight: CGFloat = 220.0
        static let logoAspectRatio: CGFloat = 125.0/417.0
        static let logoWidthPercentage: CGFloat = 0.7
    }
    static var defaultTintColor: UIColor = {
        return UIView().tintColor
    }()
    
    struct Colors {
        static let background = UIColor(red: 0x19/255, green: 0x1a / 255, blue: 0x2a / 255, alpha: 1.0) // #191a2a
        static let cellBackground = UIColor(red: 0x2f/255, green: 0x31 / 255, blue: 0x45 / 255, alpha: 1.0) // #1E2034
        static let text = UIColor.white
        static let lightText = UIColor(red: 109, green: 109, blue: 126, alpha: 1.0)
        static let cardBackground = UIColor(red: 0x2E / 255, green: 0x2E / 255, blue: 0x47 / 255, alpha: 1.0)
		static let lightGrey = UIColor(red: 0xaa / 255, green: 0xaa / 255, blue: 0xaa / 255, alpha: 1.0) // #9c9eb9
        static let blueGrey = UIColor(red: 0x9c / 255, green: 0x9e / 255, blue: 0x9b / 255, alpha: 1.0) // #9c9eb9
        static let greyBlue = UIColor(red: 0x66 / 255, green: 0x68 / 255, blue: 0x8f / 255, alpha: 1.0) // #66688f
        static let dark2 = UIColor(red: 0x19 / 255, green: 0x1a / 255, blue: 0x2a / 255, alpha: 1.0) // #191a2a
        static let dark3 = UIColor(red: 0x2e / 255, green: 0x2f / 255, blue: 0x47 / 255, alpha: 1.0) // #2e2f47
        static let blue = UIColor(red: 0x02 / 255, green: 0x5D / 255, blue: 0xBA / 255, alpha: 1.0) // #025DBA
        static let weirdGreen = UIColor(red: 63.0 / 255.0, green: 231.0 / 255.0, blue: 123.0 / 255.0, alpha: 1.0) //#3fe77b
		static let weirdRed = UIColor(red: 0xFF / 255, green: 0x74 / 255, blue: 0x16 / 255, alpha: 1)
        static let favoriteYellow = UIColor(red: 0xEA / 255, green: 0xD3 / 255, blue: 0x34 / 255, alpha: 1) // #EAD334
        static let separator = UIColor.white.withAlphaComponent(0.1)
    }
    
    static let animationDuration: TimeInterval = 0.3
    static let secondsInDay: TimeInterval = 86400
    static let maxMoney: UInt64 = 21000000*100000000
    static let satoshis: UInt64 = 100000000
    static let walletQueue = "io.digibyte.walletqueue"
    static let btcCurrencyCode = "DGB"
    static let null = "(null)"
    static let maxMemoLength = 250
    static let maxContactNameLength = 30
	//FIXME: We need a valid feedback email address.
    static let feedbackEmail = "info@digibyte.io"
	static let reviewLink = "https://itunes.apple.com/us/app/digibyte-wallet/id1328006562?action=write-review"
    static var standardPort: UInt16 {
		return E.isTestnet ? 12026 : 12024
    }
	//FIXME: Before shipping to production, change this to DigiByte.sqlite
	static let sqliteFileName = "DigiByte.sqlite"
    
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    static let applicationTitle = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "DigiByte"
}
