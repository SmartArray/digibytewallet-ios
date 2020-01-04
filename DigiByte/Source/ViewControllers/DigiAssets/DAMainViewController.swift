//
//  DAOnboardingViewController.swift
//  digibyte
//
//  Created by Yoshi Jaeger on 28.02.19.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

class DAMainViewController: UITabBarController {
    // MARK: Public properties
    
    // MARK: Private properties
    private let header = ModalHeaderView(title: "DigiAssets", style: ModalHeaderViewStyle.light)
    private let store: BRStore
    private let wallet: BRWallet
    private let walletManager: WalletManager
    private var tabs: [UIViewController]
    
    init(store: BRStore, walletManager: WalletManager) {
        self.store = store
        self.wallet = walletManager.wallet!
        self.walletManager = walletManager
        self.tabs = [
            DAAssetsRootViewController(store: store, wallet: wallet),
            DASendViewController(store: store, wallet: wallet, walletManager: walletManager),
//            DAReceiveViewController(store: store, wallet: wallet),
//            DACreateViewController(),
            DABurnViewController(store: store, wallet: wallet)
        ]
        super.init(nibName: nil, bundle: nil)
        
        addSubviews()
        addConstraints()
        setStyle()
        
        viewControllers = tabs
        tabBar.tintColor = UIColor(red: 38 / 255, green: 152 / 255, blue: 237 / 255, alpha: 1.0) //  38 152 237
        tabBar.barTintColor = UIColor(red: 35 / 255, green: 35 / 255, blue: 60 / 255, alpha: 1.0) //  35 35 60
        tabBar.isTranslucent = false
        
        if #available(iOS 10.0, *) {
            tabBar.unselectedItemTintColor = UIColor(red: 47 / 255, green: 49 / 255, blue: 80 / 255, alpha: 1.0) // 47 49 80
        } else {
            // what will we do below ios10 ?
        }
        
        header.close.tap = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        
        header.backgroundColor = UIColor.da.backgroundColor.withAlphaComponent(0.7)
    }
    
    private func addSubviews() {
        view.addSubview(header)
    }
    
    private func addConstraints() {
        header.constrain([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 96)
        ])
    }
    
    private func setStyle() {
        view.backgroundColor = UIColor.da.backgroundColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
