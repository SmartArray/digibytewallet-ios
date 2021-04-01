//
//  ModalPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication
import Kingfisher

typealias PresentDigiIdScan = ((@escaping DigiIDScanCompletion) -> Void)

class ModalPresenter : Subscriber, Trackable {

    //MARK: - Public
    var walletManager: WalletManager?
    init(store: BRStore, walletManager: WalletManager, window: UIWindow, apiClient: BRAPIClient) {
        self.store = store
        self.window = window
        self.walletManager = walletManager
        self.modalTransitionDelegate = ModalTransitionDelegate(type: .regular, store: store)
        self.wipeNavigationDelegate = StartNavigationDelegate(store: store)
        self.noAuthApiClient = apiClient
        addSubscriptions()
    }

    //MARK: - Private
    private let store: BRStore
    private let window: UIWindow
    private let alertHeight: CGFloat = 350.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()
    private let securityCenterNavigationDelegate = SecurityCenterNavigationDelegate()
    private let verifyPinTransitionDelegate = PinTransitioningDelegate()
    private let noAuthApiClient: BRAPIClient

    private var currentRequest: PaymentRequest?
    private var reachability = ReachabilityMonitor()
    private var notReachableAlert: InAppAlert?
    private let wipeNavigationDelegate: StartNavigationDelegate

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
        store.subscribe(self,
                        selector: { $0.hamburgerModal != $1.hamburgerModal},
                        callback: { self.hamburgerMenuViewController($0.hamburgerModal) })
        store.subscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != nil },
                        callback: { self.handleAlertChange($0.alert) })
        store.subscribe(self, name: .presentFaq(""), callback: {
            guard let trigger = $0 else { return }
            if case .presentFaq(let articleId) = trigger {
                self.makeFaq(articleId: articleId)
            }
        })

        //Subscribe to prompt actions
        store.subscribe(self, name: .promptUpgradePin, callback: { _ in
            self.presentUpgradePin()
        })
        store.subscribe(self, name: .promptPaperKey, callback: { _ in
            self.presentWritePaperKey()
        })
        store.subscribe(self, name: .promptBiometrics, callback: { _ in
            self.presentBiometricsSetting()
        })
        store.subscribe(self, name: .promptShareData, callback: { _ in
            self.promptShareData()
        })
        store.subscribe(self, name: .openFile(Data()), callback: {
            guard let trigger = $0 else { return }
            if case .openFile(let file) = trigger {
                self.handleFile(file)
            }
        })
        store.subscribe(self, name: .recommendRescan, callback: { _ in
            self.presentRescan()
        })

        //URLs
        store.subscribe(self, name: .receivedPaymentRequest(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .receivedPaymentRequest(request) = trigger {
                if let request = request {
                    self.handlePaymentRequest(request: request)
                }
            }
        })
        store.subscribe(self, name: .scanQr, callback: { _ in
            self.handleScanQrURL()
        })
        store.subscribe(self, name: .scanDigiId, callback: { _ in
            self.handleDigiIdScanQrURL()
        })
        store.subscribe(self, name: .copyWalletAddresses(nil, nil), callback: {
            guard let trigger = $0 else { return }
            if case .copyWalletAddresses(let success, let error) = trigger {
                self.handleCopyAddresses(success: success, error: error)
            }
        })
        store.subscribe(self, name: .authenticateForBitId("", {_ in}), callback: {
            guard let trigger = $0 else { return }
            if case .authenticateForBitId(let prompt, let callback) = trigger {
                self.authenticateForBitId(prompt: prompt, callback: callback)
            }
        })
        reachability.didChange = { isReachable in
            if isReachable {
                self.hideNotReachable()
            } else {
                self.showNotReachable()
            }
        }
        store.subscribe(self, name: .lightWeightAlert(""), callback: {
            guard let trigger = $0 else { return }
            if case let .lightWeightAlert(message) = trigger {
                self.showLightWeightAlert(message: message)
            }
        })
        store.subscribe(self, name: .showAlert(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .showAlert(alert) = trigger {
                if let alert = alert {
                    self.topViewController?.present(alert, animated: true, completion: nil)
                }
            }
        })
    }

    private func presentModal(_ type: RootModal, configuration: ((UIViewController) -> Void)? = nil) {
        guard type != .loginScan else { return presentLoginScan() }
        guard let vc = rootModalViewController(type) else {
            self.store.perform(action: RootModalActions.Present(modal: .none))
            return
        }
        
        vc.transitioningDelegate = modalTransitionDelegate
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        configuration?(vc)

        topViewController?.present(vc, animated: true, completion: {
            self.store.perform(action: RootModalActions.Present(modal: .none))
            self.store.trigger(name: .hideStatusBar)
        })
    }

    private func handleAlertChange(_ type: AlertType?) {
        guard let type = type else { return }
        presentAlert(type, completion: {
            self.store.perform(action: Alert.Hide())
        })
    }

    func presentAlert(_ type: AlertType, completion: @escaping ()->Void) {
        let alertView = AlertView(type: type)
        let window = UIApplication.shared.keyWindow!
        let size = window.bounds.size
        
        let backgroundView = BlurView()
        backgroundView.alpha = 0.0
        
        window.addSubview(backgroundView)
        window.addSubview(alertView)

        backgroundView.constrain([
            backgroundView.heightAnchor.constraint(equalTo: window.heightAnchor),
            backgroundView.widthAnchor.constraint(equalTo: window.widthAnchor),
        ])
        
        let topConstraint = alertView.constraint(.top, toView: window, constant: size.height)
        alertView.constrain([
            alertView.constraint(.height, constant: alertHeight + 25.0),
            alertView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 20),
            alertView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -20),
            topConstraint,
        ])
        
        //alertView.layer.borderWidth = 1
        //alertView.layer.borderColor = UIColor.white.cgColor
        
        window.layoutIfNeeded()
        
        UIView.spring(0.6, animations: {
            topConstraint?.constant = size.height / 2 - self.alertHeight / 2
            backgroundView.alpha = 1.0
            window.layoutIfNeeded()
        }, completion: { _ in
            alertView.animate()
            UIView.spring(0.6, delay: 2.0, animations: {
                topConstraint?.constant = size.height
                backgroundView.alpha = 0
                window.layoutIfNeeded()
            }, completion: { _ in
                //TODO - Make these callbacks generic
                if case .paperKeySet(let callback) = type {
                    callback()
                }
                if case .pinSet(let callback) = type {
                    callback()
                }
                if case .sweepSuccess(let callback) = type {
                    callback()
                }
                completion()
                alertView.removeFromSuperview()
                backgroundView.removeFromSuperview()
            })
        })
    }

    private func makeFaq(articleId: String? = nil) {
        //guard let supportCenter = supportCenter else { return }
        guard let supportCenter = UIStoryboard.init(name: "SupportStoryboard", bundle: Bundle.main).instantiateInitialViewController() else { return }
        supportCenter.modalPresentationStyle = .overFullScreen
        supportCenter.modalPresentationCapturesStatusBarAppearance = true
        //supportCenter.transitioningDelegate = supportCenter
        /*let url = articleId == nil ? "/support" : "/support/article?slug=\(articleId!)"
        supportCenter.navigate(to: url)*/

        topViewController?.present(supportCenter, animated: true, completion: {})
    }

    private func hamburgerMenuViewController(_ type: HamburgerMenuModal) {
        self.store.perform(action: HamburgerActions.Present(modal: .none)) // reset the state
        
        switch(type) {
            case .none:
                return
            case .securityCenter:
                return makeSecurityCenter()
            case .digiAssets(let action):
                return makeDigiAssets(action)
            case .support:
                return makeFaq()
            case .settings:
                return makeSettings()
            case .lockWallet:
                store.trigger(name: .lock)
                return
        }
    }
    
    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send:
            return makeSendView()
        case .showAddress:
            return showAddressView()
        case .showAddressBook:
            return showAddressBook()
        case .receive:
            return receiveView(isRequestAmountVisible: true)
        case .loginScan:
            return nil //The scan view needs a custom presentation
        case .loginAddress:
            return receiveView(isRequestAmountVisible: false)
        case .manageWallet:
            return ModalViewController(childViewController: ManageWalletViewController(store: store), store: store)
        case .requestAmount:
            guard let wallet = walletManager?.wallet else { return nil }
            let requestVc = RequestAmountViewController(wallet: wallet, store: store)
            requestVc.presentEmail = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMailCompose(bitcoinURL: bitcoinURL, image: image)
            }
            requestVc.presentText = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMessageCompose(bitcoinURL: bitcoinURL, image: image)
            }
            return ModalViewController(childViewController: requestVc, store: store)
        }
    }

    private func makeSendView() -> UIViewController? {
        guard !store.state.walletState.isRescanning else {
            let alert = AlertController(title: S.Alert.error, message: S.Send.isRescanning, preferredStyle: .alert)
            alert.addAction(AlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
            return nil
        }
        guard let walletManager = walletManager else { return nil }
        guard let kvStore = walletManager.apiClient?.kv else { return nil }
        let sendVC = SendViewController(store: store, sender: Sender(walletManager: walletManager, kvStore: kvStore, store: store), walletManager: walletManager, initialRequest: currentRequest)
        currentRequest = nil

        if store.state.isLoginRequired {
            sendVC.isPresentedFromLock = true
        }

        let root = ModalViewController(childViewController: sendVC, store: store)
        sendVC.presentScan = presentScan(parent: root)
        sendVC.presentVerifyPin = { [weak self, weak root] bodyText, callback in
            guard let myself = self else { return }
            let vc = VerifyPinViewController(bodyText: bodyText, pinLength: myself.store.state.pinLength, callback: callback)
            vc.transitioningDelegate = self?.verifyPinTransitionDelegate
            vc.modalPresentationStyle = .overFullScreen
            vc.modalPresentationCapturesStatusBarAppearance = true
            root?.view.isFrameChangeBlocked = true
            root?.present(vc, animated: true, completion: nil)
        }
        sendVC.onPublishSuccess = { [weak self] in
            self?.presentAlert(.sendSuccess, completion: {})
        }
        
        return root
    }

    private func receiveView(isRequestAmountVisible: Bool) -> UIViewController? {
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ReceiveViewController(wallet: wallet, store: store, isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC, store: store)
        receiveVC.presentEmail = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMailCompose(bitcoinAddress: address, image: image)
        }
        receiveVC.presentText = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMessageCompose(address: address, image: image)
        }
        return root
    }
    
    private func showAddressBook() -> UIViewController? {
        let addressBookVC = AddressBookOverviewViewController()
        
        let root = ModalViewController(childViewController: addressBookVC, store: store)
        root.scrollView.isScrollEnabled = false
        
        addressBookVC.presentScanForAdd = presentScan(parent: addressBookVC.addContactVC)
        addressBookVC.presentScanForEdit = presentScan(parent: addressBookVC.editContactVC)

        return root
    }
    
    
    
    private func showAddressView() -> UIViewController? {
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ShowAddressViewController(wallet: wallet, store: store)
        let root = ModalViewController(childViewController: receiveVC, store: store)
        receiveVC.presentEmail = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMailCompose(bitcoinAddress: address, image: image)
        }
        receiveVC.presentText = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMessageCompose(address: address, image: image)
        }
        return root
    }
    
    private func presentDigiIdScan() {
        guard let top = topViewController else { return }
        let present = presentScan(parent: top)
        store.perform(action: RootModalActions.Present(modal: .none))
        present({ digiIdUrl in
            print(digiIdUrl?.toAddress ?? "invalid")
        })
    }

    func presentLoginScan() {
        guard let top = topViewController else { return }
        let present = presentScan(parent: top)
        store.perform(action: RootModalActions.Present(modal: .none))
        present({ paymentRequest in
            guard let request = paymentRequest else { return }
            self.currentRequest = request
            self.presentModal(.send)
        })
    }
    
    private func presentLoginScanForDigiId() {
        guard let top = topViewController else { return }
        let present = presentDigiIdScan(parent: top)
        store.perform(action: RootModalActions.Present(modal: .none))
        present({ digiIdRequest in
            guard let request = digiIdRequest else { return }
            let url = URL(string: request.signString)
            
            if let signMessage = url {
                let bitId: BRDigiIDProtocol = DigiIDLegacySites.default.test(url: url) ? BRDigiIDLegacy(url: signMessage, walletManager: self.walletManager!) : BRDigiID(url: signMessage, walletManager: self.walletManager!)
                bitId.runCallback(store: self.store, { (data, response, error) in
                    if let resp = response as? HTTPURLResponse, error == nil && resp.statusCode >= 200 && resp.statusCode < 300 {
                        let senderAppInfo = getSenderAppInfo(request: request)
                        if senderAppInfo.unknownApp {
                            // we can not open the sender app again, we will just display a messagebox
                            let alert = AlertController(title: S.DigiID.success, message: nil, preferredStyle: .alert)
                            alert.addAction(AlertAction(title: S.Button.ok, style: .default, handler: nil))
                            DispatchQueue.main.async { alert.show() }
                        } else {
                            // open the sender app
                            if let u = URL(string: senderAppInfo.appURI) {
                                DispatchQueue.main.async { UIApplication.shared.open(u, options: [:], completionHandler: nil) }
                            }
                        }
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode
                        let additionalInformation = statusCode != nil ? "\(statusCode!)" : ""
                        
                        let errorInformation: String = {
                            guard let data = data else { return S.DigiID.errorMessage }
                            do {
                                // check if server gave json response in format { message: <error description> }
                                let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                                return json["message"] as! String
                            } catch {
                                // just return response as string
                                if let s = String(data: data, encoding: String.Encoding.utf8), s.count > 0 {
                                    return s
                                }
                                return S.DigiID.errorMessage
                            }
                        }()
                        
                        // show alert controller and display error description
                        let alert = AlertController(title: S.DigiID.error, message: "\(errorInformation).\n\n\(additionalInformation)", preferredStyle: .alert)
                        alert.addAction(AlertAction(title: S.Button.ok, style: .default, handler: nil))
                        DispatchQueue.main.async { alert.show() }
                    }
                })
            }
        })
    }

    private func makeSettings() {
        guard let top = topViewController else { return }
//        guard let walletManager = self.walletManager else { return }
        let settingsNav = UINavigationController()
        
        var usage: UInt = 0
        let updateImageCacheUsage = { (callback: @escaping (() -> Void)) in
            let group = DispatchGroup()
            
            group.enter()
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case .success(let size):
                    usage = size
                case .failure(let error):
                    print(error)
                    usage = 0
                }
                group.leave()
            }
            
            group.notify(queue: DispatchQueue.main) {
                print(usage)
                callback()
            }
        }
        
        updateImageCacheUsage {}
        
        var settingsVC: SettingsViewController? = nil
        
        let sections = ["Wallet", "DigiAssets", "Manage", "Advanced"]
        let rows = [
            "Wallet": [/*Setting(title: S.Settings.importTile, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let importNav = ModalNavigationController()
                    importNav.setClearNavbar()
                    importNav.setWhiteStyle()
                    let start = StartImportViewController(walletManager: walletManager, store: myself.store)
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationItem.title = S.Import.title
                // TODO: Writeup support/FAQ documentation for digibyte wallet
                    /*let faqButton = UIButton.buildFaqButton(store: myself.store, articleId: ArticleIds.importWallet)
                    faqButton.tintColor = .white
                    start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]*/
                    importNav.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        myself.topViewController?.present(importNav, animated: true, completion: nil)
                    })
                }),*/
               Setting(title: S.Settings.wipe, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let nc = ModalNavigationController()
                    nc.setClearNavbar()
                    nc.setWhiteStyle()
                    nc.delegate = myself.wipeNavigationDelegate
                    //nc.navigationBar.tintColor = .clear
                    nc.navigationBar.barTintColor = .clear
                    nc.navigationBar.isTranslucent = true
                    let start = StartWipeWalletViewController {
                        let recover = EnterPhraseViewController(store: myself.store, walletManager: walletManager, reason: .validateForWipingWallet( {
                            myself.wipeWallet()
                        }))
                        nc.pushViewController(recover, animated: true)
                    }
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationController?.navigationBar.tintColor = .clear
                    start.navigationItem.title = S.WipeWallet.title
                // TODO: Writeup support/FAQ documentation for digibyte wallet
                    /*let faqButton = UIButton.buildFaqButton(store: myself.store, articleId: ArticleIds.wipeWallet)
                    faqButton.tintColor = .white
                    start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]*/
                    nc.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        myself.topViewController?.present(nc, animated: true, completion: nil)
                    })
               })
            ],
            "Manage": [
                /*Setting(title: S.Settings.notifications, accessoryText: {
                    return self.store.state.isPushNotificationsEnabled ? S.PushNotifications.on : S.PushNotifications.off
                }, callback: {
                    settingsNav.pushViewController(PushNotificationsViewController(store: self.store), animated: true)
                }),*/
                Setting(switchWithTitle: S.Settings.maxSendEnabled, initial: UserDefaults.maxSendButtonVisible, callback: { (active) in
                    UserDefaults.maxSendButtonVisible = active
                }),
                Setting(switchWithTitle: S.Settings.excludeLogoInQR, initial: UserDefaults.excludeLogoInQR, callback: { (a) in
                    UserDefaults.excludeLogoInQR = a
                }),
//                Setting(title: LAContext.biometricType() == .face ? S.Settings.faceIdLimit : S.Settings.touchIdLimit, accessoryText: { [weak self] in
//                    guard let myself = self else { return "" }
//                    guard let rate = myself.store.state.currentRate else { return "" }
//                    let amount = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: myself.store.state.maxDigits)
//                    return amount.localCurrency
//                }, callback: {
//                    self.pushBiometricsSpendingLimit(onNc: settingsNav)
//                }),
                Setting(title: S.Settings.currency, accessoryText: { [unowned self] in
                    let code = self.store.state.defaultCurrencyCode
                    let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
                    let identifier = Locale.identifier(fromComponents: components)
                    return Locale(identifier: identifier).currencyCode ?? ""
                }, callback: {
                    guard let wm = self.walletManager else { print("NO WALLET MANAGER!"); return }
                    settingsNav.pushViewController(DefaultCurrencyViewController(walletManager: wm, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.sync, callback: {
                    settingsNav.pushViewController(ReScanViewController(store: self.store), animated: true)
                }),
//                Setting(title: S.UpdatePin.updateTitle, callback: strongify(self) { myself in
//                    let updatePin = UpdatePinViewController(store: myself.store, walletManager: walletManager, type: .update)
//                    settingsNav.pushViewController(updatePin, animated: true)
//                })
            ],
//            "DigiByte": [
//                /*Setting(title: S.Settings.shareData, callback: {
//                    settingsNav.pushViewController(ShareDataViewController(store: self.store), animated: true)
//                }),*/
//
//            ],
            
            "DigiAssets": [
                Setting(switchWithTitle: S.Settings.showRawTransactions, initial: UserDefaults.showRawTransactionsOnly, callback: { (a) in
                    UserDefaults.showRawTransactionsOnly = a
                    AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.newAssetData, object: nil) // Refresh Table View
                }),
                Setting(switchWithTitle: S.Settings.resolveAssetsWithoutPrompt, initial: UserDefaults.Privacy.automaticallyResolveAssets, callback: { (active) in
                    UserDefaults.Privacy.automaticallyResolveAssets = active
                }),
                
                Setting(title: S.Settings.clearAssetCache, callback: { [weak self] in
                    AssetHelper.reset()
                    self?.showLightWeightAlert(message: S.Settings.cacheCleared)
                }),
                
                Setting(title: S.Settings.clearImageCache, accessoryText: {
                    let calc = Double(usage) / 1024 / 1024
                    let rounded = round(calc * 1000.0) / 1000
                    return "\(rounded) MB"
                }, callback: { [weak self] in
                    let cache = ImageCache.default
                    cache.clearMemoryCache()
                    cache.clearDiskCache {
                        self?.showLightWeightAlert(message: S.Settings.cacheCleared)
                        updateImageCacheUsage {
                            settingsVC?.tableView.reloadData()
                        }
                    }
                }),
            ],
            
            "Advanced": [
                Setting(title: S.Settings.advancedTitle, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    guard let store = self?.store else { return }
                    let sections = ["Network"]
                    let advancedSettings = [
                        "Network": [
                            Setting(title: S.Settings.nodes, callback: {
                                let nodeSelector = NodeSelectorViewController(walletManager: walletManager, store: store)
                                settingsNav.pushViewController(nodeSelector, animated: true)
                            }),
                            Setting(title: S.Settings.useDigiIDLegacy, accessoryText: { () -> String in
                                let count = DigiIDLegacySites.default.sites.count
                                return String(format: S.WritePaperPhrase.step, count)
                            }, callback: {
                                let vc = DigiIDExceptionViewController()
                                vc.presentScan = myself.presentDigiIdScan(parent: vc)
                                settingsNav.pushViewController(vc, animated: true)
                                
                                DispatchQueue.main.async {
                                    self?.showLightWeightWarning(message: S.Settings.digiIdLegacyWarning)
                                }
                            })
                            /*,
                            
                            Setting(title: S.BCH.title, callback: {
                                let bCash = BCashTransactionViewController(walletManager: walletManager, store: myself.store)
                                settingsNav.pushViewController(bCash, animated: true)
                            })*/
                        ]
                    ]

                    let advancedSettingsVC = SettingsViewController(sections: sections, rows: advancedSettings, optionalTitle: S.Settings.advancedTitle)
                    settingsNav.pushViewController(advancedSettingsVC, animated: true)
                }),
                
                Setting(title: S.MenuButton.support, callback: {
                    let screenName =  "DGBSupport"
                    let appURL = URL(string: "tg://resolve?domain=\(screenName)")!
                    let webURL = URL(string: "https://dgbsupport.digiassetx.com")!
                    
                    if UIApplication.shared.canOpenURL(webURL as URL) {
                        UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                    }
                }),
                
                Setting(title: S.Settings.about, callback: {
                    settingsNav.pushViewController(AboutViewController(), animated: true)
                })
            ]
        ]
        
        /*rows["DigiByte"]?.append( Setting(title: S.Settings.review, callback: {
                let alert = AlertController(title: S.Settings.review, message: S.Settings.enjoying, preferredStyle: .alert)
                alert.addAction(AlertAction(title: S.Button.no, style: .default, handler: { _ in
                    self.messagePresenter.presenter = self.topViewController
                    self.messagePresenter.presentFeedbackCompose()
                }))
                alert.addAction(AlertAction(title: S.Button.yes, style: .default, handler: { _ in
                    if let url = URL(string: C.reviewLink) {
                        UIApplication.shared.openURL(url)
                    }
                }))
                self.topViewController?.present(alert, animated: true, completion: nil)
            })
        )*/

        let settings = SettingsViewController(sections: sections, rows: rows)
        settingsVC = settings
    
        settings.addCloseNavigationItem(tintColor: .white)
        settingsNav.viewControllers = [settings]
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = C.Colors.background
        settingsNav.navigationBar.setBackgroundImage(view.imageRepresentation, for: .default)
        settingsNav.navigationBar.shadowImage = UIImage()
        settingsNav.navigationBar.isTranslucent = true
        settingsNav.setTintableBackArrow()
        settingsNav.navigationBar.tintColor = .white
        top.present(settingsNav, animated: true, completion: nil)
    }
    
    func presentScan(parent: UIViewController) -> PresentScan {
        return { [weak parent] scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                //self.saveEvent("scan.cameraDenied")
                if let parent = parent {
                    ScanViewController.presentCameraUnavailableAlert(fromRoot: parent)
                }
                return
            }
            let vc = ScanViewController(completion: { paymentRequest in
                scanCompletion(paymentRequest)
                parent?.view.isFrameChangeBlocked = false
            }, isValidURI: { address in
                return address.isValidAddress
            })
            parent?.view.isFrameChangeBlocked = true
            parent?.present(vc, animated: true, completion: {})
        }
    }
    
    private func presentDigiIdScan(parent: UIViewController) -> PresentDigiIdScan {
        return { [weak parent] scanCompletion in
            // check whether camera privileges are available
            guard ScanViewController.isCameraAllowed else {
                if let parent = parent {
                    ScanViewController.presentCameraUnavailableAlert(fromRoot: parent)
                }
                return
            }

            // open scanner
            let vc = ScanViewController(digiIdCompletion: { digiIdRequest in
                scanCompletion(digiIdRequest)
                parent?.view.isFrameChangeBlocked = false
            }, isValidURI: { address in            
                return address.isValidAddress
            })
            parent?.view.isFrameChangeBlocked = true
            parent?.present(vc, animated: true, completion: {})
        }
    }
    
    private func makeDigiAssets(_ action: AssetMenuAction? = nil) {
        guard let walletManager = walletManager else { return }
        
        let digiAssetsViewController = DAMainViewController(store: store, walletManager: walletManager, action: action)
        var nextVC: UIViewController!
        
        if !UserDefaults.digiAssetsOnboardingShown {
            // Onboarding shall be displayed.
            // After user has finished introduction, we will display the
            // main DigiAssets view controller
            let onboarding = DAOnboardingViewController()
            nextVC = onboarding
            onboarding.nextVC = digiAssetsViewController
        } else {
            // Directly display the main view controller for DigiAssets
            nextVC = digiAssetsViewController
        }
        
        let nc = ModalNavigationController(rootViewController: nextVC)
        nc.setDefaultStyle()
        nc.setWhiteStyle()
        nc.isNavigationBarHidden = true
        
        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    private func makeSecurityCenter() {
        guard let walletManager = walletManager else { return }
        let securityCenter = SecurityCenterViewController(store: store, walletManager: walletManager)
        let nc = ModalNavigationController(rootViewController: securityCenter)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        securityCenter.didTapPin = { [weak self] in
            guard let myself = self else { return }
            let updatePin = UpdatePinViewController(store: myself.store, walletManager: walletManager, type: .update)
            nc.pushViewController(updatePin, animated: true)
        }
        securityCenter.didTapBiometrics = strongify(self) { myself in
            let biometricsSettings = BiometricsSettingsViewController(walletManager: walletManager, store: myself.store)
            biometricsSettings.presentSpendingLimit = {
                myself.pushBiometricsSpendingLimit(onNc: nc)
            }
            nc.pushViewController(biometricsSettings, animated: true)
        }
        securityCenter.didTapPaperKey = { [weak self] in
            self?.presentWritePaperKey(fromViewController: nc)
        }

        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    private func pushBiometricsSpendingLimit(onNc: UINavigationController) {
        guard let walletManager = walletManager else { return }

        let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: store.state.pinLength, callback: { [weak self] pin, vc in
            guard let myself = self else { return false }
            if walletManager.authenticate(pin: pin) {
                vc.dismiss(animated: true, completion: {
                    let spendingLimit = BiometricsSpendingLimitViewController(walletManager: walletManager, store: myself.store)
                    onNc.pushViewController(spendingLimit, animated: true)
                })
                return true
            } else {
                return false
            }
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        onNc.present(verify, animated: true, completion: nil)
    }

    private func presentWritePaperKey(fromViewController vc: UIViewController) {
        guard let walletManager = walletManager else { return }
        let paperPhraseNavigationController = UINavigationController()
        paperPhraseNavigationController.setClearNavbar()
        paperPhraseNavigationController.setWhiteStyle()
        paperPhraseNavigationController.modalPresentationStyle = .overFullScreen
        let start = StartPaperPhraseViewController(store: store, callback: { [weak self] in
            guard let myself = self else { return }
            let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: myself.store.state.pinLength, callback: { pin, vc in
                if walletManager.authenticate(pin: pin) {
                    var write: WritePaperPhraseViewController?
                    write = WritePaperPhraseViewController(store: myself.store, walletManager: walletManager, pin: pin, callback: { [weak self] in
                        guard let myself = self else { return }
                        var confirm: ConfirmPaperPhraseViewController?
                        confirm = ConfirmPaperPhraseViewController(store: myself.store, walletManager: walletManager, pin: pin, callback: {
                                confirm?.dismiss(animated: true, completion: {
                                    myself.store.perform(action: Alert.Show(.paperKeySet(callback: {
                                        myself.store.perform(action: HideStartFlow())
                                    })))
                            })
                        })
                        write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
                        if let confirm = confirm {
                            paperPhraseNavigationController.pushViewController(confirm, animated: true)
                        }
                    })
                    write?.addCloseNavigationItem(tintColor: .white)
                    write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle

                    vc.dismiss(animated: true, completion: {
                        guard let write = write else { return }
                        paperPhraseNavigationController.pushViewController(write, animated: true)
                    })
                    return true
                } else {
                    return false
                }
            })
            verify.transitioningDelegate = self?.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            paperPhraseNavigationController.present(verify, animated: true, completion: nil)
        })
        start.addCloseNavigationItem(tintColor: .white)
        start.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
        // TODO: Writeup support/FAQ documentation for digibyte wallet
        /*let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.paperKey)
        faqButton.tintColor = .white
        start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]*/
        paperPhraseNavigationController.viewControllers = [start]
        vc.present(paperPhraseNavigationController, animated: true, completion: nil)
    }

    private func presentRescan() {
        let vc = ReScanViewController(store: self.store)
        let nc = UINavigationController(rootViewController: vc)
        nc.setClearNavbar()
        vc.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    func wipeWallet() {
        let alert = AlertController(title: S.WipeWallet.alertTitle, message: S.WipeWallet.alertMessage, preferredStyle: .alert)
        alert.addAction(AlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(AlertAction(title: S.WipeWallet.wipe, style: .default, handler: { _ in
            self.topViewController?.dismiss(animated: true, completion: {
                let activity = BRActivityViewController(message: S.WipeWallet.wiping)
                self.topViewController?.present(activity, animated: true, completion: nil)
                DispatchQueue.walletQueue.async {
                    self.walletManager?.peerManager?.disconnect()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                        activity.dismiss(animated: true, completion: {
                            if (self.walletManager?.wipeWallet(pin: "forceWipe"))! {
                                self.store.trigger(name: .reinitWalletManager({}))
                            } else {
                                let failure = AlertController(title: S.WipeWallet.failedTitle, message: S.WipeWallet.failedMessage, preferredStyle: .alert)
                                failure.addAction(AlertAction(title: S.Button.ok, style: .default, handler: nil))
                                self.topViewController?.present(failure, animated: true, completion: nil)
                            }
                        })
                    })
                }
            })
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    //MARK: - Prompts
    func presentBiometricsSetting() {
        guard let walletManager = walletManager else { return }
        let biometricsSettings = BiometricsSettingsViewController(walletManager: walletManager, store: store)
        biometricsSettings.addCloseNavigationItem(tintColor: .white)
        let nc = ModalNavigationController(rootViewController: biometricsSettings)
        biometricsSettings.presentSpendingLimit = strongify(self) { myself in
            myself.pushBiometricsSpendingLimit(onNc: nc)
        }
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.navigationBar.isTranslucent = true
        nc.delegate = securityCenterNavigationDelegate
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func promptShareData() {
        let shareData = ShareDataViewController(store: store)
        let nc = ModalNavigationController(rootViewController: shareData)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        shareData.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    func presentWritePaperKey() {
        guard let vc = topViewController else { return }
        presentWritePaperKey(fromViewController: vc)
    }

    func presentUpgradePin() {
        guard let walletManager = walletManager else { return }
        let updatePin = UpdatePinViewController(store: store, walletManager: walletManager, type: .update)
        let nc = ModalNavigationController(rootViewController: updatePin)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        updatePin.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func handleFile(_ file: Data) {
        if let request = PaymentProtocolRequest(data: file) {
            if let topVC = topViewController as? ModalViewController {
                let attemptConfirmRequest: () -> Bool = {
                    if let send = topVC.childViewController as? SendViewController {
                        send.confirmProtocolRequest(protoReq: request)
                        return true
                    }
                    return false
                }
                if !attemptConfirmRequest() {
                    modalTransitionDelegate.reset()
                    topVC.dismiss(animated: true, completion: {
                        self.store.perform(action: RootModalActions.Present(modal: .send))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { //This is a hack because present has no callback
                            let _ = attemptConfirmRequest()
                        })
                    })
                }
            }
        } else if let ack = PaymentProtocolACK(data: file) {
            if let memo = ack.memo {
                let alert = AlertController(title: "", message: memo, preferredStyle: .alert)
                alert.addAction(AlertAction(title: S.Button.ok, style: .cancel, handler: nil))
                topViewController?.present(alert, animated: true, completion: nil)
            }
        //TODO - handle payment type
        } else {
            let alert = AlertController(title: S.Alert.error, message: S.PaymentProtocol.Errors.corruptedDocument, preferredStyle: .alert)
            alert.addAction(AlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
        }
    }

    private func handlePaymentRequest(request: PaymentRequest) {
        self.currentRequest = request
        guard !store.state.isLoginRequired else { presentModal(.send); return }

        if topViewController is AccountViewController {
            presentModal(.send)
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    self.presentModal(.send)
                })
            }
        }
    }
    
    

    private func handleScanQrURL() {
        guard !store.state.isLoginRequired else { presentLoginScan(); return }
        
        if topViewController is AccountViewController || topViewController is LoginViewController {
            presentLoginScan()
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    self.presentLoginScan()
                })
            }
        }
    }
    
    private func handleDigiIdScanQrURL() {
        guard !store.state.isLoginRequired else { presentLoginScanForDigiId(); return }
        
        if topViewController is AccountViewController || topViewController is LoginViewController {
            presentLoginScanForDigiId()
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    self.presentLoginScanForDigiId()
                })
            }
        }
    }

    private func handleCopyAddresses(success: String?, error: String?) {
        guard let walletManager = walletManager else { return }
        let alert = AlertController(title: S.URLHandling.addressListAlertTitle, message: S.URLHandling.addressListAlertMessage, preferredStyle: .alert)
        alert.addAction(AlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(AlertAction(title: S.URLHandling.copy, style: .default, handler: { [weak self] _ in
            guard let myself = self else { return }
            let verify = VerifyPinViewController(bodyText: S.URLHandling.addressListVerifyPrompt, pinLength: myself.store.state.pinLength, callback: { [weak self] pin, view in
                if walletManager.authenticate(pin: pin) {
                    self?.copyAllAddressesToClipboard()
                    view.dismiss(animated: true, completion: {
                        self?.store.perform(action: Alert.Show(.addressesCopied))
                        if let success = success, let url = URL(string: success) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    })
                    return true
                } else {
                    return false
                }
            })
            verify.transitioningDelegate = self?.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            self?.topViewController?.present(verify, animated: true, completion: nil)
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func authenticateForBitId(prompt: String, callback: @escaping (BitIdAuthResult) -> Void) {
        if UserDefaults.isBiometricsEnabled {
            walletManager?.authenticate(biometricsPrompt: prompt, isDigiIDAuth: true, completion: { result in
                switch result {
                case .success:
                    return callback(.success)
                case .cancel:
                    return callback(.cancelled)
                case .failure:
                    self.verifyPinForBitId(prompt: prompt, callback: callback)
                case .fallback:
                    self.verifyPinForBitId(prompt: prompt, callback: callback)
                }
            })
        } else {
            self.verifyPinForBitId(prompt: prompt, callback: callback)
        }
    }

    private func verifyPinForBitId(prompt: String, callback: @escaping (BitIdAuthResult) -> Void) {
        guard let walletManager = walletManager else { return }
        let verify = VerifyPinViewController(bodyText: prompt, pinLength: store.state.pinLength, callback: { pin, view in
            if walletManager.authenticate(pin: pin) {
                view.dismiss(animated: true, completion: {
                    callback(.success)
                })
                return true
            } else {
                return false
            }
        })
        verify.didCancel = { callback(.cancelled) }
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        topViewController?.present(verify, animated: true, completion: nil)
    }

    private func copyAllAddressesToClipboard() {
        guard let wallet = walletManager?.wallet else { return }
        let addresses = wallet.allAddresses.filter({wallet.addressIsUsed($0)})
        UIPasteboard.general.string = addresses.joined(separator: "\n")
    }

    private var topViewController: UIViewController? {
        var viewController = window.rootViewController
        while viewController?.presentedViewController != nil {
            viewController = viewController?.presentedViewController
        }
        return viewController
    }

    private func showNotReachable() {
        guard notReachableAlert == nil else { return }
        let alert = InAppAlert(message: S.Alert.noInternet, image: UIImage(named: "BrokenCloud")!)
        notReachableAlert = alert
        let window = UIApplication.shared.keyWindow!
        let size = window.bounds.size
        window.addSubview(alert)
        let bottomConstraint = alert.bottomAnchor.constraint(equalTo: window.topAnchor, constant: 0.0)
        alert.constrain([
            alert.constraint(.width, constant: size.width),
            alert.constraint(.height, constant: InAppAlert.height),
            alert.constraint(.leading, toView: window, constant: nil),
            bottomConstraint ])
        window.layoutIfNeeded()
        alert.bottomConstraint = bottomConstraint
        alert.hide = {
            self.hideNotReachable()
        }
        UIView.spring(C.animationDuration, animations: {
            alert.bottomConstraint?.constant = InAppAlert.height
            window.layoutIfNeeded()
        }, completion: {_ in})
    }

    private func hideNotReachable() {
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.notReachableAlert?.bottomConstraint?.constant = 0.0
            self.notReachableAlert?.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.notReachableAlert?.removeFromSuperview()
            self.notReachableAlert = nil
        })
    }

    private func showLightWeightAlert(message: String) {
        let alert = LightWeightAlert(message: message)
        let view = UIApplication.shared.keyWindow!
        view.addSubview(alert)
        alert.constrain([
            alert.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alert.centerYAnchor.constraint(equalTo: view.centerYAnchor) ])
        alert.alpha = 0
        UIView.animate(withDuration: 0.6, animations: {
            alert.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.6, delay: 2.0, options: [], animations: {
                alert.alpha = 0
            }, completion: { _ in
                alert.removeFromSuperview()
            })
        })
    }
    
    private func showLightWeightWarning(message: String) {
        let alert = LightWeightAlert(message: message)
        alert.container.backgroundColor = C.Colors.favoriteYellow
        let view = UIApplication.shared.keyWindow!
        view.addSubview(alert)
        alert.constrain([
            alert.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alert.centerYAnchor.constraint(equalTo: view.centerYAnchor) ])
        alert.alpha = 0
        UIView.animate(withDuration: 0.6, animations: {
            alert.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.6, delay: 2.0, options: [], animations: {
                alert.alpha = 0
            }, completion: { _ in
                alert.removeFromSuperview()
            })
        })
    }
}

class SecurityCenterNavigationDelegate : NSObject, UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        guard let coordinator = navigationController.topViewController?.transitionCoordinator else { return }

        if coordinator.isInteractive {
            coordinator.notifyWhenInteractionChanges { context in
                //We only want to style the view controller if the
                //pop animation wasn't cancelled
                if !context.isCancelled {
                    self.setStyle(navigationController: navigationController, viewController: viewController)
                }
            }
        } else {
            setStyle(navigationController: navigationController, viewController: viewController)
        }
    }

    func setStyle(navigationController: UINavigationController, viewController: UIViewController) {
        if viewController is SecurityCenterViewController {
            navigationController.isNavigationBarHidden = true
        } else if viewController is DAOnboardingViewController {
            navigationController.isNavigationBarHidden = true
        } else {
            navigationController.isNavigationBarHidden = false
        }

        if viewController is BiometricsSettingsViewController {
            navigationController.setWhiteStyle()
        } else {
            navigationController.setDefaultStyle()
        }
    }
}
