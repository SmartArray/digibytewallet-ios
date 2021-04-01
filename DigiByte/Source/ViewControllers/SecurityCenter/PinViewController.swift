//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

enum UpdatePinType {
    case creationNoPhrase
    case creationWithPhrase
    case update
    case login
}

private let biometricsSize: CGFloat = 128.0
private let topControlHeight: CGFloat = 32.0

class UpdatePinViewController : PINViewController {

    //MARK: - Public
    var setPinSuccess: ((String) -> Void)?
    var resetFromDisabledSuccess: (() -> Void)?
    var resetFromDisabledWillSucceed: (() -> Void)?
    
    init(store: BRStore, walletManager: WalletManager, type: UpdatePinType, showsBackButton: Bool = true, phrase: String? = nil) {
        self.walletManager = walletManager
        self.phrase = phrase
        self.showsBackButton = showsBackButton
        self.faq = UIButton.buildFaqButton(store: store, articleId: ArticleIds.setPin)
        self.type = type
        super.init(store: store, style: .create)
    }

    //MARK: - Private
    private let walletManager: WalletManager
    private let faq: UIButton
    private var currentPin: String?
    
    private var step: Step = .verify {
        didSet {
            switch step {
            case .verify:
                instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
                caption.isHidden = true
            case .new:
                let instructionText = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterNew
                if instruction.text != instructionText {
                    instruction.pushNewText(instructionText)
                }
                header.text = S.UpdatePin.createTitle
                caption.isHidden = false
            case .confirmNew:
                caption.isHidden = true
                if isCreatingPin {
                    header.text = S.UpdatePin.createTitleConfirm
                } else {
                    instruction.pushNewText(S.UpdatePin.reEnterNew)
                }
            }
        }
    }
    
    private var newPin: String?
    private var phrase: String?
    private let type: UpdatePinType
    private var isCreatingPin: Bool {
        return type != .update
    }
    
    private let newPinLength = 6
    private let showsBackButton: Bool

    private enum Step {
        case verify
        case new
        case confirmNew
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addSubviews()
        addConstraints()
        setData()
    }
    
    private func addConstraints() {
        faq.constrain([
            faq.topAnchor.constraint(equalTo: header.topAnchor),
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.constraint(.height, constant: 44.0),
            faq.constraint(.width, constant: 44.0)
        ])
    }
    
    private func addSubviews() {
        view.addSubview(faq)
        faq.isHidden = true // TODO: Writeup support/FAQ documentation for digibyte wallet
    }

    private func setData() {
        caption.text = S.UpdatePin.caption
        header.text = isCreatingPin ? S.UpdatePin.createTitle : S.UpdatePin.updateTitle
        instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
        
        pinPad.ouputDidUpdate = { [weak self] text in
            guard let step = self?.step else { return }
            switch step {
            case .verify:
                self?.didUpdateForCurrent(pin: text)
            case .new :
                self?.didUpdateForNew(pin: text)
            case .confirmNew:
                self?.didUpdateForConfirmNew(pin: text)
            }
        }

        if isCreatingPin {
            step = .new
            caption.isHidden = false
        } else {
            caption.isHidden = true
        }
        
        if !showsBackButton {
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
        }
    }

    private func didUpdateForCurrent(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == store.state.pinLength {
            if walletManager.authenticate(pin: pin) {
                pushNewStep(.new)
                currentPin = pin
                replacePinView()
            } else {
                if walletManager.walletDisabledUntil > 0 {
                    dismiss(animated: true, completion: {
                        self.store.perform(action: RequireLogin())
                    })
                } else {
                    clearAfterFailure()
                }
            }
        }
    }

    private func didUpdateForNew(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            newPin = pin
            pushNewStep(.confirmNew)
        }
    }

    private func didUpdateForConfirmNew(pin: String) {
        guard let newPin = newPin else { return }
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            if pin == newPin {
                didSetNewPin()
            } else {
                clearAfterFailure()
                pushNewStep(.new)
            }
        }
    }

    private func clearAfterFailure() {
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
            self?.pinView.fill(0)
        }
        pinPad.clear()
    }

    private func replacePinView() {
        pinView.removeFromSuperview()
        pinView = PinView(style: .create, length: newPinLength)
        view.addSubview(pinView)
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
    }

    private func pushNewStep(_ newStep: Step) {
        step = newStep
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinView.fill(0)
        }
    }

    private func didSetNewPin() {
        DispatchQueue.walletQueue.async { [weak self] in
            guard let newPin = self?.newPin else { return }
            var success: Bool? = false
            if let seedPhrase = self?.phrase {
                success = self?.walletManager.forceSetPin(newPin: newPin, seedPhrase: seedPhrase)
            } else if let currentPin = self?.currentPin {
                success = self?.walletManager.changePin(newPin: newPin, pin: currentPin)
                DispatchQueue.main.async { self?.store.trigger(name: .didUpgradePin) }
            } else if self?.type == .creationNoPhrase {
                success = self?.walletManager.forceSetPin(newPin: newPin)
            }

            DispatchQueue.main.async {
                if let success = success, success == true {
                    if self?.resetFromDisabledSuccess != nil {
                        self?.resetFromDisabledWillSucceed?()
                        self?.store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                            self?.dismiss(animated: true, completion: {
                                self?.resetFromDisabledSuccess?()
                            })
                        })))
                    } else {
                        self?.store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                            self?.setPinSuccess?(newPin)
                            if self?.type != .creationNoPhrase {
                                self?.parent?.dismiss(animated: true, completion: nil)
                            }
                        })))
                    }

                } else {
                    let alert = AlertController(title: S.UpdatePin.updateTitle, message: S.UpdatePin.setPinError, preferredStyle: .alert)
                    alert.addAction(AlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
                        self?.clearAfterFailure()
                        self?.pushNewStep(.new)
                    }))
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/*
  _                 _       _   _ _
 | |               (_)     | | | (_)
 | |     ___   __ _ _ _ __ | | | |_  _____      __
 | |    / _ \ / _` | | '_ \| | | | |/ _ \ \ /\ / /
 | |___| (_) | (_| | | | | \ \_/ / |  __/\ V  V /
 \_____/\___/ \__, |_|_| |_|\___/|_|\___| \_/\_/
               __/ |         C o n t r o l l e r
               |___/
*/
class LoginViewController: PINViewController, Trackable {
    var w: WalletManager?
    
    var hidePinView = true {
        didSet {
            DispatchQueue.main.async {
                self.pinView.isHidden = self.hidePinView
            }
        }
    }
    
    var hideActivityView = false {
        didSet {
            DispatchQueue.main.async {
                self.activityView.isHidden = self.hideActivityView
            }
        }
    }
    
    var walletManager: WalletManager? {
        didSet {
            guard walletManager != nil else {
                hidePinView = true
                hideActivityView = false
                return
            }
            hidePinView = false
            hideActivityView = true
        }
    }
    var shouldSelfDismiss = false
    var authenticated = false
    
    //MARK: - Private
    private let disabledView: WalletDisabledView
    private var hasAttemptedToShowBiometrics = false
    private let lockedOverlay = UIVisualEffectView()
    private var isResetting = false
    private var unlockTimer: Timer?
    private let isPresentedForLock: Bool
    private let activityView = UIActivityIndicatorView(style: .whiteLarge)
    private let securityCheckLabel = UILabel(font: .customMedium(size: 12), color: C.Colors.blueGrey)
    private let digiIdButton = DGBHapticButton()

    private let biometricsView: UIView = {
        let view = UIView()

        let label = UILabel(font: UIFont.customBody(size: 14), color: .white)
        label.text = LAContext.biometricType() == .face ? S.UnlockScreen.faceIdPrompt : S.UnlockScreen.touchIdText
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        
        let biometricsImage = { () -> UIImageView in
            if LAContext.biometricType() == .face {
                let img = UIImage(named: "faceId")!.withRenderingMode(.alwaysTemplate)
                let v = UIImageView(image: img)
                v.tintColor = C.Colors.blue
                return v
            } else {
                return UIImageView(image: UIImage(named: "touchId"))
            }
        }()
        
        biometricsImage.contentMode = .scaleAspectFit
        biometricsImage.isUserInteractionEnabled = true
        
        view.addSubview(biometricsImage)
        view.addSubview(label)
    
        label.constrain([
            label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            label.topAnchor.constraint(equalTo: biometricsImage.bottomAnchor, constant: 20),
        ])
        
        biometricsImage.constrain([
            biometricsImage.topAnchor.constraint(equalTo: view.topAnchor),
            biometricsImage.widthAnchor.constraint(equalToConstant: biometricsSize),
            biometricsImage.heightAnchor.constraint(equalToConstant: biometricsSize),
            biometricsImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        return view
    }()
    
    init(store: BRStore, isPresentedForLock: Bool, walletManager: WalletManager? = nil) {
        self.walletManager = walletManager
        self.disabledView = WalletDisabledView(store: store)
        self.isPresentedForLock = isPresentedForLock
        
        super.init(store: store)
    }
    
    private func setData() {
        securityCheckLabel.text = S.Prompts.SecurityCheck.header.uppercased()
        securityCheckLabel.numberOfLines = 2
        securityCheckLabel.textAlignment = .center
        securityCheckLabel.lineBreakMode = .byWordWrapping
        
        header.text = S.UnlockScreen.subheader

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addSubviews()
        addConstraints()
        addBiometricsButton()
        addDigiIDButton()
        addPinPadCallback()
        setData()
//        
//        DispatchQueue.main.async {            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
//                self.store.perform(action: HamburgerActions.Present(modal: .digiAssets))
//            })
//        }
        
        disabledView.didTapReset = { [weak self] in
            guard let store = self?.store else { return }
            guard let walletManager = self?.walletManager else { return }
            self?.isResetting = true
            let nc = UINavigationController()
            let recover = EnterPhraseViewController(store: store, walletManager: walletManager, reason: .validateForResettingPin({ phrase in
                let updatePin = UpdatePinViewController(store: store, walletManager: walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
                nc.pushViewController(updatePin, animated: true)
                updatePin.resetFromDisabledWillSucceed = {
                    self?.disabledView.isHidden = true
                }
                updatePin.resetFromDisabledSuccess = {
                    self?.authenticationSucceded()
                }
            }))
            recover.addCloseNavigationItem()
            nc.viewControllers = [recover]
            nc.navigationBar.tintColor = .whiteTint
            nc.navigationBar.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.darkText,
                NSAttributedString.Key.font: UIFont.customBold(size: 17.0)
            ]
            nc.setClearNavbar()
            nc.navigationBar.isTranslucent = false
            nc.navigationBar.barTintColor = .whiteTint
            nc.viewControllers = [recover]
            self?.present(nc, animated: true, completion: nil)
        }
        store.subscribe(self, name: .loginFromSend, callback: {_ in
            self.authenticationSucceded()
        })
    }
    
    private func addDigiIDButton() {
        digiIdButton.setImage(UIImage(named: "DigiID-Logo"), for: .normal)
        digiIdButton.tap = {
            self.walletManager?.store.trigger(name: .scanDigiId)
        }
    }
    
    private func addPinPadCallback() {
        pinPad.ouputDidUpdate = { [weak self] pin in
            guard let myself = self else { return }
            guard let pinView = self?.pinView else { return }
            let attemptLength = pin.utf8.count
            pinView.fill(attemptLength)
            self?.pinPad.isAppendingDisabled = attemptLength < myself.store.state.pinLength ? false : true
            if attemptLength == myself.store.state.pinLength {
                self?.authenticate(pin: pin)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard UIApplication.shared.applicationState != .background else { return }
        
        if isPresentedForLock {
            walletLocked()
        }
        
        if shouldUseBiometrics && !hasAttemptedToShowBiometrics && !isPresentedForLock {
            hasAttemptedToShowBiometrics = true
            
            // do not ask for fingerprint / faceid, if app was opened using an application url
            if UserDefaults.automaticBiometricsOnStartup, senderApp == "" {
                self.biometricsTapped()
            }
        }
        if !isResetting {
            lockIfNeeded()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unlockTimer?.invalidate()
    }

    private func addSubviews() {
        if walletManager == nil {
            view.addSubview(activityView)
        }
        
        view.addSubview(securityCheckLabel)
        view.addSubview(digiIdButton)
    }
    
    private func addConstraints() {
        if walletManager == nil {
            activityView.constrain([
                activityView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20.0)
            ])
            activityView.startAnimating()
        }
        
        securityCheckLabel.constrain([
            securityCheckLabel.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 16),
            securityCheckLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            securityCheckLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            securityCheckLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
        ])
        
        digiIdButton.constrain([
            digiIdButton.centerYAnchor.constraint(equalTo: securityCheckLabel.bottomAnchor),
            digiIdButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),
            digiIdButton.widthAnchor.constraint(equalToConstant: 40),
            digiIdButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        constraints["header.top"]?.isActive = false
        
        header.constrain([
            header.topAnchor.constraint(equalTo: securityCheckLabel.bottomAnchor, constant: 18),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
        ])
    }
    
    private func addBiometricsButton() {
        guard shouldUseBiometrics else { return }
        
        view.addSubview(biometricsView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(biometricsTapped))
        tap.numberOfTapsRequired = 1
        tap.numberOfTouchesRequired = 1
        biometricsView.addGestureRecognizer(tap)
        
        let deviceHeight = Double((UIApplication.shared.keyWindow?.bounds.height)!)
        
        biometricsView.constrain([
            biometricsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            biometricsView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            //biometricsView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 5),
            biometricsView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: deviceHeight < 600.0 ? -102 : -120),
            biometricsView.heightAnchor.constraint(equalToConstant: 170),
        ])
        
        constraints["pinView.centerY"]?.isActive = false
        pinView.constrain([
            pinView.topAnchor.constraint(equalTo: biometricsView.bottomAnchor, constant: deviceHeight < 600.0 ? 20 : 105)
        ])
    }
    
    private func authenticate(pin: String) {
        guard let walletManager = walletManager else { return }
        guard !E.isScreenshots else { return authenticationSucceded() }
        guard walletManager.authenticate(pin: pin) else { return authenticationFailed() }
        authenticationSucceded()
    }
    
    private func walletLocked() {
        let label = UILabel(font: .customBody(size: 14))
        label.textColor = .white
        label.text = S.UnlockScreen.locked
    
        let lock = UIImageView(image: UIImage(named: "locked")?.withRenderingMode(.alwaysTemplate))
        lock.tintColor = UIColor.white
        
        view.addSubview(label)
        view.addSubview(lock)
        
        label.constrain([
            label.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -C.padding[1]),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        lock.constrain([
            lock.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[1]),
            lock.centerXAnchor.constraint(equalTo: label.centerXAnchor) ])
        view.layoutIfNeeded()
        
        self.pinView.alpha = 0.0
        self.pinPad.view.alpha = 0.0
        self.biometricsView.alpha = 0.0
        self.header.alpha = 0.0
        self.securityCheckLabel.alpha = 0.0
        self.digiIdButton.alpha = 0.0
        
        lock.alpha = 1.0
        label.alpha = 1.0
        
        UIView.animate(withDuration: 0.4, delay: 1.0, options: .curveEaseInOut, animations: {
            self.pinView.alpha = 1.0
            self.pinPad.view.alpha = 1.0
            self.biometricsView.alpha = 1.0
            self.header.alpha = 1.0
            self.securityCheckLabel.alpha = 1.0
            self.digiIdButton.alpha = 1.0
            
            lock.alpha = 0
            label.alpha = 0
        }, completion: nil)
    }
    
    private func authenticationSucceded() {
        authenticated = true
        //saveEvent("login.success")
        let label = UILabel(font: .customBody(size: 14))
        label.textColor = .white
        label.text = S.UnlockScreen.unlocked
        label.alpha = 0.0
        let lock = UIImageView(image: UIImage(named: "unlocked")?.withRenderingMode(.alwaysTemplate))
        lock.tintColor = UIColor.white
        lock.alpha = 0.0
        
        view.addSubview(label)
        view.addSubview(lock)
        
        label.constrain([
            label.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -C.padding[1]),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        lock.constrain([
            lock.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[1]),
            lock.centerXAnchor.constraint(equalTo: label.centerXAnchor) ])
        view.layoutIfNeeded()
        
        // Haptic Feedback when unlocking the wallet
        if #available(iOS 10.0, *) {
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.prepare()
            feedbackGenerator.notificationOccurred(.success)
        }
        
        UIView.spring(0.6, delay: 0.1, animations: {
            self.pinView.alpha = 0.0
            self.pinPad.view.alpha = 0.0
            self.biometricsView.alpha = 0.0
            self.header.alpha = 0.0
            self.securityCheckLabel.alpha = 0.0
            self.digiIdButton.alpha = 0.0
            
            lock.alpha = 1.0
            label.alpha = 1.0
            
            self.view.layoutIfNeeded()
        }) { completion in
            if self.shouldSelfDismiss {
                self.dismiss(animated: true, completion: nil)
            }
            self.store.perform(action: LoginSuccess())
            self.store.trigger(name: .showStatusBar)
        }
    }
    
    private func authenticationFailed() {
        //saveEvent("login.failed")
        authenticated = false
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
        }
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
            self?.pinView.fill(0)
            self?.lockIfNeeded()
        }
    }
    
    private var shouldUseBiometrics: Bool {
        guard let walletManager = self.walletManager else { return false }
        return LAContext.canUseBiometrics && !walletManager.pinLoginRequired && store.state.isBiometricsEnabled
    }
    
    @objc func biometricsTapped() {
        guard !isWalletDisabled else { return }

        self.walletManager?.authenticate(biometricsPrompt: S.UnlockScreen.touchIdPrompt, isDigiIDAuth: false, completion: { result in
            if result == .success {
                self.authenticationSucceded()
            }
        })
    }
    
    private func lockIfNeeded() {
        if let disabledUntil = walletManager?.walletDisabledUntil {
            let now = Date().timeIntervalSince1970
            if disabledUntil > now {
                //saveEvent("login.locked")
                let disabledUntilDate = Date(timeIntervalSince1970: disabledUntil)
                let unlockInterval = disabledUntil - now
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate(unlockInterval > C.secondsInDay ? "h:mm:ss a MMM d, yyy" : "h:mm:ss a")
                
                disabledView.setTimeLabel(string: String(format: S.UnlockScreen.disabled, df.string(from: disabledUntilDate)))
                
                pinPad.view.isUserInteractionEnabled = false
                unlockTimer?.invalidate()
                unlockTimer = Timer.scheduledTimer(timeInterval: unlockInterval, target: self, selector: #selector(LoginViewController.unlock), userInfo: nil, repeats: false)
                
                if disabledView.superview == nil {
                    view.addSubview(disabledView)
                    setNeedsStatusBarAppearanceUpdate()
                    disabledView.constrain(toSuperviewEdges: nil)
                    disabledView.show()
                }
            } else {
                pinPad.view.isUserInteractionEnabled = true
                disabledView.hide { [weak self] in
                    self?.disabledView.removeFromSuperview()
                    self?.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }
    
    private var isWalletDisabled: Bool {
        guard let walletManager = walletManager else { return false }
        let now = Date().timeIntervalSince1970
        return walletManager.walletDisabledUntil > now
    }
    
    @objc private func unlock() {
        //saveEvent("login.unlocked")
        caption.pushNewText(S.UnlockScreen.subheader)
        pinPad.view.isUserInteractionEnabled = true
        unlockTimer = nil
        disabledView.hide { [weak self] in
            self?.disabledView.removeFromSuperview()
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Base class
class PINViewController: UIViewController, Subscriber {
    fileprivate let store: BRStore
    
    fileprivate let header = UILabel.wrapping(font: .customBold(size: 26.0), color: .darkText)
    fileprivate let instruction = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkText)
    fileprivate let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    fileprivate var pinView: PinView
    fileprivate let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad, maxDigits: 0)
    fileprivate let spacer = UIView()
    
    fileprivate var constraints: [String: NSLayoutConstraint] = [:]
    
    init(store: BRStore, style: PinViewStyle = .create) {
        self.store = store
        self.pinView = PinView(style: style, length: store.state.pinLength)
        super.init(nibName: nil, bundle: nil)
    }
    
    private func configurate() {
        view.backgroundColor = C.Colors.background
        
        caption.textAlignment = .center
        caption.textColor = C.Colors.text
        caption.font = UIFont.customBody(size: 16)
        
        header.textAlignment = .center
        header.textColor = C.Colors.text
        header.font = UIFont.customBody(size: 16)
        
        instruction.textAlignment = .center
        instruction.textColor = C.Colors.text
        instruction.font = UIFont.customBody(size: 15)
    }
    
    override func viewDidLoad() {
        configurate()
        addSubviews()
        addConstraints()
    }
    
    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(pinView)
        view.addSubview(spacer)
    }
    
    private func setData() {
        caption.text = S.UpdatePin.caption
        //header.text = isCreatingPin ? S.UpdatePin.createTitle : S.UpdatePin.updateTitle
        //instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
        
        pinPad.ouputDidUpdate = { [weak self] text in
            self?.checkPIN(text)
        }
        
        // caption.isHidden = false
    }
    
    private func checkPIN(_ pin: String) {
        print("PIN: ", pin)
    }
    
    private func addConstraints() {
        constraints["header.top"] = header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2])
        header.constrain([
            constraints["header.top"],
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])
        ])
        
        instruction.constrain([
            instruction.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            instruction.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor)
        ])
        
        constraints["pinView.centerY"] = pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor, constant: 0)
        pinView.constrain([
            constraints["pinView.centerY"],
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize)
        ])
        
        if E.isIPhoneXOrGreater {
            addChildViewController(pinPad, layout: {
                pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
                pinPad.view.constrain([pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height),
                                       pinPad.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[3])])
            })
        } else {
            addChildViewController(pinPad, layout: {
                pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
                pinPad.view.constrain([pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height)])
            })
        }
        spacer.constrain([
            spacer.topAnchor.constraint(equalTo: instruction.bottomAnchor),
            spacer.bottomAnchor.constraint(equalTo: caption.topAnchor) ])
        caption.constrain([
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
