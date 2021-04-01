//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController : Subscriber, Trackable {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    fileprivate let store = BRStore()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    fileprivate var walletManager: WalletManager?
    private var walletCoordinator: WalletCoordinator?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate: ModalTransitionDelegate
    private var kvStoreCoordinator: KVStoreCoordinator?
    private var accountViewController: AccountViewController?
    fileprivate var application: UIApplication?
    private let watchSessionManager = PhoneWCSessionManager()
    private var urlController: URLController?
    private var defaultsUpdater: UserDefaultsUpdater?
    private var reachability = ReachabilityMonitor()
    private let noAuthApiClient = BRAPIClient(authenticator: NoAuthAuthenticator())
    private var fetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var launchURL: URL?
    private var hasPerformedWalletDependentInitialization = false
    private var didInitWallet = false

    init() {
        transitionDelegate = ModalTransitionDelegate(type: .transactionDetail, store: store)
        DispatchQueue.walletQueue.async {
            guardProtected(queue: DispatchQueue.walletQueue) {
                self.initWallet()
            }
        }
    }
    
    private func defaultInitWallet() {
        DispatchQueue.main.async {
            self.didInitWallet = true
            if !self.hasPerformedWalletDependentInitialization {
                self.didInitWalletManager()
            }
        }
    }
    
    private var blockReq: FirstBlockWithWalletTxRequest? = nil
    
    func firstBlockSyncInit(_ w: BRWallet) {
        print("No blocks in database found. Trying to fetch first block of interest to start the sync at.")
        blockReq = FirstBlockWithWalletTxRequest(w.allAddressesLimited(limit: 20), useBestBlockAlternatively: true, completion: { [weak self] (success, hash, height, timestamp) in
            if success && timestamp != 0 && height > 0 {
                guard let walletManager = self?.walletManager else { return }
                
                // set first block to start from
                let start = StartBlock(hash: hash, timestamp: timestamp, startHeight: height)
                walletManager.startBlock = start
                
                // Make the start block persistent (to safely continue after reboot)
                walletManager.saveBlocks(true, [walletManager.generateMerkleBlock(s: start)])
            }
            
            self?.blockReq = nil
            
            self?.defaultInitWallet()
        })
        
        blockReq!.start()
    }
    
    private func initWallet() {
        self.walletManager = try? WalletManager(store: self.store, dbPath: nil)
        
//        walletManager!.wipeWallet(pin: "forceWipe")
//        exit(0)
        
        var firstInit = false
        var wallet: BRWallet?
        
        // attempt to initialize wallet
        if let w = self.walletManager?.wallet {
            if self.walletManager?.loadBlocks().count == 0 {
                // first sync
                firstInit = true
                wallet = w
            }
        }
        
        if firstInit, UserDefaults.fastSyncEnabled {
            firstBlockSyncInit(wallet!)
        } else {
            // Just start or resume the sync
            defaultInitWallet()
        }
    }

    func launch(application: UIApplication, options: [UIApplication.LaunchOptionsKey: Any]?) {
        self.application = application
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        setup()
        handleLaunchOptions(options)
        reachability.didChange = { isReachable in
            if !isReachable {
                self.reachability.didChange = { isReachable in
                    if isReachable {
                        self.retryAfterIsReachable()
                    }
                }
            }
        }
		//TODO: If DigiByte plans to create a NUXT based support app inside the wallet, we'll need to update this
		// in order to keep the NUXT asset bundle up to date.
        //updateAssetBundles()
        if !hasPerformedWalletDependentInitialization && didInitWallet {
            didInitWalletManager()
        }

    }

    private func setup() {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        listenForPushNotificationRequest()
        offMainInitialization()
        
        #if Debug
        if (false) {
            DispatchQueue.main.async {
                self.modalPresenter?.presentAlert(AlertType.pinSet(callback: {
                    print(1111)
                }), completion: {
                    print(2222)
                })
            }
        }
        #endif
        
        store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard let trigger = $0 else { return }
            if case .reinitWalletManager(let callback) = trigger {
                if let callback = callback {
                    self.store.removeAllSubscriptions()
                    self.store.perform(action: Reset())
                    self.setup()
                    DispatchQueue.walletQueue.async {
                        do {
                            self.walletManager = try WalletManager(store: self.store, dbPath: nil)
                            let _ = self.walletManager?.wallet //attempt to initialize wallet
                        } catch let error {
                            assert(false, "Error creating new wallet: \(error)")
                        }
                        DispatchQueue.main.async {
                            self.didInitWalletManager()
                            callback()
                        }
                    }
                }
            }
        })
    }

    func willEnterForeground() {
        guard let walletManager = walletManager else { return }
        guard !walletManager.noWallet else { return }
        if shouldRequireLogin() {
            store.perform(action: RequireLogin())
        }
        
        DispatchQueue.main.async {
            self.store.perform(action: WalletChange.setSyncingState(.connecting))
        }
        
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdater?.refresh(completion: {})
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func retryAfterIsReachable() {
        guard let walletManager = walletManager else { return }
        guard !walletManager.noWallet else { return }
        
        DispatchQueue.main.async {
            self.store.perform(action: WalletChange.setSyncingState(.connecting))
        }
        
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        
        exchangeUpdater?.refresh(completion: {})
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func didEnterBackground() {
        senderApp = "" // reset sender App
        
        if store.state.walletState.syncState == .success {
            DispatchQueue.walletQueue.async {
                self.walletManager?.peerManager?.disconnect()
            }
        }
        //Save the backgrounding time if the user is logged in
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        walletManager?.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fetchCompletionHandler = completionHandler
    }

    func open(url: URL) -> Bool {
        if let urlController = urlController {
            return urlController.handleUrl(url)
        } else {
            launchURL = url
            return false
        }
    }

    private func didInitWalletManager() {
        guard let walletManager = walletManager else { assert(false, "WalletManager should exist!"); return }
        guard let rootViewController = window.rootViewController else { return }
        hasPerformedWalletDependentInitialization = true
        store.perform(action: PinLength.set(walletManager.pinLength))
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        modalPresenter = ModalPresenter(store: store, walletManager: walletManager, window: window, apiClient: noAuthApiClient)
        exchangeUpdater = ExchangeUpdater(store: store, walletManager: walletManager)
        feeUpdater = FeeUpdater(walletManager: walletManager, store: store)
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: rootViewController)
        accountViewController?.walletManager = walletManager
        accountViewController?.kvStore = walletManager.apiClient?.kv
        defaultsUpdater = UserDefaultsUpdater(walletManager: walletManager)
        urlController = URLController(store: self.store, walletManager: walletManager)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }
        
        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                // UserDefaults.hasShownWelcome = true
                addWalletCreationListener()
                store.perform(action: ShowStartFlow())
            } else {
                modalPresenter?.walletManager = walletManager
                DispatchQueue.main.async {
                    self.store.perform(action: WalletChange.setSyncingState(.connecting))
                }
                
                DispatchQueue.walletQueue.async {
                    walletManager.peerManager?.connect()
                }
                self.startDataFetchers()
            }

        //For when watch app launches app in background
        } else {
            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.setSyncingState(.connecting))
            }
            
            DispatchQueue.walletQueue.async { [weak self] in
                walletManager.peerManager?.connect()
                if self?.fetchCompletionHandler != nil {
                    self?.performBackgroundFetch()
                }
            }
            exchangeUpdater?.refresh(completion: {
                self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = self.store.state.currentRate
            })
        }
    }

    private func shouldRequireLogin() -> Bool {
        let then = UserDefaults.standard.double(forKey: timeSinceLastExitKey)
        let timeout = UserDefaults.standard.double(forKey: shouldRequireLoginTimeoutKey)
        let now = Date().timeIntervalSince1970
        return now - then > timeout
    }

    private func setupDefaults() {
        if UserDefaults.standard.object(forKey: shouldRequireLoginTimeoutKey) == nil {
            UserDefaults.standard.set(60.0*3.0, forKey: shouldRequireLoginTimeoutKey) //Default 3 min timeout
        }
    }

    private func setupAppearance() {
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font: UIFont.header]
        //Hack to globally hide the back button text
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -500.0, vertical: -500.0), for: .default)
    }

    private func setupRootViewController() {
        let didSelectTransaction: ([Transaction], Int) -> Void = { transactions, selectedIndex in
            guard let kvStore = self.walletManager?.apiClient?.kv else { return }
            guard let wnd = self.window.rootViewController else { return }
            
            let backgroundView = BlurView()
            backgroundView.alpha = 0.0
            
            let transactionDetails = TransactionDetailsViewController(
                store: self.store,
                transactions: transactions,
                selectedIndex: selectedIndex,
                kvStore: kvStore,
                onDismiss: { vc in
                    UIView.spring(0.5, animations: {
                        backgroundView.alpha = 0.0
                        vc.view.frame.origin.y = UIScreen.main.bounds.height
                        
                    }, completion: { (b) in
                        backgroundView.removeFromSuperview()
                        vc.willMove(toParent: nil)
                        vc.view.removeFromSuperview()
                        vc.removeFromParent()
                    })
                }
            )
        
            wnd.view.addSubview(backgroundView)
            backgroundView.constrain(toSuperviewEdges: nil)
            wnd.addChild(transactionDetails)
            wnd.view.addSubview(transactionDetails.view)
            transactionDetails.view.frame.origin.y = UIScreen.main.bounds.height
        
            UIView.spring(0.5, animations: {
                backgroundView.alpha = 1.0
                transactionDetails.view.frame.origin.y = 0
            }, completion: { (b) in
                
            })
        }
        
        accountViewController = AccountViewController(store: store, didSelectTransaction: didSelectTransaction)
        
        accountViewController?.sendCallback = {
            senderApp = "HomeScreen"
            self.store.perform(action: RootModalActions.Present(modal: .send))
        }
        
        accountViewController?.receiveCallback = {
            senderApp = "HomeScreen"
            self.store.perform(action: RootModalActions.Present(modal: .receive))
        }
        
        accountViewController?.showAddressBookCallback = {
            senderApp = "HomeScreen"
            self.store.perform(action: RootModalActions.Present(modal: .showAddressBook))
        }
        
        accountViewController?.digiIDCallback = {
            senderApp = "HomeScreen"
            self.store.trigger(name: .scanDigiId)
        }
        
        accountViewController?.scanCallback = {
            senderApp = "HomeScreen"
            self.modalPresenter?.presentLoginScan()
        }
        
        window.rootViewController = accountViewController
    }

    private func startDataFetchers() {
        walletManager?.apiClient?.updateFeatureFlags()
        //initKVStoreCoordinator()
        feeUpdater?.refresh()
        defaultsUpdater?.refresh()
        walletManager?.apiClient?.events?.up()
        exchangeUpdater?.refresh(completion: {
            self.watchSessionManager.walletManager = self.walletManager
            self.watchSessionManager.rate = self.store.state.currentRate
        })
    }

    private func addWalletCreationListener() {
        store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            self.modalPresenter?.walletManager = self.walletManager
            self.startDataFetchers()
        })
    }
    
    private func updateAssetBundles() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            myself.noAuthApiClient.updateBundles { errors in
                for (n, e) in errors {
                    print("Bundle \(n) ran update. err: \(String(describing: e))")
                }
            }
        }
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = walletManager?.apiClient?.kv else { return }
        guard kvStoreCoordinator == nil else { return }
        kvStore.syncAllKeys { error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.walletCoordinator?.kvStore = kvStore
            self.kvStoreCoordinator = KVStoreCoordinator(store: self.store, kvStore: kvStore)
            self.kvStoreCoordinator?.retreiveStoredWalletInfo()
            self.kvStoreCoordinator?.listenForWalletChanges()
        }
    }

    private func offMainInitialization() {
        DispatchQueue.global(qos: .background).async {
            let _ = Rate.symbolMap //Initialize currency symbol map
        }
    }

    private func handleLaunchOptions(_ options: [UIApplication.LaunchOptionsKey: Any]?) {
        if let url = options?[.url] as? URL {
            do {
                let file = try Data(contentsOf: url)
                if file.count > 0 {
                    store.trigger(name: .openFile(file))
                }
            } catch let error {
                print("Could not open file at: \(url), error: \(error)")
            }
        }
    }

    func performBackgroundFetch() {
        //saveEvent("appController.performBackgroundFetch")
		
        if let peerManager = walletManager?.peerManager, peerManager.syncProgress(fromStartHeight: peerManager.lastBlockHeight) < 1.0 {
            store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { state in
                if self.fetchCompletionHandler != nil {
                    if state.walletState.syncState == .success {
                        DispatchQueue.walletQueue.async {
                            peerManager.disconnect()
                        }
					}
                }
            })
        }

		let group = DispatchGroup()
        group.enter()
        Async.parallel(callbacks: [
            { self.exchangeUpdater?.refresh(completion: $0) },
            { self.feeUpdater?.refresh(completion: $0) },
            { self.walletManager?.apiClient?.events?.sync(completion: $0) },
            { self.walletManager?.apiClient?.updateFeatureFlags(); $0() }
            ], completion: {
                group.leave()
        })

        DispatchQueue.global(qos: .utility).async {
            if group.wait(timeout: .now() + 25.0) == .timedOut {
                //self.saveEvent("appController.backgroundFetchFailed")
                self.fetchCompletionHandler?(.failed)
            } else {
                //self.saveEvent("appController.backgroundFetchNewData")
                self.fetchCompletionHandler?(.newData)
            }
            self.fetchCompletionHandler = nil
        }
    }

    func willResignActive() {
        guard !store.state.isPushNotificationsEnabled else { return }
        guard let pushToken = UserDefaults.pushToken else { return }
        walletManager?.apiClient?.deletePushNotificationToken(pushToken)
    }
}

//MARK: - Push notifications
extension ApplicationController {
    func listenForPushNotificationRequest() {
        store.subscribe(self, name: .registerForPushNotificationToken, callback: { _ in
            if #available(iOS 10.0, *) {
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .badge, .sound])  { (granted, error) in
                    // Enable or disable features based on authorization.
                    // ToDo
                }
            } else {
                // REGISTER FOR PUSH NOTIFICATIONS
                let notifyTypes:UIUserNotificationType  = [.alert, .badge, .sound]
                let settings = UIUserNotificationSettings(types: notifyTypes, categories: nil)
                self.application?.registerUserNotificationSettings(settings)
                self.application?.registerForRemoteNotifications()
                self.application?.applicationIconBadgeNumber = 0
            }
        })
    }

    @available(iOS 10.0, *)
    func application(_ application: UIApplication, didRegister notificationSettings: UNNotificationSettings) {
//        if !notificationSettings.types.isEmpty {
//            application.registerForRemoteNotifications()
//        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        guard let apiClient = walletManager?.apiClient else { return }
//        guard UserDefaults.pushToken != deviceToken else { return }
//        UserDefaults.pushToken = deviceToken
//        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
//        print("didFailToRegisterForRemoteNotification: \(error)")
    }
    
    func resetWindows() { self.store.perform(action: HamburgerActions.Present(modal: .none)) }
    func openDigiIDScanner() { self.store.trigger(name: .scanDigiId) }
    func showDigiAssets() { self.store.perform(action: HamburgerActions.Present(modal: .digiAssets(nil))) }
    func showAddressBook() { self.store.perform(action: RootModalActions.Present(modal: .showAddressBook)) }
    func showReceive() { self.store.perform(action: RootModalActions.Present(modal: .receive)) }
    func showSend() { self.store.perform(action: RootModalActions.Present(modal: .send)) }
}
