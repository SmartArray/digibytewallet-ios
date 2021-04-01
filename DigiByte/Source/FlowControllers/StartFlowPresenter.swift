//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowPresenter : Subscriber {

    //MARK: - Public
    init(store: BRStore, walletManager: WalletManager, rootViewController: UIViewController) {
        self.store = store
        self.walletManager = walletManager
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate(store: store)
        addSubscriptions()
    }

    //MARK: - Private
    private let store: BRStore
    private let rootViewController: UIViewController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let walletManager: WalletManager
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()

    private var closeButton: UIButton {
        let button = UIButton.close
        button.tintColor = .white
        button.tap = { [weak self] in
            self?.store.perform(action: HideStartFlow())
        }
        return button
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
                        callback: { self.handleStartFlowChange(state: $0) })
        store.lazySubscribe(self,
                        selector: { $0.isLoginRequired != $1.isLoginRequired },
                        callback: {
                            self.handleLoginRequiredChange(state: $0)
        }) //TODO - this should probably be in modal presenter
        store.subscribe(self, name: .lock, callback: { _ in
            self.presentLoginFlow(isPresentedForLock: true)
        })
    }

    private func handleStartFlowChange(state: State) {
        if state.isStartFlowVisible {
            guardProtected(queue: DispatchQueue.main) { [weak self] in
                self?.presentStartFlow()
            }
        } else {
            dismissStartFlow()
        }
    }

    private func handleLoginRequiredChange(state: State) {
        if state.isLoginRequired {
            presentLoginFlow(isPresentedForLock: false)
        } else {
            dismissLoginFlow()
        }
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(
            store: store,
            didTapCreate: { [weak self] in
                self?.pushPinCreationViewControllerForNewWallet()
            },
            didTapRecover: { [weak self] in
                guard let myself = self else { return }
                
                // ToDo: redesign recover intro
                // let recoverIntro = RecoverWalletIntroViewController(didTapNext: myself.pushRecoverWalletView)
                // myself.navigationController?.setTintableBackArrow()
                // myself.navigationController?.setClearNavbar()
                // myself.navigationController?.setNavigationBarHidden(false, animated: false)
                // myself.navigationController?.pushViewController(recoverIntro, animated: true)
                myself.navigationController?.setNavigationBarHidden(false, animated: false)
                myself.navigationController?.navigationBar.tintColor = UIColor.white
                myself.navigationController?.setTintableBackArrow()
                myself.navigationController?.setClearNavbar()
                myself.pushRecoverWalletView()
            }
        )
        
        navigationController = ModalNavigationController()
        navigationController?.delegate = navigationControllerDelegate
        if #available(iOS 13.0, *) {
            navigationController?.isModalInPresentation = true
            navigationController?.modalPresentationStyle = .fullScreen
        }
        
        if walletManager.wallet == nil {
            let welcome = WelcomeViewController {
                self.navigationController?.setViewControllers([startViewController], animated: true)
                UserDefaults.hasShownWelcome = true
            }
            navigationController?.setViewControllers([welcome], animated: false)

        } else {
            navigationController?.setViewControllers([startViewController], animated: false)
        }

        if let startFlow = navigationController {
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
        }
    }

    private var pushRecoverWalletView: () -> Void {
        return { [weak self] in
            guard let myself = self else { return }
            let recoverWalletViewController = EnterPhraseViewController(
                store: myself.store,
                walletManager: myself.walletManager,
                reason: .setSeed(myself.pushPinCreationViewForRecoveredWallet)
            )
            myself.navigationController?.pushViewController(recoverWalletViewController, animated: true)
        }
    }

    private var pushPinCreationViewForRecoveredWallet: (String) -> Void {
        return { [weak self] phrase in
            guard let myself = self else { return }
            
            // Show privacy window
            let wnd = DGBConfirmAlert(title: "Fast sync", message: "This wallet can communicate with a blockexplorer. Note that this will leak some public wallet addresses in order to speed up the sync.", image: UIImage(named: "privacy"), okTitle: "Fast sync", cancelTitle: nil, alternativeButtonTitle: "Regular sync (slow)")
            
            wnd.confirmCallback = { (close: DGBCallback) in
                let pinCreationView = UpdatePinViewController(store: myself.store, walletManager: myself.walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
                
                pinCreationView.setPinSuccess = { _ in
                    UserDefaults.fastSyncEnabled = true
                    
                    let req = FirstBlockWithWalletTxRequest(myself.walletManager.wallet!.allAddressesLimited(limit: 20), useBestBlockAlternatively: true, completion: { (success, hash, height, timestamp) in
                        
                        if success && height > 0 && timestamp > 0 {
                            // set first block to start from
                            myself.walletManager.startBlock = StartBlock(hash: hash, timestamp: timestamp, startHeight: height)
                        }
                        
                        DispatchQueue.main.async {
                            myself.store.perform(action: WalletChange.setSyncingState(.connecting))
                        }
                        
                        DispatchQueue.walletQueue.async {
                            myself.walletManager.peerManager?.connect()
                            DispatchQueue.main.async {
                                myself.store.trigger(name: .didCreateOrRecoverWallet)
                            }
                        }
                    })
                
                    req.start()
                }
                
                close()
                myself.navigationController?.pushViewController(pinCreationView, animated: true)
            }
            
            wnd.alternativeCallback = { (close: DGBCallback) in
                UserDefaults.fastSyncEnabled = false
                
                let pinCreationView = UpdatePinViewController(store: myself.store, walletManager: myself.walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
                
                pinCreationView.setPinSuccess = { _ in
                    // Regular sync
                    DispatchQueue.main.async {
                        myself.store.perform(action: WalletChange.setSyncingState(.connecting))
                    }
                    
                    DispatchQueue.walletQueue.async {
                        myself.walletManager.peerManager?.connect()
                        DispatchQueue.main.async {
                            myself.store.trigger(name: .didCreateOrRecoverWallet)
                        }
                    }
                }
                
                close()
                myself.navigationController?.pushViewController(pinCreationView, animated: true)
            }
            
            myself.navigationController?.present(wnd, animated: true, completion: nil)
        }
    }

    private func dismissStartFlow() {
        navigationController?.dismiss(animated: true) { [weak self] in
            self?.navigationController = nil
        }
    }
    
    private var blockReq: BestBlockRequest? = nil

    private func pushPinCreationViewControllerForNewWallet() {
        let pinCreationViewController = UpdatePinViewController(store: store, walletManager: walletManager, type: .creationNoPhrase, showsBackButton: true, phrase: nil)
        pinCreationViewController.setPinSuccess = { [weak self] pin in
            autoreleasepool {
                guard self?.walletManager.setRandomSeedPhrase() != nil else { self?.handleWalletCreationError(); return }
            }
            
            // Determine the best block of the blockchain
            self?.blockReq = BestBlockRequest(completion: { (success, blockHash, blockHeight, blockDate) in
                if success && blockDate > 0 && blockHeight > 0 {
                    self?.walletManager.startBlock = StartBlock(hash: blockHash, timestamp: blockDate, startHeight: blockHeight)
                }
                
                self?.blockReq = nil
                
                self?.store.perform(action: WalletChange.setWalletCreationDate(Date()))
                
                DispatchQueue.main.async {
                    self?.store.perform(action: WalletChange.setSyncingState(.connecting))
                }
                
                DispatchQueue.walletQueue.async {
                    self?.walletManager.peerManager?.connect()
                    DispatchQueue.main.async {
                        self?.pushStartPaperPhraseCreationViewController(pin: pin)
                        self?.store.trigger(name: .didCreateOrRecoverWallet)
                    }
                }
            })
        }

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setTintableBackArrow()
        navigationController?.setClearNavbar()
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func handleWalletCreationError() {
        let alert = AlertController(title: S.Alert.error, message: "Could not create wallet", preferredStyle: .alert)
        alert.addAction(AlertAction(title: S.Button.ok, style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func pushStartPaperPhraseCreationViewController(pin: String) {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store, callback: { [weak self] in
            self?.pushWritePaperPhraseViewController(pin: pin)
        })
        paperPhraseViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        paperPhraseViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]

        // TODO: Writeup support/FAQ documentation for digibyte wallet
        /*let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.paperKey)
        faqButton.tintColor = .white
        paperPhraseViewController.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]*/

        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.customBold(size: 17.0)
        ]
        navigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController(pin: String) {
        let writeViewController = WritePaperPhraseViewController(store: store, walletManager: walletManager, pin: pin, callback: { [weak self] in
            self?.pushConfirmPaperPhraseViewController(pin: pin)
        })
        writeViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        writeViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController(pin: String) {
        let confirmViewController = ConfirmPaperPhraseViewController(store: store, walletManager: walletManager, pin: pin, callback: { [weak self] in
            guard let myself = self else { return }
            myself.store.perform(action: Alert.Show(.paperKeySet(callback: {
                self?.store.perform(action: HideStartFlow())
            })))
        })
        confirmViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        navigationController?.navigationBar.tintColor = .white
        navigationController?.pushViewController(confirmViewController, animated: true)
    }

    private func presentLoginFlow(isPresentedForLock: Bool) {
        let loginView = LoginViewController(store: store, isPresentedForLock: isPresentedForLock, walletManager: walletManager)
        if isPresentedForLock {
            loginView.shouldSelfDismiss = true
        }
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginView.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = loginView
        rootViewController.present(loginView, animated: false, completion: nil)

        /*
        let pin = UpdatePinViewController(store: store, walletManager: walletManager, type: .update, showsBackButton: false, phrase: "Enter your PIN")
        pin.transitioningDelegate = loginTransitionDelegate
        pin.modalPresentationStyle = .overFullScreen
        pin.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = pin
        rootViewController.present(pin, animated: false, completion: nil)
         */
    }

    private func dismissLoginFlow() {
        loginViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.loginViewController = nil
        })
    }
}
