//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCore

typealias PresentScan = ((@escaping ScanCompletion) -> Void)

private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)

class SendViewController : UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, Subscriber, ModalPresentable, Trackable {

    //MARK - Public
    var presentScan: PresentScan?
    var presentVerifyPin: ((String, @escaping VerifyPinCallback)->Void)?
    var onPublishSuccess: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String? {
        didSet {
            if initialAddress != nil {
                addressCell.hideButtons()
            } else {
                addressCell.showButtons()
            }
        }
    }
    var isPresentedFromLock = false
    
    init(store: BRStore, sender: Sender, walletManager: WalletManager, initialAddress: String? = nil, initialRequest: PaymentRequest? = nil) {
        self.store = store
        self.sender = sender
        self.walletManager = walletManager
        self.initialAddress = initialAddress
        self.initialRequest = initialRequest
        self.currency = ShadowButton(title: Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits), type: .tertiary)
        amountView = AmountViewController(store: store, isPinPadExpandedAtLaunch: false, scrollDownOnTap: false)
        super.init(nibName: nil, bundle: nil)
        
        self.addressCell = AddressCell(showAddressBookButton: true, addressBookCallback: { [unowned self] in
            // Show address book (modal selector)
            let vc = AddressBookOverviewViewController()
            vc.view.backgroundColor = UIColor(red: 0x15 / 255, green: 0x15 / 255, blue: 0x1F / 255, alpha: 1) // #15151F
            
            // Use a Bread modal window
            let root = ModalViewController(childViewController: vc, store: store)
            root.header.backgroundColor = vc.view.backgroundColor
            root.view.backgroundColor = vc.view.backgroundColor
            root.scrollView.isScrollEnabled = false
            root.modalHeaderImage.isHidden = true
            root.providesPresentationContextTransitionStyle = true
            root.definesPresentationContext = true
            root.modalPresentationStyle = .fullScreen
            root.modalPresentationCapturesStatusBarAppearance = true
        
            // Set the callback, so that AddressBookOverviewViewController won't show
            // the edit / add button
            vc.contactSelectedCallback = { [unowned self] contact in
                self.addressCell.setContent(contact.address)
                self.addressCell.nameLabel.text = "\(contact.name)"
                self.addressCell.textField.textView.textColor = C.Colors.weirdGreen
                root.dismiss(animated: true, completion: nil)
            }
            
            self.present(root, animated: true, completion: nil)
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        defer {
            self.initialAddress = initialAddress
        }
    }

    //MARK - Private
    deinit {
        store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
    }

    private let store: BRStore
    private let sender: Sender
    private let walletManager: WalletManager
    private let amountView: AmountViewController
    private var addressCell: AddressCell!
    private let descriptionCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    
    private var dandelionSwitchContainer = UIView()
    private let dandelionSwitch = UISwitch()
    private let dandelionLabel = UILabel()
    
    private let sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary)
    private let currency: ShadowButton
    private let currencyBorder = UIView(color: C.Colors.blueGrey)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var balance: UInt64 = 0
    private var amount: Satoshis?
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false
    private let initialRequest: PaymentRequest?
    private let confirmTransitioningDelegate = PinTransitioningDelegate()
    private var feeType: Fee?
    
    private var indexedContacts: [String: AddressBookContact] = [:]

    override func viewDidLoad() {
        view.backgroundColor = .clear
        view.addSubview(addressCell)
        view.addSubview(descriptionCell)
        view.addSubview(sendButton)
        view.addSubview(dandelionSwitchContainer)
        
        dandelionLabel.text = S.Send.useDandelion
        dandelionLabel.numberOfLines = 0
        dandelionLabel.lineBreakMode = .byWordWrapping
        dandelionLabel.textColor = UIColor.white
        dandelionSwitch.onTintColor = C.Colors.blue
        dandelionSwitch.isOn = true
        dandelionLabel.font = UIFont.customBody(size: 14)
        
        dandelionSwitchContainer.addSubview(dandelionLabel)
        dandelionSwitchContainer.addSubview(dandelionSwitch)
        
        dandelionLabel.constrain([
            dandelionLabel.leadingAnchor.constraint(equalTo: dandelionSwitchContainer.leadingAnchor, constant: 16),
            dandelionLabel.trailingAnchor.constraint(equalTo: dandelionSwitch.leadingAnchor, constant: -16),
            dandelionLabel.centerYAnchor.constraint(equalTo: dandelionSwitchContainer.centerYAnchor),
        ])
        
        dandelionSwitch.constrain([
            dandelionSwitch.centerYAnchor.constraint(equalTo: dandelionSwitchContainer.centerYAnchor, constant: 0),
            dandelionSwitch.trailingAnchor.constraint(equalTo: dandelionSwitchContainer.trailingAnchor, constant: -16),
            dandelionSwitch.widthAnchor.constraint(equalToConstant: 52)
        ])

        addressCell.constrainTopCorners(sidePadding: 0, topPadding: 0)

        addChildViewController(amountView, layout: {
            amountView.view.constrain([
                amountView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                amountView.view.topAnchor.constraint(equalTo: addressCell.bottomAnchor),
                amountView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        })

        descriptionCell.constrain([
            descriptionCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            descriptionCell.topAnchor.constraint(equalTo: amountView.view.bottomAnchor),
            descriptionCell.leadingAnchor.constraint(equalTo: amountView.view.leadingAnchor),
            descriptionCell.heightAnchor.constraint(equalTo: descriptionCell.textView.heightAnchor, constant: C.padding[4]) ])

        descriptionCell.accessoryView.constrain([
                descriptionCell.accessoryView.constraint(.width, constant: 0.0) ])
        
        dandelionSwitchContainer.constrain([
            dandelionSwitchContainer.topAnchor.constraint(equalTo: descriptionCell.bottomAnchor, constant: 15),
            dandelionSwitchContainer.leftAnchor.constraint(equalTo: descriptionCell.leftAnchor),
            dandelionSwitchContainer.rightAnchor.constraint(equalTo: descriptionCell.rightAnchor),
            dandelionSwitchContainer.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        sendButton.constrain([
            sendButton.constraint(.leading, toView: view, constant: C.padding[2]),
            sendButton.constraint(.trailing, toView: view, constant: -C.padding[2]),
            sendButton.constraint(toBottom: dandelionSwitchContainer, constant: verticalButtonPadding),
            sendButton.constraint(.height, constant: C.Sizes.buttonHeight),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneXOrGreater ? -C.padding[5] : -C.padding[2]) ])
        
        addButtonActions()
        
        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance },
                        callback: {
                            if let balance = $0.walletState.balance {
                                self.balance = balance
                            }
        })
        
        walletManager.wallet?.feePerKb = store.state.fees.regular
        
        addressCell.didEdit = { [unowned self] in
            self.addressCell.nameLabel.text = ""
            self.addressCell.textField.textView.textColor = UIColor.white
            
            if let contact = self.indexedContacts[self.addressCell.address] {
                self.addressCell.nameLabel.text = contact.name
                self.addressCell.textField.textView.textColor = C.Colors.weirdGreen
            }
        }
    
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        indexContacts()
        
        if initialAddress != nil {
            addressCell.setContent(initialAddress)
            amountView.expandPinPad()
        } else if let initialRequest = initialRequest {
            handleRequest(initialRequest)
        }
    }
    
    private func indexContacts() {
        indexedContacts = [:]
        
        let contacts = AddressBookContact.loadContacts()
        for contact in contacts {
            indexedContacts[contact.address] = contact
        }
    }
    
    @objc
    private func dismissKeyboard() {
        addressCell.textField.textView.resignFirstResponder()
    }

    private func addButtonActions() {
        addressCell.paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        addressCell.scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
		addressCell.qrImage.addTarget(self, action: #selector(SendViewController.qrImageTapped), for: .touchUpInside)
        amountView.maxButton.addTarget(self, action: #selector(maxTapped), for: .touchUpInside)
        amountView.view.isUserInteractionEnabled = true
//        amountView.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
        
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        descriptionCell.didReturn = { textView in
            textView.resignFirstResponder()
        }
        descriptionCell.didBeginEditing = { [weak self] in
            self?.amountView.closePinPad()
        }
        addressCell.didBeginEditing = strongify(self) { myself in
            myself.amountView.closePinPad()
        }
        addressCell.didReceivePaymentRequest = { [weak self] request in
            self?.handleRequest(request)
        }
        amountView.balanceTextForAmount = { [weak self] amount, rate in
            return self?.balanceTextForAmount(amount: amount, rate: rate)
        }

        amountView.didUpdateAmount = { [weak self] amount in
            self?.amount = amount
        }
        amountView.didUpdateFee = strongify(self) { myself, fee in
            guard let wallet = myself.walletManager.wallet else { return }
            myself.feeType = fee
            let fees = myself.store.state.fees
            switch fee {
            case .regular:
                wallet.feePerKb = fees.regular
            case .economy:
                wallet.feePerKb = fees.economy
            }
            myself.amountView.updateBalanceLabel()
        }

        amountView.didChangeFirstResponder = { [weak self] isFirstResponder in
            if isFirstResponder {
                self?.descriptionCell.textView.resignFirstResponder()
                self?.addressCell.textField.resignFirstResponder()
                self?.addressCell.textField.textView.resignFirstResponder()
            }
        }
    }

    private func balanceTextForAmount(amount: Satoshis?, rate: Rate?) -> (NSAttributedString?, NSAttributedString?) {
        let balanceAmount = DisplayAmount(amount: Satoshis(rawValue: balance), state: store.state, selectedRate: rate, minimumFractionDigits: 0)
        let balanceText = balanceAmount.description
        let balanceOutput = String(format: S.Send.balance, balanceText)
        var feeOutput = ""
        var color: UIColor = .grayTextTint
        if let amount = amount, amount.rawValue > 0 {
            let fee = sender.feeForTx(amount: amount.rawValue)
            let feeAmount = DisplayAmount(amount: Satoshis(rawValue: fee), state: store.state, selectedRate: rate, minimumFractionDigits: 0)
            let feeText = feeAmount.description
            feeOutput = String(format: S.Send.fee, feeText)
            if (balance >= fee) && amount.rawValue > (balance - fee) {
                color = .cameraGuideNegative
            }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.customBody(size: 14.0),
            NSAttributedString.Key.foregroundColor: color
        ]

        let feeAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.customBody(size: 14.0),
            NSAttributedString.Key.foregroundColor: UIColor.grayTextTint
        ]

        return (NSAttributedString(string: balanceOutput, attributes: attributes), NSAttributedString(string: feeOutput, attributes: feeAttributes))
    }
    
    @objc private func maxTapped() {
        if balance > 0 {
            let fee = sender.feeForTx(amount: balance)
            let output = balance - fee
            amountView.amount = Satoshis(rawValue: output)
        }
    }

    @objc private func pasteTapped() {
        guard let pasteboard = UIPasteboard.general.string, pasteboard.utf8.count > 0 else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }
        guard let request = PaymentRequest(string: pasteboard) else {
            return showAlert(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressOnPasteboard, buttonLabel: S.Button.ok)
        }
        handleRequest(request)
    }

    @objc private func scanTapped() {
        descriptionCell.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            self?.handleRequest(request)
        }
    }

	@objc private func qrImageTapped() {
		descriptionCell.textView.resignFirstResponder()
		addressCell.textField.resignFirstResponder()

		let imagePicker = UIImagePickerController()

		if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
			imagePicker.delegate = self
			imagePicker.sourceType = .savedPhotosAlbum;
			imagePicker.allowsEditing = false

			self.present(imagePicker, animated: true, completion: nil)
		}
	}

	internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		self.dismiss(animated: true, completion: { () -> Void in })

		if
            let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
			let cgImage = originalImage.cgImage {

			let ciImage = CIImage(cgImage:cgImage)

			if
				let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy : CIDetectorAccuracyHigh]) {
				let features = detector.features(in: ciImage)

				if features.count == 1 {
					if let qrCode = features.first as? CIQRCodeFeature {
						if let decode = qrCode.messageString {
							if let payRequest = PaymentRequest(string: decode) {
								self.handleRequest(payRequest)
                                return;
							}
						}
					}
				} else if features.count > 1 {
					return showAlert(title: S.QRImageReader.title, message: S.QRImageReader.TooManyFoundMessage, buttonLabel: S.Button.ok)
				} else {
					return showAlert(title: S.QRImageReader.title, message: S.QRImageReader.NotFoundMessage, buttonLabel: S.Button.ok)
				}

			}
		}

	}

    @objc private func sendTapped() {
        if addressCell.textField.isFirstResponder {
            addressCell.textField.resignFirstResponder()
        }

        if sender.transaction == nil {
            let address = addressCell.address
            guard address != "" else {
                return showAlert(title: S.Alert.error, message: S.Send.noAddress, buttonLabel: S.Button.ok)
            }
            guard address.isValidAddress else {
                return showAlert(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, buttonLabel: S.Button.ok)
            }
            guard let amount = amount else {
                return showAlert(title: S.Alert.error, message: S.Send.noAmount, buttonLabel: S.Button.ok)
            }
            if let minOutput = walletManager.wallet?.minOutputAmount {
                guard amount.rawValue >= minOutput else {
                    let minOutputAmount = Amount(amount: minOutput, rate: Rate.empty, maxDigits: store.state.maxDigits)
                    let message = String(format: S.PaymentProtocol.Errors.smallPayment, minOutputAmount.string(isBtcSwapped: store.state.isBtcSwapped))
                    return showAlert(title: S.Alert.error, message: message, buttonLabel: S.Button.ok)
                }
            }
            guard !(walletManager.wallet?.containsAddress(address) ?? false) else {
                return showAlert(title: S.Alert.error, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            }
            guard amount.rawValue + sender.feeForTx(amount: amount.rawValue, force: true) <= (walletManager.wallet?.balance ?? 0) else {
                return showAlert(title: S.Alert.error, message: S.Send.insufficientFunds, buttonLabel: S.Button.ok)
            }
            guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
            }
        }
        
        sender.transaction?.isDandelion = dandelionSwitch.isOn

        guard let amount = amount else { return }
        let confirm = ConfirmationViewController(amount: amount, fee: Satoshis(sender.fee), feeType: feeType ?? .regular, state: store.state, selectedRate: amountView.selectedRate, minimumFractionDigits: amountView.minimumFractionDigits, address: addressCell.address, isUsingBiometrics: sender.canUseBiometrics)
        
		confirm.successCallback = {
            confirm.dismiss(animated: true, completion: {
                self.send()
            })
        }
        confirm.cancelCallback = {
            confirm.dismiss(animated: true, completion: {
                self.sender.transaction = nil
            })
        }
        confirmTransitioningDelegate.shouldShowMaskView = false
        confirm.transitioningDelegate = confirmTransitioningDelegate
        confirm.modalPresentationStyle = .overFullScreen
        confirm.modalPresentationCapturesStatusBarAppearance = true
        
        present(confirm, animated: true, completion: nil)
        return
    }

    private func handleRequest(_ request: PaymentRequest) {
        switch request.type {
        case .local:
            addressCell.setContent(request.toAddress)
            addressCell.isEditable = true
            if let amount = request.amount {
                amountView.forceUpdateAmount(amount: amount)
            }
            if request.label != nil {
                descriptionCell.content = request.label
            }
        case .remote:
            let loadingView = BRActivityViewController(message: S.Send.loadingRequest)
            present(loadingView, animated: true, completion: nil)
            request.fetchRemoteRequest(completion: { [weak self] request in
                DispatchQueue.main.async {
                    loadingView.dismiss(animated: true, completion: {
                        if let paymentProtocolRequest = request?.paymentProtoclRequest {
                            self?.confirmProtocolRequest(protoReq: paymentProtocolRequest)
                        } else {
                            self?.showErrorMessage(S.Send.remoteRequestError)
                        }
                    })
                }
            })
        }
    }

    private func send() {
        guard let rate = store.state.currentRate else { return }
        guard let feePerKb = walletManager.wallet?.feePerKb else { return }
        
        sender.send(biometricsMessage: S.VerifyPin.touchIdMessage,
                    rate: rate,
                    comment: descriptionCell.textView.text,
                    feePerKb: feePerKb,
                    verifyPinFunction: { [weak self] pinValidationCallback in
                        self?.presentVerifyPin?(S.VerifyPin.authorize) { [weak self] pin, vc in
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
                    self?.dismiss(animated: true, completion: {
                        guard let myself = self else { return }
                        myself.store.trigger(name: .showStatusBar)
                        if myself.isPresentedFromLock {
                            myself.store.trigger(name: .loginFromSend)
                        }
                        myself.onPublishSuccess?()
                    })
                    //self?.saveEvent("send.success")
                case .creationError(let message, _):
                    self?.showAlert(title: S.Send.createTransactionError, message: message, buttonLabel: S.Button.ok)
                    //self?.saveEvent("send.publishFailed", attributes: ["errorMessage": message])
                case .publishFailure(let error):
                    if case .posixError(let code, let description) = error {
                        self?.showAlert(title: S.Alerts.sendFailure, message: "\(description) (\(code))", buttonLabel: S.Button.ok)
                        //self?.saveEvent("send.publishFailed", attributes: ["errorMessage": "\(description) (\(code))"])
                    }
                }
        })
    }

    func confirmProtocolRequest(protoReq: PaymentProtocolRequest) {
        guard let firstOutput = protoReq.details.outputs.first else { return }
        guard let wallet = walletManager.wallet else { return }

        let address = firstOutput.swiftAddress
        let isValid = protoReq.isValid()
        var isOutputTooSmall = false

        if let errorMessage = protoReq.errorMessage, errorMessage == S.PaymentProtocol.Errors.requestExpired, !isValid {
            return showAlert(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
        }

        //TODO: check for duplicates of already paid requests
        var requestAmount = Satoshis(0)
        protoReq.details.outputs.forEach { output in
            if output.amount > 0 && output.amount < wallet.minOutputAmount {
                isOutputTooSmall = true
            }
            requestAmount += output.amount
        }

        if wallet.containsAddress(address) {
            return showAlert(title: S.Alert.warning, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
        } else if wallet.addressIsUsed(address) && !didIgnoreUsedAddressWarning {
            let message = "\(S.Send.UsedAddress.title)\n\n\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)"
            return showError(title: S.Alert.warning, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if let message = protoReq.errorMessage, message.utf8.count > 0 && (protoReq.commonName?.utf8.count)! > 0 && !didIgnoreIdentityNotCertified {
            return showError(title: S.Send.identityNotCertified, message: message, ignore: { [weak self] in
                self?.didIgnoreIdentityNotCertified = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if requestAmount < wallet.minOutputAmount {
            let amount = Amount(amount: wallet.minOutputAmount, rate: Rate.empty, maxDigits: store.state.maxDigits)
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, amount.bits)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        } else if isOutputTooSmall {
            let amount = Amount(amount: wallet.minOutputAmount, rate: Rate.empty, maxDigits: store.state.maxDigits)
            let message = String(format: S.PaymentProtocol.Errors.smallTransaction, amount.bits)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        }

        if let name = protoReq.commonName {
            addressCell.setContent(protoReq.pkiType != "none" ? "\(Symbols.lock) \(name.sanitized)" : name.sanitized)
        }

        if requestAmount > 0 {
            amountView.forceUpdateAmount(amount: requestAmount)
        }
        descriptionCell.content = protoReq.details.memo

        if requestAmount == 0 {
            if let amount = amount {
                guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                    return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
                }
            }
        } else {
            addressCell.isEditable = false
            sender.createTransaction(forPaymentProtocol: protoReq)
        }
    }

    private func showError(title: String, message: String, ignore: @escaping () -> Void) {
        let alertController = AlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(AlertAction(title: S.Button.ignore, style: .default, handler: { _ in
            ignore()
        }))
        alertController.addAction(AlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    //MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    //TODO - maybe put this in ModalPresentable?
    private func copyKeyboardChangeAnimation(notification: Notification) {
        return;
        /*
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        UIView.animate(withDuration: info.animationDuration, delay: 0, options: info.animationOptions, animations: {
            guard let parentView = self.parentView else { return }
            parentView.frame = parentView.frame.offsetBy(dx: 0, dy: info.deltaY)
        }, completion: nil)
         */
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SendViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.sendBitcoin
    }

    var modalTitle: String {
        return S.Send.title
    }
}
