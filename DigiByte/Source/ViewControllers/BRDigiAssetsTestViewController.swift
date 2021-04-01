//
//  BRDigiAssetsTestViewController.swift
//  digibyte
//
//  Created by Yoshi Jäger on 08.11.18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

class BRDigiAssetsTestViewController: UIViewController {
    
    private let segmentedButton = UISegmentedControl(items: ["Hex", "Base64"])
    private let textView = UITextView()
    private let signButton = UIButton()
    private let retView = UITextView()
    
    private let closeButton = UIButton()
    
    private let wallet: WalletManager

    init(wallet: WalletManager) {
        self.wallet = wallet
        super.init(nibName: nil, bundle: nil)
        
        view.backgroundColor = C.Colors.background
        
        view.addSubview(segmentedButton)
        view.addSubview(textView)
        view.addSubview(signButton)
        view.addSubview(retView)
        view.addSubview(closeButton)
        
        segmentedButton.constrain([
            segmentedButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 90),
            segmentedButton.leftAnchor.constraint(equalTo: view.leftAnchor),
            segmentedButton.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        
        textView.constrain([
            textView.topAnchor.constraint(equalTo: segmentedButton.bottomAnchor, constant: 15),
            textView.leftAnchor.constraint(equalTo: view.leftAnchor),
            textView.rightAnchor.constraint(equalTo: view.rightAnchor),
            textView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        signButton.constrain([
            signButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 15),
            signButton.leftAnchor.constraint(equalTo: view.leftAnchor),
            signButton.rightAnchor.constraint(equalTo: view.rightAnchor),
            signButton.heightAnchor.constraint(equalToConstant: 45),
        ])
        
        retView.constrain([
            retView.topAnchor.constraint(equalTo: signButton.bottomAnchor, constant: 15),
            retView.leftAnchor.constraint(equalTo: view.leftAnchor),
            retView.rightAnchor.constraint(equalTo: view.rightAnchor),
            retView.heightAnchor.constraint(equalToConstant: 150),
        ])
        
        closeButton.constrain([
            closeButton.bottomAnchor.constraint(equalTo: segmentedButton.topAnchor, constant: -20),
            closeButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 150),
            closeButton.heightAnchor.constraint(equalToConstant: 25),
        ])
        
        retView.isScrollEnabled = false
        textView.isScrollEnabled = false
        
        retView.backgroundColor = .clear
        textView.backgroundColor = .clear
        
        retView.textColor = UIColor.white
        textView.textColor = UIColor.white
        
        retView.isEditable = false
        
        signButton.backgroundColor = UIColor.blue
        signButton.setTitle("Sign transaction", for: .normal)
        signButton.setTitleColor(UIColor.white, for: .normal)
        
        closeButton.backgroundColor = UIColor.blue
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(UIColor.white, for: .normal)
        
        signButton.addTarget(self, action: #selector(signButtonTapped), for: .touchUpInside)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        segmentedButton.selectedSegmentIndex = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }
    
    @objc private func signButtonTapped() {
        view.endEditing(true)
        
        guard let data = textView.text, data.count > 0 else { return }
        var signed: String? = nil
        
        if segmentedButton.selectedSegmentIndex == 0 {
            // hex
            signed = wallet.signSerializedTransaction(hex: data)
        } else {
            // base64
            signed = wallet.signSerializedTransaction(base64: data)
        }
        
        // check return value
        guard signed != nil else {
            let alert = AlertController(title: S.Alert.error, message: S.Import.Error.signing, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(AlertAction(title: S.Alerts.defaultConfirmOkCaption, style: UIAlertAction.Style.default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // show the signed tx
        retView.text = signed!
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

