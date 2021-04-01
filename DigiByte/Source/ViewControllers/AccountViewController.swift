//
//  AccountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import MachO
import QuartzCore

let accountHeaderHeight: CGFloat = 136.0
let assetDrawerMarginRight: CGFloat = 15.0
private let transactionsLoadingViewHeightConstant: CGFloat = 48.0

fileprivate let balanceHeaderLabelTopVisible: CGFloat = 12
fileprivate let currencyLabelTopVisible: CGFloat = 12
fileprivate let balanceHeaderLabelTopHidden: CGFloat = -20
fileprivate let currencyLabelTopHidden: CGFloat = -20

fileprivate enum ViewMode {
    case normal
    case small
}

fileprivate class BalanceView: UIView, Subscriber {
    private let balanceHeaderLabel = UILabel(font: .customMedium(size: 12))
    private var balanceLabel: UpdatingLabel
    private var currencyLabel: UpdatingLabel
    
    private var currencyLabelTop: NSLayoutConstraint? = nil
    private var balanceHeaderLabelTop: NSLayoutConstraint? = nil
    
    private var topRightImage = UIImageView(image: nil)
    
    private let grUp: UISwipeGestureRecognizer = {
       let g = UISwipeGestureRecognizer()
        g.direction = .up
        return g
    }()
    
    private let grDown: UISwipeGestureRecognizer = {
        let g = UISwipeGestureRecognizer()
        g.direction = .down
        return g
    }()
    
    private let store: BRStore
    private var isBtcSwapped: Bool {
        didSet { updateBalancesAnimated() }
    }
    private var exchangeRate: Rate? {
        didSet { updateBalances() }
    }
    private var balance: UInt64 = 0 {
        didSet { updateBalances() }
    }
    
    private var viewMode: ViewMode = .normal {
        didSet {
            self.resizeView(viewMode)
        }
    }
    
    init(store: BRStore) {
        self.store = store
        isBtcSwapped = store.state.isBtcSwapped
        exchangeRate = store.state.currentRate
        if let rate = exchangeRate {
            let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: store.state.maxDigits)
            balanceLabel = UpdatingLabel(formatter: placeholderAmount.btcFormat)
            currencyLabel = UpdatingLabel(formatter: placeholderAmount.localFormat)
        } else {
            balanceLabel = UpdatingLabel(formatter: NumberFormatter())
            currencyLabel = UpdatingLabel(formatter: NumberFormatter())
        }
        
        super.init(frame: CGRect())
        
        addSubviews()
        addConstraints()
        addStyles()
        
        addGestureRecognizers()
        
        addSubscriptions()
        
        if UserDefaults.balanceViewCollapsed {
            viewMode = .small
            closeView()
        } else {
            viewMode = .normal
        }
        
        updateSyncIcon(syncState: .connecting, isConnected: false)
    }
    
    private func resizeView(_ viewMode: ViewMode) {
        switch (viewMode) {
            case .normal:
                openView()
            case .small:
                closeView()
        }
    }
    
    private var viewOpen: Bool = true
    private var animating: Bool = false
    private var lastKnownConnectionState: String = "Connecting..."
    
    private func openView() {
        //guard !viewOpen else { return }
        guard !animating else { return }
        animating = true
        
        UIView.spring(0.4, animations: {
            self.balanceHeaderLabelTop?.constant = balanceHeaderLabelTopVisible
            self.currencyLabelTop?.constant = currencyLabelTopVisible
            
            self.balanceHeaderLabel.alpha = 1
            self.currencyLabel.alpha = 1
            self.topRightImage.alpha = 1
            
            self.currencyLabel.layoutIfNeeded()
            self.balanceHeaderLabel.layoutIfNeeded()
            self.balanceLabel.layoutIfNeeded()
            self.layoutIfNeeded()
            
            self.superview?.layoutIfNeeded()
        }) { (c) in
            self.animating = false
            self.viewOpen = true
            UserDefaults.balanceViewCollapsed = false
        }
    }
    
    private func closeView() {
        //guard viewOpen else { return }
        guard !animating else { return }
        animating = true
        
        UIView.spring(0.4, animations: {
            self.balanceHeaderLabelTop?.constant = balanceHeaderLabelTopHidden
            self.currencyLabelTop?.constant = currencyLabelTopHidden
            
            self.balanceHeaderLabel.alpha = 0
            self.currencyLabel.alpha = 0
            self.topRightImage.alpha = 0
            
            self.currencyLabel.layoutIfNeeded()
            self.balanceHeaderLabel.layoutIfNeeded()
            self.balanceLabel.layoutIfNeeded()
            
            self.layoutIfNeeded()
            
            self.superview?.layoutIfNeeded()
        }) { (c) in
            self.animating = false
            self.viewOpen = false
            UserDefaults.balanceViewCollapsed = true
        }
    }
    
    @objc private func balanceViewTapped() {
        guard !animating else { return }
        
        if #available(iOS 10.0, *) {
            let feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator.prepare()
            feedbackGenerator.selectionChanged()
        }

        animating = true
        
        self.store.perform(action: CurrencyChange.toggle())
    }
    
    @objc private func balanceViewSwipeUp() {
        viewMode = .small
    }
    
    @objc private func balanceViewSwipeDown() {
        viewMode = .normal
    }
    
    private func addGestureRecognizers() {
        grUp.addTarget(self, action: #selector(balanceViewSwipeUp))
        grDown.addTarget(self, action: #selector(balanceViewSwipeDown))
        
        let gr = UITapGestureRecognizer()
        gr.addTarget(self, action: #selector(balanceViewTapped))
    
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(grUp)
        self.addGestureRecognizer(grDown)
        self.addGestureRecognizer(gr)
        
        let signalgr = UITapGestureRecognizer()
        signalgr.addTarget(self, action: #selector(signalTapped))
        topRightImage.isUserInteractionEnabled = true
        topRightImage.addGestureRecognizer(signalgr)
    }
    
    @objc
    private func signalTapped() {
        store.trigger(name: .lightWeightAlert(lastKnownConnectionState))
    }
    
    private func addSubscriptions() {
        store.lazySubscribe(self,
                            selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                            callback: { self.isBtcSwapped = $0.isBtcSwapped })
        store.lazySubscribe(self,
                            selector: { $0.currentRate != $1.currentRate},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    self.currencyLabel.formatter = placeholderAmount.localFormat
                                    self.balanceLabel.formatter = placeholderAmount.btcFormat
                                }
                                self.exchangeRate = $0.currentRate
        })
        
        store.lazySubscribe(self,
                            selector: { $0.maxDigits != $1.maxDigits},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    self.currencyLabel.formatter = placeholderAmount.localFormat
                                    self.balanceLabel.formatter = placeholderAmount.btcFormat
                                    self.updateBalances()
                                }
        })
        store.subscribe(self,
                        selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            if let balance = state.walletState.balance {
                                DispatchQueue.main.async {
                                    self.balance = balance
                                }
                            } })
        
        store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState || $0.walletState.isConnected != $1.walletState.isConnected }, callback: { [weak self] state in
            self?.updateSyncIcon(syncState: state.walletState.syncState, isConnected: state.walletState.isConnected)
        })
    }
    
    func updateSyncIcon(syncState: SyncState, isConnected: Bool) {
        topRightImage.stopAnimating()
        topRightImage.animationImages = []
        
        // Update connection status image
        if syncState == .connecting {
            // Show: Connecting...
            lastKnownConnectionState = S.SyncingView.connecting
            topRightImage.image = nil
            
            topRightImage.animationImages = [
                imageWithColor(UIImage(named: "connecting1")!, color: UIColor.gray),
                imageWithColor(UIImage(named: "connecting2")!, color: UIColor.gray),
                imageWithColor(UIImage(named: "connecting3")!, color: UIColor.gray),
            ]
            
            topRightImage.animationDuration = 3
            topRightImage.startAnimating()
            return
        }
        
        if !isConnected {
            // Show: Not connected
            lastKnownConnectionState = S.NodeSelector.notConnected
            topRightImage.image = UIImage(named: "disconnected")?.withRenderingMode(.alwaysTemplate)
            topRightImage.tintColor = C.Colors.weirdRed
        } else {
            // Show: connected
            lastKnownConnectionState = S.SyncingView.syncing
            topRightImage.image = UIImage(named: "connected")?.withRenderingMode(.alwaysTemplate)
            topRightImage.tintColor = C.Colors.weirdGreen
        }
    }
    
    private func imageWithColor(_ img: UIImage, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0, y: img.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(.normal)
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        context.clip(to: rect, mask: img.cgImage!)
        color.setFill()
        context.fill(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private func addSubviews() {
        addSubview(balanceHeaderLabel)
        addSubview(balanceLabel)
        addSubview(currencyLabel)
        addSubview(topRightImage)
    }
    
    private func addConstraints() {
        balanceHeaderLabelTop = balanceHeaderLabel.topAnchor.constraint(equalTo: topAnchor, constant: balanceHeaderLabelTopVisible)
        balanceHeaderLabel.constrain([
            balanceHeaderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            balanceHeaderLabelTop
        ])
        
        balanceLabel.constrain([
            balanceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            balanceLabel.topAnchor.constraint(equalTo: balanceHeaderLabel.bottomAnchor, constant: 12),
        ])
        
        currencyLabelTop = currencyLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: currencyLabelTopVisible)
        currencyLabel.constrain([
            currencyLabelTop,
            currencyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            currencyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -25)
        ])
        
        topRightImage.constrain([
            topRightImage.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            topRightImage.rightAnchor.constraint(equalTo: rightAnchor, constant: -12),
            topRightImage.widthAnchor.constraint(equalToConstant: 20),
            topRightImage.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    private func addStyles() {
        balanceLabel.font = .customMedium(size: 32)
        balanceLabel.textColor = C.Colors.text
        balanceLabel.textAlignment = .center
        
        currencyLabel.font = .customMedium(size: 16)
        currencyLabel.textColor = .gray
        currencyLabel.textAlignment = .center
        
        balanceHeaderLabel.numberOfLines = 2
        balanceHeaderLabel.textColor = .gray
        balanceHeaderLabel.text = S.Balance.header.uppercased()
        balanceHeaderLabel.textAlignment = .center
        
        //balanceLabel.text = "D 132 293.787"
        //currencyLabel.text = "$USD 3988.33"
        backgroundColor = .clear
        
        topRightImage.contentMode = .scaleAspectFit
        topRightImage.tintColor = .white
        
        if #available(iOS 13.0, *) {
            let standard = UINavigationBarAppearance()
            standard.configureWithTransparentBackground()

            standard.backgroundColor = .clear
            standard.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            let button = UIBarButtonItemAppearance(style: .plain)
            button.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
            standard.buttonAppearance = button
            
            let done = UIBarButtonItemAppearance(style: .done)
            done.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
            standard.doneButtonAppearance = done
            
            UINavigationBar.appearance().standardAppearance = standard
        }
    }
    
    private func updateBalances(animatedValue: Bool = true) {
        guard let rate = exchangeRate else { return }
        let amount = Amount(amount: balance, rate: rate, maxDigits: store.state.maxDigits)
        
        var balanceValue: Double = 0
        var currencyValue: Double = 0
        
        if isBtcSwapped {
            self.currencyLabel.formatter = amount.btcFormat
            self.balanceLabel.formatter = amount.localFormat
            balanceValue = amount.localAmount
            currencyValue = amount.amountForBtcFormat
        } else {
            self.currencyLabel.formatter = amount.localFormat
            self.balanceLabel.formatter = amount.btcFormat
            balanceValue = amount.amountForBtcFormat
            currencyValue = amount.localAmount
        }
        
        if animatedValue {
            balanceLabel.setValueAnimated(balanceValue) {}
            currencyLabel.setValueAnimated(currencyValue) {}
        } else {
            balanceLabel.setValue(balanceValue)
            currencyLabel.setValue(currencyValue)
        }
    }
    
    private func updateBalancesAnimated() {
        UIView.animate(withDuration: 0.2, animations: {
            self.balanceLabel.alpha = 0
            self.currencyLabel.alpha = 0
        }) { (c) in
            self.updateBalances(animatedValue: false)
            UIView.animate(withDuration: 0.2, animations: {
                self.balanceLabel.alpha = 1
                
                if self.viewMode == .normal {
                    self.currencyLabel.alpha = 1
                }
            }, completion: { (c) in
                self.animating = false
            })
        }
    }
}

fileprivate class CustomSegmentedControl: UIControl {
    
    private var padding: CGFloat = 7.0
    
    var buttons = [UIButton]()
    
    var buttonTemplates: [String] = []
    
    var backgroundRect: UIView!
    
    var selectedSegmentIdx = 0 {
        didSet {
            //updateSegmentedControlSegs(index: selectedSegmentIdx)
        }
    }
    
    var numberOfSegments: Int = 0
    
    var callback: ((Int, Int) -> Void)? = nil
    var scrollToTopCallback: ((Int) -> Void)? = nil
    
    var animating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        styleView()
        update()
    }
    
    func update() {
        updateView()
    }
    
    private func styleView() {
        backgroundColor = C.Colors.background
    
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateView() {
        buttons.removeAll()
        
        subviews.forEach { (v) in
            v.removeFromSuperview()
        }
        
        guard buttonTemplates.count > 0 else { return }
        numberOfSegments = buttonTemplates.count
        
        let selectorWidth = (frame.width - 2 * padding) / CGFloat(numberOfSegments)

        backgroundRect = UIView()
        backgroundRect.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        backgroundRect.layer.cornerRadius = 4
        
        let buttonTitles = buttonTemplates
        for buttonTitle in buttonTitles {
            let button = UIButton(type: .system)
            button.setTitle(buttonTitle, for: .normal)
            button.titleLabel?.font = UIFont.customBody(size: 14)
            button.setTitleColor(C.Colors.text, for: .normal)
            button.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
            button.backgroundColor = .clear
            button.titleLabel?.lineBreakMode = .byCharWrapping
            button.titleLabel?.textAlignment = .center
            buttons.append(button)
        }
        
        // background Rect
        addSubview(backgroundRect)
        
        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 0.0
        stackView.backgroundColor = .clear
        addSubview(stackView)
        
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: self.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: padding),
            stackView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -padding),
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false

//        backgroundRect.constrain([
//            backgroundRect.topAnchor.constraint(equalTo: topAnchor, constant: padding),
//            backgroundRect.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),
//            backgroundRect.widthAnchor.constraint(equalToConstant: selectorWidth),
//            backgroundRect.leftAnchor.constraint(equalTo: leftAnchor, constant: padding)
//        ])
        
        backgroundRect.frame = CGRect(x: padding, y: padding, width: selectorWidth, height: self.frame.height - 2*padding)
        
        backgroundColor = UIColor(red: 0x23 / 255, green: 0x24 / 255, blue: 0x37 / 255, alpha: 1.0)
        layer.cornerRadius = 4
    }
    
    @objc func buttonTapped(button: UIButton) {
        var selectorStartPosition: CGFloat!
        for (buttonIndex, btn) in buttons.enumerated() {
            btn.setTitleColor(C.Colors.text, for: .normal)
            
            if (btn == button) {
                guard !animating else { return }
                
                guard selectedSegmentIdx != buttonIndex else {
                    scrollToTopCallback?(buttonIndex)
                    return
                }
                
                animating = true
                callback?(selectedSegmentIdx, buttonIndex)
                selectedSegmentIdx = buttonIndex
                selectorStartPosition = padding + (frame.width - 2 * padding) / CGFloat(buttons.count) * CGFloat(buttonIndex)
                
                UIView.spring(0.2, animations: {
                    self.backgroundRect.frame.origin.x = selectorStartPosition
                }) { (done) in
                    DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1, execute: {
                        self.animating = false
                    })
                }
            }
        }
    }
    
    func animationStep(progress: CGFloat) {
        guard !animating else { return }
    
        let progress = (progress > 1 ? 1 : (progress < -1 ? -1 : progress))
        let singleWidth = (frame.width - 2*padding) / CGFloat(buttons.count)
        let maxIndex = CGFloat(buttons.count) - 1
        var index = CGFloat(selectedSegmentIdx) + progress
        index = (index > maxIndex ? maxIndex : index)
        index = (index < 0 ? 0 : index)
        
        // calculate new position
        let posX = padding + singleWidth * CGFloat(index)
        let newPos: CGFloat = posX
        
        backgroundRect.frame.origin.x = newPos
    }
    
    @objc private func stopped() {
        self.selectedSegmentIdx  = nextIndex
    }
    
    private var nextIndex: Int = 0
    
    func updateSegmentedControlSegs(index: Int) {
        var selectorStartPosition: CGFloat!
        selectorStartPosition = padding + (frame.width - 2*padding) / CGFloat(buttons.count) * CGFloat(index)
        
        selectedSegmentIdx = index

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.3, initialSpringVelocity: 10, options: [ .allowUserInteraction, .curveLinear ], animations: {
            self.backgroundRect.frame.origin.x = selectorStartPosition
        }) { (done) in
            // 
        }
    }
}

protocol DrawerControllerProtocol {
    func closeDrawer(with id: String)
}

class AccountViewController: UIViewController, Subscriber, UIPageViewControllerDataSource, UIPageViewControllerDelegate, DrawerControllerProtocol, UIScrollViewDelegate {

    //MARK: - Public
    var sendCallback: (() -> Void)? {
        didSet { footerView.sendCallback = sendCallback }
    }
    var receiveCallback: (() -> Void)? {
        didSet { footerView.receiveCallback = receiveCallback }
    }
    var menuCallback: (() -> Void)? {
        didSet { footerView.menuCallback = menuCallback }
    }
    
    var digiIDCallback: (() -> Void)? {
        didSet {
            footerView.digiIDCallback = digiIDCallback
        }
    }
    
    var scanCallback: (() -> Void)? {
        didSet {
            footerView.qrScanCallback = scanCallback
        }
    }
    
    var showAddressBookCallback: (() -> Void)? {
        didSet {
            footerView.addressBookCallback = showAddressBookCallback
        }
    }

    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            
            AssetHelper.assetWasNotSpentCallback = { [weak self] (txid, n) -> Bool in
                guard let wallet = self?.walletManager?.wallet else { return false }
                
                let hasUtxo = wallet.hasUtxo(txid: txid, n: n)
                let isSpendable =  wallet.utxoIsSpendable(txid: txid, n: n)
                
                GlobalDebug.default.add("\(txid):\(n) => hasUtxo=\(hasUtxo), isSpendable=\(isSpendable)")
                
                return hasUtxo && isSpendable
            }
            
            if !walletManager.noWallet {
                loginView.walletManager = walletManager
                loginView.transitioningDelegate = loginTransitionDelegate
                loginView.modalPresentationStyle = .overFullScreen
                loginView.modalPresentationCapturesStatusBarAppearance = true
                loginView.shouldSelfDismiss = true
                
                self.present(self.loginView, animated: false, completion: {
                    self.tempView.removeFromSuperview()
                    self.tempLoginView.remove()
                    //self.attemptShowWelcomeView()
                })

//                let pin = UpdatePinViewController(store: store, walletManager: walletManager, type: .update, showsBackButton: false, phrase: "Enter your PIN")
//                pin.view.backgroundColor = UIColor.txListGreen // DDDDD
//                pin.transitioningDelegate = loginTransitionDelegate
//                pin.modalPresentationStyle = .overFullScreen
//                pin.modalPresentationCapturesStatusBarAppearance = true
//                self.present(pin, animated: false, completion: {
//                    self.tempView.removeFromSuperview()
//                    self.tempLoginView.remove()
//                })
            }
            transactionsTableView.walletManager = walletManager
            transactionsTableViewForSentTransactions.walletManager = walletManager
            transactionsTableViewForReceivedTransactions.walletManager = walletManager
            assetDrawer.walletManager = walletManager
        }
    }
    
    func assetTxSelected(by hash: String) {
        guard let txIdx = store.state.walletState.transactions.firstIndex(where: { $0.hash == hash }) else { return }
        let tx = store.state.walletState.transactions[txIdx]
        assetTxSelected(tx)        
    }
    
    func assetTxSelected(_ tx: Transaction) {
        assert(tx.isAssetTx)
        
        let showDrawerMenu: (TransactionInfoModel) -> Void = { infoModel in
            self.assetDrawer.setTransactionInfoModel(for: tx, infoModel: infoModel)
            self.openAssetDrawer()
        }
        
        if
            let infoModel = AssetHelper.getTransactionInfoModel(txid: tx.hash),
            infoModel.temporary != true,
            AssetHelper.hasAllAssetModels(for: infoModel.getAssetIds())
        {
            // Display asset if all required models exist
            showDrawerMenu(infoModel)
        } else {
            // Display privacy alert and load asset data and it's asset models
            self.showSingleDigiAssetsConfirmViewIfNeeded(for: tx) { utxos in
                guard utxos.count > 0 else {
                    self.didSelectTransaction(hash: tx.hash)
                    self.showError(with: S.Assets.NoAssetData)
                    return
                }
                
                let infoModel = utxos[0]
                showDrawerMenu(infoModel)
            }
        }
    }
    
    init(store: BRStore, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.store = store
        self.syncViewController = SyncViewController(store: store)
        
        self.loginView = LoginViewController(store: store, isPresentedForLock: false)
        self.tempLoginView = LoginViewController(store: store, isPresentedForLock: false)
        self.balanceView = BalanceView(store: store)
        
        self.didSelectTransaction = didSelectTransaction
        
        self.edgeGesture = UIScreenEdgePanGestureRecognizer()
        super.init(nibName: nil, bundle: nil)
        
        // This callback is invoked if a transaction was selected that contains an asset
        let didSelectAssetTx: (_ tx: Transaction) -> Void = { tx in
            self.assetTxSelected(tx)
        }
        
        transactionsTableView = TransactionsTableViewController(store: store, didSelectTransaction: didSelectTransaction, didSelectAssetTx: didSelectAssetTx)
        transactionsTableViewForSentTransactions = TransactionsTableViewController(store: store, didSelectTransaction: didSelectTransaction, didSelectAssetTx: didSelectAssetTx, kvStore: nil, filterMode: .showOutgoing)
        transactionsTableViewForReceivedTransactions = TransactionsTableViewController(store: store, didSelectTransaction: didSelectTransaction, didSelectAssetTx: didSelectAssetTx, kvStore: nil, filterMode: .showIncoming)
        
        footerView.debugDigiAssetsCallback = { [unowned self] in
            guard let w = self.walletManager else { return }
            let vc = BRDigiAssetsTestViewController(wallet: w)
            self.present(vc, animated: true, completion: nil)
        }
        
        // Loading view for assets fetcher
        loadingAssetsModalView = DGBModalLoadingView(title: S.Assets.fetchingAssetsTitle)
        
        // New assets stored on device
        AssetNotificationCenter.instance.addObserver(forName: AssetNotificationCenter.notifications.newAssetData, object: nil, queue: nil) { _ in
            // Refresh all tableviews
            self.transactionsTableView.tableView.reloadData()
            self.transactionsTableViewForSentTransactions.tableView.reloadData()
            self.transactionsTableViewForReceivedTransactions.tableView.reloadData()
        }
        
        // Fetching new assets
        AssetNotificationCenter.instance.addObserver(forName: AssetNotificationCenter.notifications.fetchingAssets, object: nil, queue: nil) { _ in
            
            self.present(self.loadingAssetsModalView, animated: true, completion: nil)
        }
        
        // Update progress when resolving Assets
        AssetNotificationCenter.instance.addObserver(forName: AssetNotificationCenter.notifications.updateProgress, object: nil, queue: nil) { notification in
            if
                let current = notification.userInfo?["current"] as? Int,
                let total = notification.userInfo?["total"] as? Int {
                self.loadingAssetsModalView.updateStep(current: current, total: total)
            }
        }
        
        // Completed fetching new assets
        AssetNotificationCenter.instance.addObserver(forName: AssetNotificationCenter.notifications.fetchedAssets, object: nil, queue: nil) { _ in
            self.loadingAssetsModalView.dismiss(animated: true, completion: nil)
        }
        
        // A Tx was selected in the Asset's Detail View. Show the drawer menu, if the txhash exists.
        AssetNotificationCenter.instance.addObserver(forName: AssetNotificationCenter.notifications.assetTxSelected, object: nil, queue: nil) { notification in
            if let hash = notification.userInfo?["tx"] as? String {
                self.assetTxSelected(by: hash)
            }
        }
    }

    //MARK: - Private
    private let store: BRStore
    private let footerView = AccountFooterView()
    private let syncViewController: SyncViewController
    private let transactionsLoadingView = LoadingProgressView()
    private var transactionsTableView: TransactionsTableViewController!
    private var transactionsTableViewForSentTransactions: TransactionsTableViewController!
    private var transactionsTableViewForReceivedTransactions: TransactionsTableViewController!
    
    private let tempView = UIView(color: C.Colors.background)
    
    private let pageController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var pages = [UIViewController]()
    
    private let navigationDrawer = NavigationDrawer(id: "navigation", walletTitle: C.applicationTitle, version: C.version)
    private let assetDrawer = AssetDrawer(id: "assets")
    private var loadingAssetsModalView: DGBModalLoadingView!
    
    private var assetResolver: AssetResolver? = nil
    
    private let fadeView: UIView = {
        let view = BlurView()
        view.isUserInteractionEnabled = true
        return view
    }()
    private var navigationDrawerOpen = false
    private var assetDrawerOpen = false
    private let edgeGesture: UIScreenEdgePanGestureRecognizer
    private var navigationMenuLeftConstraint: NSLayoutConstraint?
    private var menuWidthConstraint: NSLayoutConstraint?
    private var assetDrawerRightConstraint: NSLayoutConstraint?
    private var assetDrawerWidthConstraint: NSLayoutConstraint?
    
    private let footerHeight: CGFloat = 56.0
    private var transactionsLoadingViewTop: NSLayoutConstraint?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var isLoginRequired = false
    private let loginView: LoginViewController
    private let tempLoginView: LoginViewController
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private let welcomeTransitingDelegate = PinTransitioningDelegate()
    
    private let didSelectTransaction: ([Transaction], Int) -> Void
    
    private var balanceView: BalanceView
    private let menu = CustomSegmentedControl(frame: .zero)

    private let searchHeaderview: SearchHeaderView = {
        let view = SearchHeaderView()
        view.isHidden = true
        return view
    }()
    private let headerContainer = UIView()
    private var loadingTimer: Timer?
    private var shouldShowStatusBar: Bool = true {
        didSet {
            if oldValue != shouldShowStatusBar {
                UIView.animate(withDuration: C.animationDuration) {
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }
    private var didEndLoading = false

    private func showActivity(_ view: UIView) {
        let act = UIActivityIndicatorView()
        act.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        act.style = UIActivityIndicatorView.Style.whiteLarge
        view.addSubview(act)
        act.constrain([
            act.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            act.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        act.startAnimating()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // detect jailbreak so we can throw up an idiot warning, in viewDidLoad so it can't easily be swizzled out
        if !E.isSimulator {
            var s = stat()
            var isJailbroken = (stat("/bin/sh", &s) == 0) ? true : false
            for i in 0..<_dyld_image_count() {
                guard !isJailbroken else { break }
                // some anti-jailbreak detection tools re-sandbox apps, so do a secondary check for any MobileSubstrate dyld images
                if strstr(_dyld_get_image_name(i), "MobileSubstrate") != nil {
                    isJailbroken = true
                }
            }
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { note in
                self.showJailbreakWarnings(isJailbroken: isJailbroken)
            }
            showJailbreakWarnings(isJailbroken: isJailbroken)
        }

        view.backgroundColor = UIColor(red: 0x19 / 255, green: 0x1b / 255, blue: 0x2a / 255, alpha: 1)
        
        addBalanceView()
        addSegmentedView()
        addTransactionsView()
        addSubviews()
        addDrawerMenus()
        addConstraints()
        addSubscriptions()
        addAppLifecycleNotificationEvents()
        addTemporaryStartupViews()
        setInitialData()
        
        for subview in pageController.view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.delegate = self
            }
        }
    }
    
    private let MENUBACKGROUND_OPACITY_END: CGFloat = 0.8
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let point = scrollView.contentOffset
        let percentageComplete: CGFloat = (point.x - view.frame.size.width) / view.frame.size.width
        
        if percentageComplete != 0 {
            menu.animationStep(progress: percentageComplete)
        }
    }
    
    @objc private func gestureScreenEdgePan(_ sender: UIScreenEdgePanGestureRecognizer) {
        guard let menuLeftConstraint = navigationMenuLeftConstraint else { return }
        let width = navigationDrawer.frame.width
        
        if sender.state == .began {
            fadeView.isHidden = false
            fadeView.alpha = 0
        } else if (sender.state == .changed) {
            let translationX = sender.translation(in: sender.view).x
            
            if -width + translationX > 0 {
                menuLeftConstraint.constant = -15
                fadeView.alpha = MENUBACKGROUND_OPACITY_END
            } else if translationX < 0 {
                // fully dragged in
                menuLeftConstraint.constant = -width
                fadeView.alpha = 0
            } else {
                // viewMenu is being dragged somewhere between min and max amount
                menuLeftConstraint.constant = -width + translationX - 15
                
                let ratio = translationX / width
                let alphaValue = ratio * MENUBACKGROUND_OPACITY_END
                fadeView.alpha = alphaValue
            }
        } else {
            // if the menu was dragged less than half of it's width, close it. Otherwise, open it.
            if menuLeftConstraint.constant < -width * 2 / 3 {
                self.closeNavigationDrawer()
            } else {
                self.openNavigationDrawer()
            }
        }
    }
    
    @objc private func gesturePan(_ sender: UIPanGestureRecognizer) {
        if (navigationDrawerOpen) {
            guard let menuLeftConstraint = navigationMenuLeftConstraint else { return }
            let width = navigationDrawer.frame.width
            
            if sender.state == UIGestureRecognizer.State.began {
                // do nothing
            } else if sender.state == UIGestureRecognizer.State.changed {
                let translationX = sender.translation(in: sender.view).x
                if translationX > 0 {
                    menuLeftConstraint.constant = -15 + sqrt(translationX)
                    navigationDrawer.animationStep(progress: 1)
                    fadeView.alpha = MENUBACKGROUND_OPACITY_END
                } else if translationX < -width - 15 {
                    menuLeftConstraint.constant = -width
                    navigationDrawer.animationStep(progress: 0)
                    fadeView.alpha = 0
                } else {
                    menuLeftConstraint.constant = translationX - 15
                    
                    let ratio = (width + translationX - 15) / width
                    let alphaValue = ratio
                    fadeView.alpha = alphaValue * MENUBACKGROUND_OPACITY_END
                    navigationDrawer.animationStep(progress: ratio)
                }
                view.layoutIfNeeded()
            } else {
                if menuLeftConstraint.constant < -width / 3 {
                    self.closeNavigationDrawer()
                } else {
                    self.openNavigationDrawer()
                }
            }
        } else if assetDrawerOpen {
            guard let assetDrawerRightConstraint = assetDrawerRightConstraint else { return }
            let width = assetDrawer.frame.width
            
                
            if sender.state == UIGestureRecognizer.State.began {
                // do nothing
            } else if sender.state == UIGestureRecognizer.State.changed {
                let translationX = sender.translation(in: sender.view).x
                if translationX < 0 {
                    assetDrawerRightConstraint.constant = assetDrawerMarginRight - sqrt(-translationX)
                    fadeView.alpha = MENUBACKGROUND_OPACITY_END
                } else if translationX > width - assetDrawerMarginRight {
                    assetDrawerRightConstraint.constant = width
                    fadeView.alpha = 0
                } else {
                    assetDrawerRightConstraint.constant = translationX + assetDrawerMarginRight
                    
                    let ratio = (width - translationX + assetDrawerMarginRight) / width
                    let alphaValue = ratio
                    fadeView.alpha = alphaValue * MENUBACKGROUND_OPACITY_END
                }
                view.layoutIfNeeded()
            } else {
                if assetDrawerRightConstraint.constant > width / 3 {
                    self.closeAssetDrawer()
                } else {
                    self.openAssetDrawer()
                }
            }
        }
    }

    
    private func addDrawerMenus() {
        // set closer delegates
        navigationDrawer.setCloser(supervc: self)
        assetDrawer.setCloser(supervc: self)
        
        navigationDrawer.addButton(title: S.MenuButton.security, icon: UIImage(named: "hamburger_002Shield")!) {
            self.store.perform(action: HamburgerActions.Present(modal: .securityCenter))
        }
        
//        hamburgerMenuView.addButton(title: S.MenuButton.support, icon: UIImage(named: "hamburger_001Info")) {
//            self.store.perform(action: HamburgerActions.Present(modal: .support))
//        }
        
        navigationDrawer.addButton(title: S.MenuButton.digiAssets, icon: UIImage(named: "digiassets")!) {
            guard !UserDefaults.showRawTransactionsOnly else {
                // Please Enable DigiAsset Support in Settings
                let vc = DGBConfirmAlert(title: S.Assets.protocolDisabled, message: S.Assets.protocolDisabledDescription, image: nil, okTitle: S.Button.ok, cancelTitle: nil, alternativeButtonTitle: nil)
                vc.contentLabel.textAlignment = .center
                
                vc.confirmCallback = { close in
                    close()
                }
                
                self.present(vc, animated: true, completion: nil)
                return
            }
            
            // Show confirmation alert (address disclosure)
            if !self.showDigiAssetsConfirmViewIfNeeded({ infoModels in
                // Models were probably resolved
                guard infoModels.count > 0 else { return }
                self.store.perform(action: HamburgerActions.Present(modal: .digiAssets(nil)))
            }) {
                self.store.perform(action: HamburgerActions.Present(modal: .digiAssets(nil)))
            }
        }
        
        navigationDrawer.addButton(title: S.MenuButton.settings, icon: UIImage(named: "hamburger_003Settings")!) {
            self.store.perform(action: HamburgerActions.Present(modal: .settings))
        }

        navigationDrawer.addButton(title: S.MenuButton.lock, icon: UIImage(named: "hamburger_004Locked")!) {
            self.store.perform(action: HamburgerActions.Present(modal: .lockWallet))
        }
        
        view.addSubview(fadeView)
        view.addSubview(navigationDrawer)
        view.addSubview(assetDrawer)
        
        navigationMenuLeftConstraint = navigationDrawer.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0)
        menuWidthConstraint = navigationDrawer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9)
        
        assetDrawerRightConstraint = assetDrawer.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0)
        assetDrawerWidthConstraint = assetDrawer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9)
        
        navigationDrawer.constrain([
            navigationMenuLeftConstraint,
            menuWidthConstraint,
            navigationDrawer.topAnchor.constraint(equalTo: view.topAnchor),
            navigationDrawer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        assetDrawer.constrain([
            assetDrawerRightConstraint,
            assetDrawerWidthConstraint,
            assetDrawer.topAnchor.constraint(equalTo: view.topAnchor),
            assetDrawer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        assetDrawer.callback = { [weak self] tx in
            self?.closeAssetDrawer()
            self?.didSelectTransaction(hash: tx.hash)
        }
        
        assetDrawer.assetNavigatorCallback = { [weak self] action in
            self?.store.perform(action: HamburgerActions.Present(modal: .digiAssets(action)))
        }
        
        let tapper = UITapGestureRecognizer()
        tapper.numberOfTapsRequired = 1
        tapper.numberOfTouchesRequired = 1
        tapper.addTarget(self, action: #selector(fadeViewTap))
        fadeView.addGestureRecognizer(tapper)
        
        let panner = UIPanGestureRecognizer()
        panner.addTarget(self, action: #selector(gesturePan(_:)))
        fadeView.addGestureRecognizer(panner)
        
        edgeGesture.addTarget(self, action: #selector(gestureScreenEdgePan))
        edgeGesture.edges = .left
        view.addGestureRecognizer(edgeGesture)
        
        fadeView.constrain(toSuperviewEdges: nil)
        footerView.menuCallback = { () -> Void in
            self.openNavigationDrawer()
        }
    }
    
    @objc private func fadeViewTap() {
        if navigationDrawerOpen { closeNavigationDrawer() }
        if assetDrawerOpen { closeAssetDrawer() }
    }
    
    func closeDrawer(with id: String) {
        switch id {
            case "navigation": closeNavigationDrawer()
            case "assets": closeAssetDrawer()
            default:
                break;
        }
    }
    
    func openNavigationDrawer() {
        if assetDrawerOpen { self.closeAssetDrawer() }
        
        navigationMenuLeftConstraint?.constant = -15
        fadeView.isHidden = false
        
        UIView.spring(0.3, animations: {
            self.view.layoutIfNeeded()
            self.fadeView.alpha = self.MENUBACKGROUND_OPACITY_END
            self.navigationDrawer.animationStep(progress: 1.0)
        }, completion: { (finished) in
            self.edgeGesture.isEnabled = false
            self.navigationDrawerOpen = true
        })
    }
    
    func closeNavigationDrawer() {
//        guard navigationDrawerOpen else { return }
        navigationMenuLeftConstraint?.constant = -navigationDrawer.frame.width
        
        UIView.spring(0.3, animations: {
            self.view.layoutIfNeeded()
            self.fadeView.alpha = 0.0
            self.navigationDrawer.animationStep(progress: 0)
        }) { (finished) in
            self.edgeGesture.isEnabled = true
            self.fadeView.isHidden = true
            self.navigationDrawerOpen = false
        }
    }
    
    func openAssetDrawer() {
        if navigationDrawerOpen { self.closeNavigationDrawer() }
        
        assetDrawerRightConstraint?.constant = assetDrawerMarginRight
        fadeView.isHidden = false
        
        UIView.spring(0.3, animations: {
            self.view.layoutIfNeeded()
            self.fadeView.alpha = self.MENUBACKGROUND_OPACITY_END
        }, completion: { (finished) in
            self.edgeGesture.isEnabled = false
            self.assetDrawerOpen = true
        })
    }
    
    func closeAssetDrawer() {
        guard assetDrawerOpen else { return }
        assetDrawerRightConstraint?.constant = assetDrawer.frame.width
        
        UIView.spring(0.3, animations: {
            self.view.layoutIfNeeded()
            self.fadeView.alpha = 0.0
        }) { (finished) in
            self.edgeGesture.isEnabled = true
            self.fadeView.isHidden = true
            self.assetDrawerOpen = false
        }
    }
    
    private func addBalanceView() {
        view.addSubview(balanceView)
    }
    
    private func addSegmentedView() {
        view.addSubview(menu)
        menu.buttonTemplates = [
            S.TransactionView.all.uppercased(),
            S.TransactionView.sent.uppercased(),
            S.TransactionView.received.uppercased()
        ]
        menu.callback = { (oldIdx, idx) -> () in
            let forward = (idx > oldIdx)
            self.pageController.setViewControllers([self.pages[idx]], direction: forward ? .forward : .reverse, animated: true, completion: nil)
        }
        menu.scrollToTopCallback = { (idx) -> () in
            switch(idx) {
            case 0:
                self.transactionsTableView.tableView.setContentOffset(CGPoint.zero, animated: true)
                break
            case 1:
                self.transactionsTableViewForSentTransactions.tableView.setContentOffset(CGPoint.zero, animated: true)
                break
            case 2:
                self.transactionsTableViewForReceivedTransactions.tableView.setContentOffset(CGPoint.zero, animated: true)
                break
            default:
                break
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldShowStatusBar = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        menu.update()
        
        navigationMenuLeftConstraint?.constant = -navigationDrawer.frame.width
        assetDrawerRightConstraint?.constant = assetDrawer.frame.width
        navigationDrawer.layoutIfNeeded()
        assetDrawer.layoutIfNeeded()
        
        fadeView.alpha = 0
        fadeView.isHidden = true
        
        if let walletState = walletManager?.store.state.walletState {
            balanceView.updateSyncIcon(syncState: walletState.syncState, isConnected: walletState.isConnected)
        }
    }
    
    private func addSubviews() {
        view.addSubview(balanceView)
        view.addSubview(headerContainer)
        
        addChild(syncViewController)
        view.addSubview(syncViewController.view)

        view.addSubview(footerView)
        headerContainer.addSubview(searchHeaderview)
    }

    private func addConstraints() {
        balanceView.constrain([
            balanceView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            balanceView.leftAnchor.constraint(equalTo: view.leftAnchor),
            balanceView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        
        menu.constrain([
            menu.topAnchor.constraint(equalTo: balanceView.bottomAnchor),
            menu.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8),
            menu.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8),
            menu.heightAnchor.constraint(equalToConstant: 60)
        ])

        footerView.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        footerView.constrain([
            footerView.constraint(.height, constant: E.isIPhoneXOrGreater ? footerHeight + 19.0 : footerHeight)
        ])
        searchHeaderview.constrain(toSuperviewEdges: nil)
        
        syncViewController.view.constrain(toSuperviewEdges: nil)
    }
    
    var kvStore: BRReplicatedKVStore? = nil {
        didSet {
            guard kvStore != nil else { return }
            transactionsTableView.kvStore = kvStore
            transactionsTableViewForSentTransactions.kvStore = kvStore
            transactionsTableViewForReceivedTransactions.kvStore = kvStore
        }
    }
    
    func didSelectTransaction(hash: String) {
        let txs = store.state.walletState.transactions
        if
            let idx = txs.firstIndex(where: { $0.hash == hash }) {
            self.didSelectTransaction(txs, idx)
        }
    }
    
    func showSingleDigiAssetsConfirmViewIfNeeded(for tx: Transaction, _ callback: (([TransactionInfoModel]) -> Void)? = nil) {
        // Check if models already exist in cache
        if
            let infoModel = AssetHelper.getTransactionInfoModel(txid: tx.hash) {
            // Do not show confirm view,
            // if we have all asset utxos and all required models.
            if
                infoModel.temporary != true,
                AssetHelper.hasAllAssetModels(for: infoModel.getAssetIds()) {
                callback?([infoModel])
                return
            }
        }
            
        let confirmView = DGBConfirmAlert(title: S.Assets.openAssetTitle, message: S.Assets.openAssetMessage, image: UIImage(named: "privacy"), okTitle: S.Assets.confirmAssetsResolve, cancelTitle: S.Assets.cancelAssetsResolve, alternativeButtonTitle: S.Assets.viewRawTransaction)
        
        let confirmCallback: () -> Void = {
            if self.assetResolver != nil { self.assetResolver!.cancel() }
            self.assetResolver = AssetHelper.resolveAssetTransaction(for: tx, callback: callback)
        }
        
        confirmView.alternativeCallback = { [weak self] (close: DGBCallback) in
            close()
            
            self?.didSelectTransaction(hash: tx.hash)
        }
        
        confirmView.confirmCallback = { (close: DGBCallback) in
            close()
            confirmCallback()
        }
        
        confirmView.cancelCallback = { (close: DGBCallback) in
            close()
        }
        
        guard !UserDefaults.Privacy.automaticallyResolveAssets else {
            confirmCallback()
            return
        }
        
        self.present(confirmView, animated: true, completion: nil)
    }
    
    @discardableResult
    func showDigiAssetsConfirmViewIfNeeded(_ callback: (([TransactionInfoModel]) -> Void)? = nil) -> Bool {
        guard !AssetHelper.resolvedAllAssets(for: self.store.state.walletState.transactions) else { return false }
            
        let confirmView = DGBConfirmAlert(title: S.Assets.receivedAssetsTitle, message: S.Assets.receivedAssetsMessage, image: UIImage(named: "privacy"), okTitle: S.Assets.confirmAssetsResolve, cancelTitle: S.Assets.cancelAssetsResolve, alternativeButtonTitle: S.Assets.continueWithoutSync)
        
        let confirmCallback: () -> Void = {
            let transactions = self.store.state.walletState.transactions
            if let resolver = self.assetResolver { resolver.cancel() }
            self.assetResolver = AssetHelper.resolveAssetTransaction(for: transactions.map({ $0.hash }), callback: callback)
        }
        
        confirmView.confirmCallback = { (close: DGBCallback) in
            close()
            confirmCallback()
        }
        
        confirmView.cancelCallback = { (close: DGBCallback) in
            close()
        }
        
        confirmView.alternativeCallback = { (close: DGBCallback) in
            close()
            self.store.perform(action: HamburgerActions.Present(modal: .digiAssets(nil)))
        }
        
        guard !UserDefaults.Privacy.automaticallyResolveAssets else {
            confirmCallback()
            return true
        }
        
        self.present(confirmView, animated: true, completion: nil)
        return true
    }

    private func addSubscriptions() {
        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress }, callback: { state in
            self.syncViewController.updateSyncState(
                state: nil,
                percentage: state.walletState.syncProgress * 100.0,
                blockHeight: state.walletState.blockHeight,
                date: Date(timeIntervalSince1970: TimeInterval(state.walletState.lastBlockTimestamp))
            )
        })
        
        store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { state in
            guard let peerManager = self.walletManager?.peerManager else { return }
            
            self.syncViewController.updateSyncState(
                state: state.walletState.syncState,
                percentage: state.walletState.syncProgress * 100.0,
                blockHeight: state.walletState.blockHeight,
                date: Date(timeIntervalSince1970: TimeInterval(exactly: state.walletState.lastBlockTimestamp)!)
            )
            
            if state.walletState.syncState == .success {
                self.syncViewController.view.isHidden = true
				self.syncViewController.hideProgress()
            } else if peerManager.shouldShowSyncingView {
                self.syncViewController.view.isHidden = false
				self.syncViewController.showUpProgress()
            } else {
                self.syncViewController.view.isHidden = true
				self.syncViewController.hideProgress()
            }
        })

        store.subscribe(self, selector: { $0.isLoadingTransactions != $1.isLoadingTransactions }, callback: {
            if $0.isLoadingTransactions {
                self.loadingDidStart()
            } else {
                self.hideLoadingView()
            }
        })
        store.subscribe(self, selector: { $0.isLoginRequired != $1.isLoginRequired }, callback: { self.isLoginRequired = $0.isLoginRequired })
        store.subscribe(self, name: .showStatusBar, callback: { _ in
            self.shouldShowStatusBar = true
        })
        store.subscribe(self, name: .hideStatusBar, callback: { _ in
            self.shouldShowStatusBar = false
        })
    }

    private func setInitialData() {
//        searchHeaderview.didChangeFilters = { [weak self] filters in
//            self?.transactionsTableView.filters = filters
//        }
    }

    private func loadingDidStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            if !self.didEndLoading {
                self.showLoadingView()
            }
        })
    }

    private func showLoadingView() {
        view.insertSubview(transactionsLoadingView, belowSubview: headerContainer)
        transactionsLoadingViewTop = transactionsLoadingView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -transactionsLoadingViewHeightConstant)
        transactionsLoadingView.constrain([
            transactionsLoadingViewTop,
            transactionsLoadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transactionsLoadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transactionsLoadingView.heightAnchor.constraint(equalToConstant: transactionsLoadingViewHeightConstant) ])
        transactionsLoadingView.progress = 0.01
        view.layoutIfNeeded()
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.transactionsTableView.tableView.verticallyOffsetContent(transactionsLoadingViewHeightConstant)
            self.transactionsLoadingViewTop?.constant = 0.0
            self.view.layoutIfNeeded()
        }) { completed in
            //This view needs to be brought to the front so that it's above the headerview shadow. It looks weird if it's below.
            self.view.insertSubview(self.transactionsLoadingView, aboveSubview: self.headerContainer)
        }
        loadingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateLoadingProgress), userInfo: nil, repeats: true)
    }
    
    private func hideLoadingView() {
        didEndLoading = true
        guard self.transactionsLoadingViewTop?.constant == 0.0 else { return } //Should skip hide if it's not shown
        loadingTimer?.invalidate()
        loadingTimer = nil
        transactionsLoadingView.progress = 1.0
        view.insertSubview(transactionsLoadingView, belowSubview: headerContainer)
        if transactionsLoadingView.superview != nil {
            UIView.animate(withDuration: C.animationDuration, animations: {
                self.transactionsTableView.tableView.verticallyOffsetContent(-transactionsLoadingViewHeightConstant)
                self.transactionsLoadingViewTop?.constant = -transactionsLoadingViewHeightConstant
                self.view.layoutIfNeeded()
            }) { completed in
                self.transactionsLoadingView.removeFromSuperview()
            }
        }
    }

    @objc private func updateLoadingProgress() {
        transactionsLoadingView.progress = transactionsLoadingView.progress + (1.0 - transactionsLoadingView.progress)/8.0
    }

    private func addTemporaryStartupViews() {
        view.addSubview(tempView)
        tempView.constrain(toSuperviewEdges: nil)
        showActivity(tempView)
        
        guardProtected(queue: DispatchQueue.main) {
            if !WalletManager.staticNoWallet {
                self.addChildViewController(self.tempLoginView, layout: {
                    self.tempLoginView.view.constrain(toSuperviewEdges: nil)
                })
            } else {
                self.tempView.removeFromSuperview()
                
                let startView = StartViewController(
                    store: self.store,
                    didTapCreate: {},
                    didTapRecover: {}
                )
                self.addChildViewController(startView, layout: {
                    startView.view.constrain(toSuperviewEdges: nil)
                    startView.view.isUserInteractionEnabled = false
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    startView.remove()
                })
            }
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let viewControllerIndex = self.pages.firstIndex(of: viewController) {
            if viewControllerIndex != 0 {
                // go to previous page in array
                return self.pages[viewControllerIndex - 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let viewControllerIndex = self.pages.firstIndex(of: viewController) {
            if viewControllerIndex < self.pages.count - 1 {
                // go to next page in array
                return self.pages[viewControllerIndex + 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else { return }
        if let viewControllers = pageViewController.viewControllers {
            if let viewControllerIndex = self.pages.firstIndex(of: viewControllers[0]) {
                menu.updateSegmentedControlSegs(index: viewControllerIndex)
            }
        }
    }
    
    private func addTransactionsView() {
        addChildViewController(pageController, layout: {
            pageController.view.constrain([
                pageController.view.topAnchor.constraint(equalTo: menu.bottomAnchor),
                pageController.view.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                pageController.view.rightAnchor.constraint(equalTo: self.view.rightAnchor),
                pageController.view.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor)
            ])
        })
        
        edgeGesture.delaysTouchesBegan = true
        pageController.scrollView?.panGestureRecognizer.require(toFail: edgeGesture)
        
        let insets = UIEdgeInsets(
            top: 15,
            left: 0,
            bottom: E.isIPhoneXOrGreater ? footerHeight + C.padding[2] + 19 : footerHeight + C.padding[2],
            right: 0
        )
        
        transactionsTableView.tableView.contentInset = insets
        transactionsTableViewForSentTransactions.tableView.contentInset = insets
        transactionsTableViewForReceivedTransactions.tableView.contentInset = insets
        
        pageController.dataSource = self
        pageController.delegate = self
        pages.append(transactionsTableView)
        pages.append(transactionsTableViewForSentTransactions)
        pages.append(transactionsTableViewForReceivedTransactions)
        pageController.setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)
    }

    private func addAppLifecycleNotificationEvents() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { note in
            UIView.animate(withDuration: 0.1, animations: {
                self.blurView.alpha = 0.0
            }, completion: { _ in
                self.blurView.removeFromSuperview()
            })
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { note in
            if !self.isLoginRequired && !self.store.state.isPromptingBiometrics {
                self.blurView.alpha = 1.0
                self.view.addSubview(self.blurView)
                self.blurView.constrain(toSuperviewEdges: nil)
            }
        }
    }

    private func showJailbreakWarnings(isJailbroken: Bool) {
        guard isJailbroken else { return }
        let totalSent = walletManager?.wallet?.totalSent ?? 0
        let message = totalSent > 0 ? S.JailbreakWarnings.messageWithBalance : S.JailbreakWarnings.messageWithBalance
        let alert = AlertController(title: S.JailbreakWarnings.title, message: message, preferredStyle: .alert)
        alert.addAction(AlertAction(title: S.JailbreakWarnings.ignore, style: .default, handler: nil))
        if totalSent > 0 {
            alert.addAction(AlertAction(title: S.JailbreakWarnings.wipe, style: .default, handler: nil)) //TODO - implement wipe
        } else {
            alert.addAction(AlertAction(title: S.JailbreakWarnings.close, style: .default, handler: { _ in
                exit(0)
            }))
        }
        present(alert, animated: true, completion: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return searchHeaderview.isHidden ? .lightContent : .default
    }

    override var prefersStatusBarHidden: Bool {
        return !shouldShowStatusBar
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//// To make the edge gesture recognizer work above transaction list
extension UIPageViewController {
    public var scrollView: UIScrollView? {
        for view in self.view.subviews {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
        }
        return nil
    }
    
}
//extension AccountViewController: UIGestureRecognizerDelegate {
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return false
//    }
//
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return false
//    }
//}

