//
//  AssetDrawer.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 04.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit
import Kingfisher

fileprivate class LogoCell: UITableViewCell {
    private let digiassetsLogo = UIImageView(image: UIImage(named: "digiassets_logo"))
    
    let stackView = UIStackView()
    let icon = UIView()
    let iconInner = UIView()
    let iconIV = UIImageView()
    let headerLabel = UILabel(font: UIFont.da.customBold(size: 20), color: .white)
    let dateLabel = UILabel(font: UIFont.da.customMedium(size: 14), color: .white)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 8
        
        stackView.addArrangedSubview(icon)
        stackView.addArrangedSubview(headerLabel)
        stackView.addArrangedSubview(dateLabel)
        
        contentView.addSubview(stackView)
        contentView.addSubview(digiassetsLogo)
        digiassetsLogo.contentMode = .scaleAspectFit
        
        digiassetsLogo.constrain([
            digiassetsLogo.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            digiassetsLogo.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 0),
            digiassetsLogo.heightAnchor.constraint(equalToConstant: 50),
//            digiassetsLogo.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50),
        ])
        
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: digiassetsLogo.bottomAnchor, constant: 50),
            stackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 15),
            stackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -15),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
        ])
        
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        headerLabel.text = S.Assets.tx
        headerLabel.textAlignment = .center
    
        let padding: CGFloat = 15
        let iconSize: CGFloat = 20
        
        icon.addSubview(iconInner)
        iconInner.addSubview(iconIV)
        
        iconIV.contentMode = .scaleAspectFit
        iconIV.tintColor = UIColor.white
        iconIV.constraint(padding: padding)
        iconIV.constrain([
            iconIV.widthAnchor.constraint(equalToConstant: iconSize),
            iconIV.heightAnchor.constraint(equalToConstant: iconSize),
        ])
        
        iconInner.constrain([
            iconInner.topAnchor.constraint(equalTo: icon.topAnchor, constant: 5),
            iconInner.bottomAnchor.constraint(equalTo: icon.bottomAnchor, constant: -5),
            iconInner.centerXAnchor.constraint(equalTo: icon.centerXAnchor)
        ])
        
        iconInner.layer.cornerRadius = (iconSize + 2 * padding) / 2
        
        dateLabel.textAlignment = .center
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AssetDrawer: UIView {
    private var supervc: DrawerControllerProtocol!
    private let id: String
    
    private var infoModel: TransactionInfoModel?
    private var tx: Transaction?

    private let tableView: UITableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private var contextMenuConstraints = [NSLayoutConstraint]()
    
    private let contextMenu = AssetContextMenu()
    private let contextMenuUnderlay = UIView() // transparent view that closes contextmenu when tapped
    private var contextMenuCtx: String? = nil
    
    private var assetModels = [String: AssetModel]()
    private var assetUtxos = [TransactionOutputModel]()
    private var walletsAssetModels = [AssetHeaderModel]()
    
    var walletManager: WalletManager? = nil
    
    // Callback to show the raw tx
    var callback: ((Transaction) -> Void)? = nil
    
    // Callback to show the asset transaction details (opens up DigiAssets submenu)
    var assetNavigatorCallback: ((AssetMenuAction) -> Void)? = nil /* AssetId, Transaction */
    
    let viewRawTxButton = DAButton(title: S.Assets.rawTx.uppercased(), backgroundColor: UIColor.da.darkSkyBlue)
    
    init(id: String) {
        self.id = id
        super.init(frame: .zero)
        
        addSubviews()
        addConstraints()
        setStyle()
        addEvents()
        
        configureTableView()
    }
    
    private func addSubviews() {
        addSubview(tableView)
        
        addSubview(viewRawTxButton)
        
        addSubview(contextMenuUnderlay)
        addSubview(contextMenu)
    }
    
    private func addConstraints() {
        tableView.constrain(toSuperviewEdges: nil)
        
        contextMenuUnderlay.constrain(toSuperviewEdges: nil)
        contextMenu.translatesAutoresizingMaskIntoConstraints = false
        
        viewRawTxButton.constrain([
            viewRawTxButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -50),
            viewRawTxButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        
        tableView.refreshControl = refreshControl
    }
    
    private func setStyle() {
        backgroundColor = UIColor.da.backgroundColor
        contextMenuUnderlay.isHidden = true
        contextMenu.isHidden = true
        
        viewRawTxButton.label.font = UIFont.da.customBold(size: 12)
        viewRawTxButton.height = 34
        
        refreshControl.tintColor = UIColor.whiteTint
    }
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(LogoCell.self, forCellReuseIdentifier: "logo")
        tableView.register(AssetCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.separatorColor = .clear
        
        tableView.contentInset = UIEdgeInsets(top: 40 + (E.isIPhoneXOrGreater ? 32 : 15), left: 0, bottom: 40, right: 0)
    }
    
    @objc
    private func viewRawTxButtonTapped() {
        guard let tx = self.tx else { return }
        self.callback?(tx)
    }
    
    private func addEvents() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(contextBgTapped))
        contextMenuUnderlay.isUserInteractionEnabled = true
        contextMenuUnderlay.addGestureRecognizer(gr)
        
        viewRawTxButton.touchUpInside = {
            self.viewRawTxButtonTapped()
        }
        
        contextMenu.txBtn.touchUpInside = { [weak self] in
            self?.hideContextMenu()
            self?.supervc.closeDrawer(with: "assets")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let tx = self?.tx, let assetId = self?.contextMenuCtx else { return }
                self?.assetNavigatorCallback?(.showTx(assetId, tx))
            }
        }
        
        contextMenu.sendBtn.touchUpInside = { [weak self] in
            self?.hideContextMenu()
            self?.supervc.closeDrawer(with: "assets")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let assetId = self?.contextMenuCtx else { return }
                self?.assetNavigatorCallback?(.send(assetId))
            }
        }
        
        contextMenu.burnBtn.touchUpInside = { [weak self] in
            self?.hideContextMenu()
            self?.supervc.closeDrawer(with: "assets")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let assetId = self?.contextMenuCtx else { return }
                self?.assetNavigatorCallback?(.burn(assetId))
            }
        }
        
        refreshControl.addTarget(self, action: #selector(refreshTransactionModel), for: .valueChanged)
    }
    
    @objc
    private func refreshTransactionModel() {
        guard let tx = tx else {
            refreshControl.endRefreshing()
            return
        }
        
        let _ = AssetResolver.init(txids: [tx.hash]) { (states) in
            DispatchQueue.main.async {
                guard
                    states.count > 0,
                    !states[0].failed,
                    let infoModel = states[0].transactionInfoModel
                else {
                    self.refreshControl.endRefreshing()
                    return
                }
                
                self.setTransactionInfoModel(for: tx, infoModel: infoModel)
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    func hideContextMenu() {
        contextMenuUnderlay.isHidden = true
        contextMenu.isHidden = true
    }
    
    @objc private func contextBgTapped() {
        // hide context menu
        hideContextMenu()
        
        // reset all button states
        tableView.visibleCells.forEach { (cell) in
            if let cell = cell as? AssetCell {
                cell.menuButton.tintColor = UIColor.da.inactiveColor
            }
        }
    }
    
    func setTransactionInfoModel(for tx: Transaction, infoModel: TransactionInfoModel) {
        self.tx = tx
        self.infoModel = infoModel
        
        refreshAssetModels(for: infoModel)
        
        tableView.reloadData()
    }
    
    func setCloser(supervc: DrawerControllerProtocol?) {
        self.supervc = supervc
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AssetDrawer: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
            case 0:
                return tx != nil ? 1 : 0
            
            case 1:
                return walletsAssetModels.count
            
            default:
                return 0
        }
        
    }
    
    private func refreshAssetModels(for infoModel: TransactionInfoModel) {
        let txid = infoModel.txid
        
        // Reset internal data
        assetUtxos = []
        walletsAssetModels = []
        assetModels = [:]
        
        guard let tx = tx else { return }
        let received = (tx.direction == .received)
        
        // Check if asset utxo is part of wallet
        infoModel.vout.forEach { (utxo) in
            if tx.direction == .moved {
                // Moved DGB-TX: most likely burned assets.
                // Show those, that were not sent to internal wallet
                assetUtxos.append(utxo)
                walletsAssetModels.append(contentsOf: utxo.assets)
                
            }
            
            guard (utxo.scriptPubKey.addresses?.count ?? 0) > 0 else { return }
            let addresses = utxo.scriptPubKey.addresses!
            
            // Only show appropriate direction
            if walletManager?.wallet?.containsAddress(addresses[0]) == received {
                assetUtxos.append(utxo)
                walletsAssetModels.append(contentsOf: utxo.assets)
            }
        }
        
        // Workaround: In case of some BURN-ALL transactions, no models were specified in the outputs.
        // Check if there is one in the inputs
        if walletsAssetModels.count == 0 {
            // Retry with models that were specified in vin
            infoModel.vin.forEach { walletsAssetModels.append(contentsOf: $0.assets) }
        }
        
        // Index the full models of the wallet's assets
        walletsAssetModels.forEach { assetHeaderModel in
            guard let model = AssetHelper.getAssetModel(assetID: assetHeaderModel.assetId) else { return }
            self.assetModels[model.assetId] = model
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let tx = self.tx!
            let cell = tableView.dequeueReusableCell(withIdentifier: "logo", for: indexPath) as! LogoCell
    
            switch (tx.assetType) {
            case .received:
                cell.dateLabel.text = "Received on: \(tx.longTimestamp)"
                cell.iconIV.image = UIImage(named: "da-receive")?.withRenderingMode(.alwaysTemplate)
                cell.iconInner.backgroundColor = UIColor.da.greenApple
            case .sent:
                cell.dateLabel.text = "Sent on: \(tx.longTimestamp)"
                cell.iconIV.image = UIImage(named: "da-send")?.withRenderingMode(.alwaysTemplate)
                cell.iconInner.backgroundColor = UIColor.da.darkSkyBlue
            case .burned:
                cell.dateLabel.text = "Burned on: \(tx.longTimestamp)"
                cell.iconIV.image = UIImage(named: "da-burn")?.withRenderingMode(.alwaysTemplate)
                cell.iconInner.backgroundColor = UIColor.da.burnColor
            case .none:
                cell.dateLabel.text = "Processed on: \(tx.longTimestamp)"
                cell.iconIV.image = UIImage(named: "da-unknown")?.withRenderingMode(.alwaysTemplate)
                cell.iconInner.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            }
            
            return cell
            
        default:
            let tx = self.tx!
            let assetInfo = self.walletsAssetModels[indexPath.row]
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! AssetCell
            
            cell.margins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16 + assetDrawerMarginRight)
            
            let assetId = assetInfo.assetId
            let amount = assetInfo.amount
            let assetModel = assetModels[assetId]!
            
            let amount: Int = {
                if tx.direction == .moved {
                    // ToDo: Use correct asset input id
                    return infoModel?.getBurnAmount(input: 0) ?? 0
                } else {
                    return assetInfo.amount
                }
            }()
            
            cell.imageTappedCallback = { cell in
                guard
                    let id = cell.assetId,
                    let model = AssetHelper.getAssetModel(assetID: id)
                else {
                    return
                }
                
                let vc = DAAssetMediaViewer(assetModel: model)
                guard vc.initialized else {
                    return
                }
                
                guard let viewController = UIApplication.shared.windows.first?.rootViewController else { return }
                viewController.present(vc, animated: true)
            }
            
            cell.assetId = assetId
            cell.configure(showContent: true)
            
            cell.assetLabel.text = assetModel.getAssetName()
            cell.amountLabel.text = "\(amount)"
            
            cell.menuButtonTapped = menuButtonTapped
            cell.menuButton.tintColor = UIColor.da.inactiveColor
            
            cell.assetImage.image = AssetCell.defaultImage
            cell.assetImage.kf.indicatorType = .activity
            
            if let description = assetModel.getDescription() {
                cell.descriptionLabel.text = description
            } else {
                cell.descriptionLabel.text = "No description"
            }
            
            cell.assetIdButton.value = assetModel.assetId
            cell.addressButton.value = tx.toAddress ?? "Unknown"
            cell.infoTextLabel.text = assetModel.getAssetInfo()
            cell.issuerButton.value = assetModel.getIssuer()
            
            if
                let urlModel = assetModel.getImage(),
                let urlStr = urlModel.url,
                let url = URL(string: urlStr)
            {
                cell.assetImage.kf.setImage(with: url)
            }
            
            return cell
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // same function found in DAAssetsViewController. Find a way to reference on function?
    private func menuButtonTapped(cell: AssetCell) {
        if let idx = tableView.indexPath(for: cell) {
            let pos = tableView.rectForRow(at: idx)
            
            contextMenuCtx = cell.assetId
            
            // get global position
            let gpos = tableView.convert(pos, to: self)
            
            // deactivate and remove each constraint
            contextMenuConstraints.forEach { c in
                c.isActive = false
                contextMenu.removeConstraint(c)
            }
            
            // set new constraints
            contextMenuConstraints = [
                contextMenu.trailingAnchor.constraint(equalTo: leadingAnchor, constant: gpos.origin.x + cell.menuButton.frame.origin.x + 10)
            ]
            
            if gpos.origin.y + contextMenu.frame.height > frame.height {
                // stick to bottom
                contextMenuConstraints.append(contextMenu.bottomAnchor.constraint(equalTo: topAnchor, constant: gpos.origin.y + 30))
            } else {
                // stick to top
                contextMenuConstraints.append(contextMenu.topAnchor.constraint(equalTo: topAnchor, constant: gpos.origin.y + 30))
            }
            
            // activate new constraints
            contextMenuConstraints.forEach { c in
                c.isActive = true
            }
            
            // initially scale
            contextMenu.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            // show context menu
            contextMenu.isHidden = false
            contextMenuUnderlay.isHidden = false
            bringSubviewToFront(contextMenuUnderlay)
            bringSubviewToFront(contextMenu)
            
            UIView.spring(0.3, animations: { [weak contextMenu, weak cell] in
                contextMenu?.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                cell?.menuButton.tintColor = UIColor.da.darkSkyBlue
            }) { (_) in
                
            }
        }
    }
}
