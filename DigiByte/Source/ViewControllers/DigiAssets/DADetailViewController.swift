//
//  DADetailViewController.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 08.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

fileprivate class DAAssetPropertyMultilineView: UIView {
    let titleLabel = UILabel(font: UIFont.da.customMedium(size: 18), color: UIColor.da.darkSkyBlue)
    let textView = UITextView(frame: .zero)
    let showContentButton = DAButton(title: S.Assets.tapToShow, backgroundColor: UIColor.da.darkSkyBlue)
    let hideContentButton = DAButton(title: S.Assets.tapToHide, backgroundColor: UIColor.da.darkSkyBlue)
    let callback: (() -> Void)
    
    var heightConstraint: NSLayoutConstraint!
    
    init(title: String, value: String, callback: @escaping (() -> Void)) {
        self.callback = callback
        super.init(frame: .zero)
        
        addSubview(titleLabel)
        addSubview(textView)
        addSubview(showContentButton)
        addSubview(hideContentButton)
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            titleLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
        ])
        
        hideContentButton.constrain([
            hideContentButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            hideContentButton.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0),
        ])
        
        showContentButton.constrain([
            showContentButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            showContentButton.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0),
        ])
        
        textView.constrain([
            textView.topAnchor.constraint(equalTo: showContentButton.bottomAnchor, constant: 8),
            textView.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            textView.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
        ])
        
        heightConstraint = textView.heightAnchor.constraint(equalToConstant: 30)
        heightConstraint.isActive = true
        
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.text = title
        
        textView.textAlignment = .center
        textView.text = value
        textView.layoutIfNeeded()
        textView.backgroundColor = UIColor.clear
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.dataDetectorTypes = .all
        textView.alpha = 0
        textView.font = UIFont.da.customBody(size: 12)
        textView.textColor = UIColor.whiteTint
        
        showContentButton.label.font = UIFont.da.customBold(size: 12)
        hideContentButton.label.font = UIFont.da.customBold(size: 12)
        hideContentButton.alpha = 0
        
        hideContentButton.touchUpInside = { [weak self] in
            self?.hideContentButton.alpha = 0
            self?.showContentButton.alpha = 1
            self?.textView.alpha = 0
            self?.heightConstraint.isActive = true
            
            self?.textView.sizeToFit()
            self?.callback()
        }
        
        showContentButton.touchUpInside = { [weak self] in
            self?.hideContentButton.alpha = 1
            self?.showContentButton.alpha = 0
            self?.textView.alpha = 1
            self?.heightConstraint.isActive = false
            
            self?.textView.sizeToFit()
            self?.callback()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class DAAssetPropertyView: UIView {
    let titleLabel = UILabel(font: UIFont.da.customMedium(size: 18), color: UIColor.da.darkSkyBlue)
    let descriptionLabel = UILabel(font: UIFont.da.customMedium(size: 12), color: .white)
    
    init(title: String, value: String) {
        super.init(frame: .zero)
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            titleLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
        ])
        
        descriptionLabel.constrain([
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            descriptionLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
        ])
        
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.text = title
        
        descriptionLabel.textAlignment = .center
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.numberOfLines = 0
        descriptionLabel.text = value
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class DACopyableAssetPropertyView: UIView {
    let titleLabel = UILabel(font: UIFont.da.customMedium(size: 18), color: UIColor.da.darkSkyBlue)
    let descriptionButton = DAButton(title: "", backgroundColor: UIColor.clear, height: 25, radius: nil)
    let callback: ((String) -> Void)
    let value: String
    
    init(title: String, value: String, callback: @escaping ((String) -> Void)) {
        self.value = value
        self.callback = callback
        super.init(frame: .zero)
        
        addSubview(titleLabel)
        addSubview(descriptionButton)
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            titleLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
        ])
        
        descriptionButton.constrain([
            descriptionButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionButton.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            descriptionButton.rightAnchor.constraint(equalTo: rightAnchor, constant: 0),
            descriptionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
        ])
        
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.text = title
        
        descriptionButton.label.numberOfLines = 0
        descriptionButton.label.lineBreakMode = .byWordWrapping
        descriptionButton.label.font = UIFont.da.customMedium(size: 12)
        descriptionButton.label.text = value
        
        descriptionButton.touchUpInside = { [weak self] in
            guard let myself = self else { return }
            myself.callback(myself.value)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class DATransactionView: UIView {
    private let infoStackView = UIStackView()
    
    let icon = UIImageView()
    let iconContainer = UIView()
    let amountLabel = UILabel(font: UIFont.da.customBody(size: 14), color: UIColor.white)
    let dateLabel = UILabel(font: UIFont.da.customBody(size: 14), color: UIColor.gray)
    
    let txHash: String
    
    init(hash: String) {
        self.txHash = hash
        super.init(frame: .zero)
        
        addSubview(iconContainer)
        iconContainer.addSubview(icon)
        addSubview(infoStackView)
        infoStackView.addArrangedSubview(amountLabel)
        infoStackView.addArrangedSubview(dateLabel)
        
        iconContainer.constrain([
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            iconContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: 0),
            iconContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            iconContainer.widthAnchor.constraint(equalToConstant: 48)
        ])
        
        icon.constrain([
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor, constant: 0),
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor, constant: 0),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.widthAnchor.constraint(equalToConstant: 22)
        ])
        
        infoStackView.constrain([
            infoStackView.leftAnchor.constraint(equalTo: iconContainer.rightAnchor, constant: 15),
            infoStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -15),
            infoStackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0)
        ])
        
        infoStackView.distribution = .fill
        infoStackView.alignment = .fill
        infoStackView.axis = .horizontal
        infoStackView.spacing = 8
        
        amountLabel.textAlignment = .left
        dateLabel.textAlignment = .right
        
        heightAnchor.constraint(equalToConstant: 56).isActive = true
        
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        
        backgroundColor = UIColor.da.headerBackgroundColor
        layer.cornerRadius = 3
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DADetailViewController: UIViewController {
    enum PropertyType {
        case copyable
        case textView
        case label
    }
    
    struct AssetTransaction {
        let hash: String
        var type: Transaction.AssetTransactionType
        var amount: Int
        var timestamp: Int
    }
    
    private let store: BRStore
    private let walletManager: WalletManager
    private let assetModel: AssetModel
    
    private let closeButton = UIButton.close
    
    private let scrollView = UIScrollView()
    
    private let headerBackgroundView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    
    private let stackView = UIStackView()
    
    private let transactionListView = UIStackView();
    
    init(store: BRStore, walletManager: WalletManager, assetModel: AssetModel) {
        self.store = store
        self.walletManager = walletManager
        self.assetModel = assetModel
        
        super.init(nibName: nil, bundle: nil)
        
        addSubviews()
        addConstraints()
        addEvents()
        
        setStyle()
        setContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(headerBackgroundView)
        headerBackgroundView.addSubview(imageView)
        headerBackgroundView.addSubview(titleLabel)
        headerBackgroundView.addSubview(closeButton)
        headerBackgroundView.addSubview(stackView)
        
        scrollView.addSubview(transactionListView)
    }
    
    private func addConstraints() {
        headerBackgroundView.constrainTopCorners(sidePadding: 0, topPadding: 0)
        headerBackgroundView.constrain([
            headerBackgroundView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0)
        ])
        
        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
            
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.0, constant: 0),
            scrollView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1.0, constant: 0),
        ])
        
        closeButton.constrain([
            closeButton.topAnchor.constraint(equalTo: headerBackgroundView.topAnchor, constant: 15),
            closeButton.leadingAnchor.constraint(equalTo: headerBackgroundView.leadingAnchor, constant: 15),
        ])
        
        closeButton.pin(toSize: CGSize(width: 44.0, height: 44.0))
        
        titleLabel.constrain([
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor, constant: 0),
            titleLabel.rightAnchor.constraint(equalTo: headerBackgroundView.rightAnchor, constant: -30),
            titleLabel.leftAnchor.constraint(equalTo: headerBackgroundView.leftAnchor, constant: 30),
        ])
        
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            imageView.centerXAnchor.constraint(equalTo: headerBackgroundView.centerXAnchor, constant: 0),
            imageView.widthAnchor.constraint(equalToConstant: 128),
            imageView.heightAnchor.constraint(equalToConstant: 128),
        ])
        
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 15),
            stackView.leftAnchor.constraint(equalTo: headerBackgroundView.leftAnchor, constant: 15),
            stackView.rightAnchor.constraint(equalTo: headerBackgroundView.rightAnchor, constant: -15),
            stackView.bottomAnchor.constraint(equalTo: headerBackgroundView.bottomAnchor, constant: -30),
        ])
        
        transactionListView.constrain([
            transactionListView.topAnchor.constraint(equalTo: headerBackgroundView.bottomAnchor, constant: 16),
            transactionListView.leftAnchor.constraint(equalTo: headerBackgroundView.leftAnchor, constant: 15),
            transactionListView.rightAnchor.constraint(equalTo: headerBackgroundView.rightAnchor, constant: -15),
            transactionListView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
        ])
    }
       
    private func addEvents() {
        closeButton.tap = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        
        let tapGr = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGr)
    }
    
    @objc
    private func imageTapped() {
        let vc = DAAssetMediaViewer(assetModel: assetModel)
        guard vc.initialized else {
            return
        }
        self.present(vc, animated: true)
    }
       
    private func setStyle() {
        view.backgroundColor = UIColor.da.backgroundColor
        headerBackgroundView.backgroundColor = UIColor.da.headerBackgroundColor
        
        titleLabel.textColor = UIColor.white
        titleLabel.font = UIFont.da.customBold(size: 20)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        
        imageView.image = AssetCell.defaultImage
        imageView.contentMode = .scaleAspectFit
        imageView.kf.indicatorType = .activity
        
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 12
        
        transactionListView.axis = .vertical
        transactionListView.alignment = .fill
        transactionListView.distribution = .fill
        transactionListView.spacing = 8
        
        scrollView.isDirectionalLockEnabled = true
    }
    
    private func addAssetProperties() {
        stackView.arrangedSubviews.forEach { (view) in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        var properties = [String: String?]()
        var type = [String: PropertyType]()
        
        let AssetIdKey = S.Assets.assetIdKey
        let BalanceKey = S.Assets.balanceKey
        let IssuerKey = S.Assets.issuerKey
        let AssetInfoKey = S.Assets.assetInfoKey
        let DescriptionKey = S.Assets.descriptionKey
        
        let keys: [String] = [AssetIdKey, BalanceKey, IssuerKey, AssetInfoKey, DescriptionKey]
        
        let balance = AssetHelper.allBalances[assetModel.assetId] ?? 0
        properties[BalanceKey] = "\(balance)"
        properties[AssetIdKey] = assetModel.assetId
        properties[DescriptionKey] = assetModel.getDescription()
        properties[IssuerKey] = assetModel.getIssuer()
        properties[AssetInfoKey] = assetModel.getAssetInfo(separator: "\n")
        
        type[BalanceKey] = .copyable
        type[AssetIdKey] = .copyable
        type[DescriptionKey] = .textView
        type[IssuerKey] = .copyable
        type[AssetInfoKey] = .label
        
        keys.forEach { (key) in
            guard
                let valueOpt = properties[key],
                let value = valueOpt
            else {
                return
            }
                    
            switch(type[key]) {
                case .copyable:
                    stackView.addArrangedSubview(DACopyableAssetPropertyView(title: key, value: value, callback: { [weak self] val in
                        self?.showAlert(with: S.Receive.copied)
                        UIPasteboard.general.string = val
                    }))
                
                case .textView:
                    // Add Multiline View with Link Highlighting, also define a callback
                    // that is supposed to refresh the stackViews layout.
                    stackView.addArrangedSubview(DAAssetPropertyMultilineView(title: key, value: value, callback: { [weak self] in
                        self?.view.layoutIfNeeded()
                    }))
                
                case .label:
                    stackView.addArrangedSubview(DAAssetPropertyView(title: key, value: value))
                
                default:
                    return
            }
        }
    }
    
    @objc
    private func showTransaction(_ sender: UITapGestureRecognizer) {
        guard let selectedTxView = sender.view as? DATransactionView else { return }
        var data = [String: String]()
        data["tx"] = selectedTxView.txHash
        
        if let presenter = presentingViewController {
            dismiss(animated: true) {
                presenter.dismiss(animated: true, completion: {
                    // Open Drawer in Account View Controller
                    AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.assetTxSelected, object: nil, userInfo: data)
                })
            }
        } else {
            dismiss(animated: true) {
                AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.assetTxSelected, object: nil, userInfo: data)
            }
        }
    }
    
    private func addTransactions() {
        transactionListView.arrangedSubviews.forEach { (view) in
            transactionListView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        var transactions = [AssetTransaction]()
        
        // Collect transactions
        walletManager.store.state.walletState.transactions.forEach({ tx in
            guard tx.isAssetTx else { return }
            guard let infoModel = AssetHelper.getTransactionInfoModel(txid: tx.hash) else { return }
            let received = (tx.direction == .received)
            
            infoModel.vout.forEach { (utxo) in
                utxo.assets.forEach { (assetHeaderModel) in
                    guard
                        walletManager.wallet?.hasUtxo(txid: tx.hash, n: utxo.n) == received ||
                        tx.direction == .moved
                    else {
                        return
                    }
                    
                    guard assetHeaderModel.assetId == assetModel.assetId else { return }
                    var atx = AssetTransaction(hash: tx.hash, type: .burned, amount: 0, timestamp: 0)
                    
                    if tx.direction == .moved {
                        atx.type = .burned
                        atx.amount = infoModel.getBurnAmount(input: 0) ?? 0
                    } else if tx.direction == .received {
                        atx.type = .received
                        atx.amount = assetHeaderModel.amount
                    } else if tx.direction == .sent {
                        atx.type = .sent
                        atx.amount = assetHeaderModel.amount
                    }
                    
                    atx.timestamp = tx.timestamp
                    transactions.append(atx)
                }
            }
        })
        
        // Sort and display
        transactions.sorted(by: { (a, b) -> Bool in
            return a.timestamp > b.timestamp
        }).forEach { (tx) in
            let view = DATransactionView(hash: tx.hash)
            view.isUserInteractionEnabled = true
            
            let tapGr = UITapGestureRecognizer(target: self, action: #selector(showTransaction(_:)))
            view.addGestureRecognizer(tapGr)
            
            switch (tx.type) {
                case .burned:
                    view.icon.image = UIImage(named: "da-burn")?.withRenderingMode(.alwaysTemplate)
                    view.iconContainer.backgroundColor = UIColor.da.burnColor
                    view.amountLabel.text = "-\(tx.amount)"
                    
                case .sent:
                    view.icon.image = UIImage(named: "da-send")?.withRenderingMode(.alwaysTemplate)
                    view.iconContainer.backgroundColor = UIColor.da.darkSkyBlue
                    view.amountLabel.text = "-\(tx.amount)"
                
                case .received:
                    view.icon.image = UIImage(named: "da-receive")?.withRenderingMode(.alwaysTemplate)
                    view.iconContainer.backgroundColor = UIColor.da.greenApple
                    view.amountLabel.text = "+\(tx.amount)"
                
                case .none:
                    view.icon.image = UIImage(named: "da-unknown")?.withRenderingMode(.alwaysTemplate)
                    view.iconContainer.backgroundColor = UIColor.da.greenApple
                    view.amountLabel.text = "+\(tx.amount)"
            }
            
            // Serialize date with format MMMM d/yyy
            let date = Date(timeIntervalSince1970: Double(tx.timestamp))
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("MMMM d, yyy")
            view.dateLabel.text = df.string(from: date)
            
            transactionListView.addArrangedSubview(view)
        }
    }
    
    private func setContent() {
        titleLabel.text = assetModel.getAssetName()
        
        if
            let urlModel = assetModel.getImage(),
            let urlStr = urlModel.url,
            let url = URL(string: urlStr)
        {
            imageView.kf.setImage(with: url)
        }
        
        addAssetProperties()
        addTransactions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print(view.bounds)
        print(view.frame)
    }
}
