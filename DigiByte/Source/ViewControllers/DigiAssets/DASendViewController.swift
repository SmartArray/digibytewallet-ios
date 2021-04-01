//
//  DASendViewController.swift
//  digibyte
//
//  Created by Yoshi Jaeger on 29.03.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

class DAPinView: DGBModalWindow {
    private let callback: VerifyPinCallback
    private let textDescription: String
    
    private var roadblock: Bool = false

    private var input: String = "" {
        didSet {
            refreshUI()
            
            let length = input.lengthOfBytes(using: .ascii)
            if length >= 6 {
                if !callback(input, self) {
                    // PIN attempt failed
                    roadblock = true
                    
                    pinView.shake()
                    DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) {
                        self.input = ""
                        self.hiddenNumberTextField.text = ""
                        self.roadblock = false
                    }
                }
            }
        }
    }
    
    private let pinView = PinView(style: .assets, length: 6)
    private let hiddenNumberTextField = UITextField()
    
    init(title: String, description: String, callback: @escaping VerifyPinCallback) {
        self.callback = callback
        self.textDescription = description
        super.init(title: title, padding: 8.0)
        
        hiddenNumberTextField.translatesAutoresizingMaskIntoConstraints = false
        hiddenNumberTextField.widthAnchor.constraint(equalToConstant: 0).isActive = true
        hiddenNumberTextField.heightAnchor.constraint(equalToConstant: 0).isActive = true
        hiddenNumberTextField.keyboardType = .numberPad
        hiddenNumberTextField.keyboardAppearance = .dark
        view.addSubview(hiddenNumberTextField)
        
        hiddenNumberTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        refreshUI()
    }
    
    private func refreshUI() {
        stackView.arrangedSubviews.forEach { v in
            stackView.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        
        stackView.spacing = 8
        
        let descriptionLabel = UILabel(font: UIFont.da.customBody(size: 14))
        descriptionLabel.text = textDescription
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.textAlignment = .center
        
        pinView.fill(input.count)
        pinView.translatesAutoresizingMaskIntoConstraints = false
        pinView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(pinView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        hiddenNumberTextField.becomeFirstResponder()
    }
    
    @objc private func textFieldDidChange() {
        guard !roadblock else { return }
        guard let text = hiddenNumberTextField.text else { return }
        input = text
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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

fileprivate class AmountButton: DAButton {
    private let callback: () -> Void
    
    init(title: String, callback: @escaping () -> Void) {
        self.callback = callback
        super.init(title: title, backgroundColor: UIColor(red: 67 / 255, green: 68 / 255, blue: 90 / 255, alpha: 1.0), height: 72, radius: 6)
        
        self.touchUpInside = { [weak self] in
            self?.callback()
        }
        
        label.font = UIFont.da.customBold(size: 14)
        label.textColor = UIColor.white
        
        widthAnchor.constraint(equalToConstant: 80).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DASendViewController: UIViewController {
    private var hc: NSLayoutConstraint? = nil
    
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    
    let header = UILabel(font: UIFont.da.customBold(size: 20), color: .white)
    let assetDropdown = DADropDown()
    let totalBalanceLabel = UILabel(font: UIFont.da.customMedium(size: 13), color: UIColor.da.secondaryGrey)
    let receiverAddressBox = DATextBox(showClearButton: true, showPasteButton: true)
    let receiverNameLabel = UILabel(font: UIFont.da.customMedium(size: 13), color: UIColor.da.secondaryGrey)
    let amountBox = DATextBox(showClearButton: true, mode: .numbersOnly)
    let amountButtonStackView = UIStackView()
    let sendButton = DAButton(title: S.Assets.sendAssets.uppercased(), backgroundColor: UIColor.da.darkSkyBlue, height: 40)
    
    private let store: BRStore
    private let wallet: BRWallet
    private let walletManager: WalletManager
    private let assetSender: AssetSender!
    
    private var indexedContacts: [String: AddressBookContact] = [:]
    
    var selectedModel: AssetModel? = nil {
        didSet {
            modelSelected()
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        UIPasteboard.general.string = assetSender.debug // YOSHI, remove before RELEASE
    }
    
    init(store: BRStore, walletManager: WalletManager) {
        self.store = store
        self.wallet = wallet
        self.walletManager = walletManager
        assetSender = AssetSender(walletManager: walletManager, store: store)
        
        super.init(nibName: nil, bundle: nil)
        
        tabBarItem = UITabBarItem(title: S.Assets.tabSend, image: UIImage(named: "da-send")?.withRenderingMode(.alwaysTemplate), tag: 0)
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        scrollView.alwaysBounceVertical = true
        
        stackView.spacing = 9
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.axis = .vertical
        
        amountButtonStackView.spacing = 8
        amountButtonStackView.alignment = .fill
        amountButtonStackView.distribution = .fill
        amountButtonStackView.axis = .horizontal
        
        header.text = S.Assets.sendAssets
        header.textAlignment = .left
        
        totalBalanceLabel.text = " "
        totalBalanceLabel.textAlignment = .left
        totalBalanceLabel.textColor = UIColor(red: 248 / 255, green: 156 / 255, blue: 78 / 255, alpha: 1.0) // 248 156 78
        
        receiverNameLabel.text = " "
        receiverNameLabel.textAlignment = .left
        receiverNameLabel.textColor = UIColor(red: 248 / 255, green: 156 / 255, blue: 78 / 255, alpha: 1.0) // 248 156 78
        
        sendButton.label.font = UIFont.da.customBold(size: 14)
        sendButton.leftImage = UIImage(named: "da-glyph-send")
        
        amountButtonStackView.addArrangedSubview(createVerticalSpacingView(32))
        amountButtonStackView.addArrangedSubview(AmountButton(title: "1", callback: { [weak self] in
            self?.setBalance(constant: 1)
            self?.toggleSendButton()
        }))
        amountButtonStackView.addArrangedSubview(AmountButton(title: "50%", callback: { [weak self] in
            self?.setBalance(multiplier: 0.5)
            self?.toggleSendButton()
        }))
        amountButtonStackView.addArrangedSubview(AmountButton(title: S.Send.max, callback: { [weak self] in
            self?.setBalance(multiplier: 1.0)
            self?.toggleSendButton()
        }))
        
        assetDropdown.setContent(asset: nil)
        
        stackView.addArrangedSubview(header)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(assetDropdown)
        stackView.addArrangedSubview(totalBalanceLabel)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(receiverAddressBox)
        stackView.addArrangedSubview(receiverNameLabel)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(amountBox)
        stackView.addArrangedSubview(amountButtonStackView)
        
        stackView.addArrangedSubview(UIView())
        
        stackView.addArrangedSubview(horizontalPadding(for: sendButton, 40))
        
        receiverAddressBox.placeholder = S.Receive.receiveAddress
        amountBox.placeholder = S.TransactionDetails.amountHeader
        
        addConstraints()
        addEvents()
        
        configureReceiverAddressBox()
        indexContacts()
        
        modelSelected()
    }
    
    private func indexContacts() {
        indexedContacts = [:]
        
        let contacts = AddressBookContact.loadContacts()
        for contact in contacts {
            indexedContacts[contact.address] = contact
        }
    }
    
    private func configureReceiverAddressBox() {
        receiverAddressBox.clipboardButton.setImage(UIImage(named: "more")?.withRenderingMode(.alwaysTemplate), for: .normal)
        receiverAddressBox.clipboardButtonTapped = { [weak self] in
            // Show modal window (gallery, image, scanner)
            let modalWindow = DGBModalMediaOptions { (address) in
                self?.receiverAddressBox.textBox.text = address
                self?.toggleSendButton()
                self?.indexContacts()
                self?.updateReceiverName(address)
            }
            
            self?.present(modalWindow, animated: true, completion: nil)
        }
        receiverAddressBox.textChanged = { [weak self] text in
            self?.updateReceiverName(text)
        }
    }
    
    private func updateReceiverName(_ text: String) {
        guard let contact = indexedContacts[text] else {
            receiverNameLabel.text = " "
            return
        }
        
        receiverNameLabel.text = contact.name
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
    
    private func setBalance(multiplier: Double = 0.0, constant: Int = 0) {
        guard let selectedModel = self.selectedModel else { return }
        var balance = AssetHelper.allBalances[selectedModel.assetId] ?? 0
        let b = balance
        
        balance = AssetHelper.AssetBalance(multiplier * Double(balance))
        balance += AssetHelper.AssetBalance(constant)
        
        balance = min(balance, b)
        
        amountBox.textBox.text = "\(balance)"
    }
    
    private func toggleSendButton() {
        var enabled: Bool = false
        
        enabled =
            selectedModel != nil &&
            amountBox.textBox.text != nil &&
            amountBox.textBox.text! != "" &&
            receiverAddressBox.textBox.text != nil &&
            receiverAddressBox.textBox.text! != ""
        
        if enabled {
            sendButton.alpha = 1.0
            sendButton.isEnabled = true
        } else {
            sendButton.alpha = 0.3
            sendButton.isEnabled = false
        }
    }
    
    private func modelSelected() {
        assetDropdown.setContent(asset: selectedModel)
        
        guard let assetModel = selectedModel else {
            toggleSendButton()
            return
        }
        
        // Update total balance
        let balance = AssetHelper.allBalances[assetModel.assetId] ?? 0
        totalBalanceLabel.text = "\(S.Assets.totalBalance): \(balance)"
        
        amountBox.textBox.text = ""
        
        toggleSendButton()
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
                self?.toggleSendButton()
            }
        }
        
        receiverAddressBox.textChanged = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.toggleSendButton()
            }
        }
        
        sendButton.touchUpInside = { [weak self] in
            guard let selectedModel = self?.selectedModel else { return }
            
            guard let balance = AssetHelper.allBalances[selectedModel.assetId] else {
                self?.showError(with: S.Assets.AssetNotAvailable)
                return
            }
            
            guard let address = self?.receiverAddressBox.textBox.text, address != "", address.isValidAddress else {
                self?.showError(with: S.Send.invalidAddressTitle)
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
        
            guard
                let assetSender = self?.assetSender,
                assetSender.createTransaction(assetModel: selectedModel, amount: amount, to: address) else {
                    self?.showError(with: "\(S.Send.createTransactionError) (\(self!.assetSender.errorCode ?? -1))")
                return;
            }
            
            guard let rate = self!.store.state.currentRate else { return }
            guard let feePerKb = self!.walletManager.wallet?.feePerKb else { return }
            
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
                            AssetHelper.createTemporaryAssetModel(for: txid, mode: .send, assetModel: selectedModel, amount: amount, to: address)
                        }
                        
                        self?.showSuccess(with: S.Assets.AssetsSent)
                        self?.dismiss(animated: true)
                        
                    case .creationError(let message, let code):
                        self?.showError(with: String.init(format: S.Assets.couldNotBeCreated, message, code ?? -1))
                        
                    case .publishFailure(let error):
                        self?.showError(with: String.init(format: S.Assets.couldNotBeBroadcasted, error.localizedDescription))
                    }
            })
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
        tabBarController?.tabBar.tintColor = UIColor(red: 38 / 255, green: 152 / 255, blue: 237 / 255, alpha: 1.0)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
