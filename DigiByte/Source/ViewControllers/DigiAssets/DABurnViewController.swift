//
//  DABurnViewController.swift
//  digibyte
//
//  Created by Yoshi Jaeger on 29.03.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

fileprivate let qrBorder: CGFloat = 200
fileprivate let qrBorderSize: CGFloat = 16
fileprivate let qrSize: CGFloat = qrBorder - qrBorderSize * 2

fileprivate func createVerticalSpacingView(_ height: CGFloat = 16) -> UIView {
    let v = UIView()
    
    v.heightAnchor.constraint(equalToConstant: height).isActive = true
    v.backgroundColor = .clear
    
    return v
}

fileprivate func horizontalPadding(for element: UIView, _ padding: CGFloat) -> UIView {
    let v = UIView()
    
    v.addSubview(element)
    element.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: padding, bottom: 0, right: -padding))
    
    return v
}

fileprivate func pad(_ pad: CGFloat, _ view: UIView) -> UIView {
    let v = UIView()
    
    v.addSubview(view)
    
    v.heightAnchor.constraint(equalToConstant: qrBorder).isActive = true
    v.widthAnchor.constraint(equalToConstant: qrBorder).isActive = true
    
    view.constrain([
        view.centerXAnchor.constraint(equalTo: v.centerXAnchor),
        view.centerYAnchor.constraint(equalTo: v.centerYAnchor),
    ])
    
    return v
}

class DABurnViewController: UIViewController {
    private var hc: NSLayoutConstraint? = nil
    private let store: BRStore
    private let wallet: BRWallet
    private let walletManager: WalletManager
    private let assetSender: AssetSender!
    
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    
    let header = UILabel(font: UIFont.da.customBold(size: 20), color: .white)
    let dangerBox = UIView()
    let dangerLabel = UILabel(font: UIFont.da.customBold(size: 18), color: UIColor.da.burnColor)
    let dangerDescriptionLabel = UILabel(font: UIFont.da.customBold(size: 14), color: .white)
    let dangerImageView = UIImageView()
    
    let assetDropdown = DADropDown()
    let totalBalanceLabel = UILabel(font: UIFont.da.customMedium(size: 13), color: UIColor.da.secondaryGrey)
    let amountBox = DATextBox(showClearButton: true, mode: .numbersOnly)
    let burnButton = DAButton(title: S.Assets.burnAssets.uppercased(), backgroundColor: UIColor.da.burnColor, height: 40)
    
    var selectedModel: AssetModel? = nil {
        didSet {
            modelSelected()
        }
    }
    
    init(store: BRStore, walletManager: WalletManager) {
        self.store = store
        self.wallet = wallet
        self.walletManager = walletManager
        self.assetSender = AssetSender(walletManager: walletManager, store: store)
        super.init(nibName: nil, bundle: nil)
        
        tabBarItem = UITabBarItem(title: S.Assets.tabBurn, image: UIImage(named: "da-burn")?.withRenderingMode(.alwaysTemplate), tag: 0)
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        scrollView.alwaysBounceVertical = true
        
        stackView.spacing = 9
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.axis = .vertical
        
        header.text = S.Assets.burnAssets
        header.textAlignment = .left
        
        totalBalanceLabel.text = " "
        totalBalanceLabel.textAlignment = .left
    
        assetDropdown.setContent(asset: nil)
        
        dangerBox.layer.borderWidth = 6
        dangerBox.layer.borderColor = UIColor.da.burnColor.cgColor
        dangerBox.layer.cornerRadius = 6
        dangerBox.layer.masksToBounds = true
        dangerBox.addSubview(dangerImageView)
        dangerBox.addSubview(dangerLabel)
        dangerBox.addSubview(dangerDescriptionLabel)
        
        dangerImageView.image = UIImage(named: "da-warning")
        dangerImageView.contentMode = .scaleAspectFit
        
        dangerLabel.textAlignment = .center
        dangerLabel.lineBreakMode = .byWordWrapping
        dangerLabel.text = S.Assets.dangerTitle
        
        dangerDescriptionLabel.textAlignment = .center
        dangerDescriptionLabel.lineBreakMode = .byWordWrapping
        dangerDescriptionLabel.text = S.Assets.dangerText
        dangerDescriptionLabel.numberOfLines = 0
        
        dangerImageView.constrain([
            dangerImageView.topAnchor.constraint(equalTo: dangerBox.topAnchor, constant: 32),
            dangerImageView.centerXAnchor.constraint(equalTo: dangerBox.centerXAnchor),
        ])
        
        dangerLabel.constrain([
            dangerLabel.topAnchor.constraint(equalTo: dangerImageView.bottomAnchor, constant: 8),
            dangerLabel.leadingAnchor.constraint(equalTo: dangerBox.leadingAnchor, constant: 16),
            dangerLabel.trailingAnchor.constraint(equalTo: dangerBox.trailingAnchor, constant: -16),
        ])
        
        dangerDescriptionLabel.constrain([
            dangerDescriptionLabel.topAnchor.constraint(equalTo: dangerLabel.bottomAnchor, constant: 16),
            dangerDescriptionLabel.leadingAnchor.constraint(equalTo: dangerBox.leadingAnchor, constant: 4),
            dangerDescriptionLabel.trailingAnchor.constraint(equalTo: dangerBox.trailingAnchor, constant: -4),
            dangerDescriptionLabel.bottomAnchor.constraint(equalTo: dangerBox.bottomAnchor, constant: -32),
        ])
        
        burnButton.label.font = UIFont.da.customBold(size: 14)
        burnButton.leftImage = UIImage(named: "da-glyph-burn")
        
        stackView.addArrangedSubview(header)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(dangerBox)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(assetDropdown)
        stackView.addArrangedSubview(totalBalanceLabel)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(amountBox)
    
        stackView.addArrangedSubview(UIView())
        
        stackView.addArrangedSubview(horizontalPadding(for: burnButton, 40))
        
        amountBox.placeholder = S.Send.amountLabel
        amountBox.textBox.text = ""
        
        addConstraints()
        addEvents()
        
        modelSelected()
    }
    
    @objc
    private func keyboardWillShow(notification: NSNotification) {
        let userInfo = notification.userInfo!
        var keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        if let hc = hc {
            hc.isActive = false
            self.hc = nil
        }
        
        hc = stackView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -keyboardFrame.height - 20)
        hc?.isActive = true

        var contentInset: UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = 80
        scrollView.contentInset = contentInset
    }
    
    @objc
    private func keyboardWillHide(notification: NSNotification) {
        let contentInset: UIEdgeInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
        if let hc = hc {
            hc.isActive = false
            self.hc = nil
        }
    }
    
    @objc private func assetDropdownTapped() {
        let assetSelector = DAModalAssetSelector()
        assetSelector.callback = { [weak self] asset in
            self?.selectedModel = asset
        }
        self.present(assetSelector, animated: true, completion: {
            assetSelector.tableView.reloadData()
        })
    }
    
    private func modelSelected() {
        assetDropdown.setContent(asset: selectedModel)
        
        guard let assetModel = selectedModel else {
            amountBox.isUserInteractionEnabled = false
            return
        }
        
        // Update total balance
        let balance = AssetHelper.allBalances[assetModel.assetId] ?? 0
        totalBalanceLabel.text = "\(S.Assets.totalBalance): \(balance)"
        totalBalanceLabel.textColor = UIColor(red: 248 / 255, green: 156 / 255, blue: 78 / 255, alpha: 1.0) // 248 156 78
        
        amountBox.isUserInteractionEnabled = true
    }
    
    private func presentVerifyPin(_ str: String, callback: @escaping VerifyPinCallback) {
        let wnd = DAPinView(title: S.VerifyPin.authorize, description: str, callback: callback)
        present(wnd, animated: true, completion: nil)
    }
    
    private func addEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name:UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name:UIResponder.keyboardWillHideNotification, object: nil)
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(assetDropdownTapped))
        assetDropdown.isUserInteractionEnabled = true
        assetDropdown.addGestureRecognizer(gr)
        
        amountBox.textChanged = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.toggleBurnButton()
            }
        }
        
        burnButton.touchUpInside = { [weak self] in
            guard let selectedModel = self?.selectedModel else { return }
            
            guard let balance = AssetHelper.allBalances[selectedModel.assetId] else {
                self?.showError(with: S.Assets.AssetNotAvailable)
                return
            }
            
            guard
                let amountStr = self?.amountBox.textBox.text,
                amountStr != "",
                let amount = Int(amountStr) else {
                    self?.showError(with: S.Send.noAmount)
                    return
            }
                
            if balance < Int(amount) {
                self?.showError(with: S.Assets.NotEnoughAssets)
                return
            }
            
            guard let rate = self!.store.state.currentRate else { return }
            guard let feePerKb = self!.walletManager.wallet?.feePerKb else { return }
            
            guard
                let assetSender = self?.assetSender,
                assetSender.createBurnTransaction(assetModel: selectedModel, amount: amount) else {
                    self?.showError(with: "\(S.Send.createTransactionError) (\(self!.assetSender.errorCode ?? -1))")
                return;
            }
            
            assetSender.send(biometricsMessage: S.VerifyPin.touchIdMessage,
                        rate: rate,
                        feePerKb: feePerKb,
                        verifyPinFunction: { [weak self] pinValidationCallback in
                            self?.presentVerifyPin(S.VerifyPin.authorize) { [weak self] pin, vc in
                                if pinValidationCallback(pin) {
                                    vc.dismiss(animated: true, completion: {
                                        self?.parent?.view.isFrameChangeBlocked = false
                                    })
                                    return true
                                } else {
                                    return false
                                }
                            }
                }, completion: { [weak self] result in
                    switch result {
                    case .success:
                        if let txid = assetSender.transaction?.txHash.description {
                            AssetHelper.createTemporaryAssetModel(for: txid, mode: .send, assetModel: selectedModel, amount: amount, to: "")
                        }
                        
                        self?.showSuccess(with: S.Assets.AssetsBurned)
                        self?.dismiss(animated: true)
                        
                    case .creationError(let message, let code):
                        self?.showError(with: String.init(format: S.Assets.couldNotBeCreated, message, code ?? -1))
                        
                    case .publishFailure(let error):
                        self?.showError(with: String.init(format: S.Assets.couldNotBeBroadcasted, error.localizedDescription))
                    }
            })
        }

    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        UIPasteboard.general.string = assetSender.debug // YOSHI, remove before RELEASE
    }
    
    private func toggleBurnButton() {
        var enabled: Bool = false
        
        enabled =
            selectedModel != nil &&
            amountBox.textBox.text != nil &&
            amountBox.textBox.text! != ""
        
        if enabled {
            burnButton.alpha = 1.0
            burnButton.isEnabled = true
        } else {
            burnButton.alpha = 0.3
            burnButton.isEnabled = false
        }
    }
    
    private func addConstraints() {
        let padding: CGFloat = 30
        
        scrollView.constrain(toSuperviewEdges: nil)
        stackView.constrain(toSuperviewEdges: UIEdgeInsets(top: 90, left: padding, bottom: -50, right: -padding))
        
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 1.0, constant: -2 * padding).isActive = true
        
        let hC = stackView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.8)
        hC.priority = .defaultLow
        hC.isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tabBarController?.tabBar.tintColor = UIColor.da.burnColor
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

