//
//  DACreateViewController.swift
//  digibyte
//
//  Created by Yoshi Jaeger on 29.03.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

fileprivate class CreateNewAssetCell: PaddedCell {
    let backgroundImage = UIImageView(image: UIImage(named: "da-new-asset-bg"))
    let headingLabel = UILabel(font: UIFont.da.customBold(size: 20), color: .white)
    let getStartedBtn = DAButton(title: S.Assets.getStarted.uppercased(), backgroundColor: UIColor.da.darkSkyBlue)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundView = backgroundImage
        backgroundColor = .clear
        selectionStyle = .none
        
        // add elements
        contentView.addSubview(headingLabel)
        contentView.addSubview(getStartedBtn)
        
        headingLabel.constrain([
            headingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            headingLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
        ])
        
        getStartedBtn.constrain([
            getStartedBtn.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -16),
            getStartedBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            getStartedBtn.widthAnchor.constraint(equalToConstant: 122)
        ])
        
        headingLabel.textAlignment = .right
        headingLabel.text = S.Assets.createNewAsset
        getStartedBtn.label.font = UIFont.da.customBold(size: 12)
        getStartedBtn.height = 34
        
        getStartedBtn.touchUpInside = {
            let url = URL(string: "https://createdigiassets.com")!
            UIApplication.shared.open(url)
        }
        
        contentView.heightAnchor.constraint(equalToConstant: 128).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DACreateViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // MARK: Private
    private let store: BRStore
    private let walletManager: WalletManager
    
    private var loadingAssetsModalView = DGBModalLoadingView(title: S.Assets.fetchingAssetsTitle)
    private var assetResolver: AssetResolver? = nil
    
    private let emptyImage: UIImageView = UIImageView()
    private let emptyContainer = UIView() // will be displayed when there is no asset in the wallet
    private let createNewAssetButton = DAButton(title: S.Assets.createNewAsset, backgroundColor: UIColor.da.darkSkyBlue)
    private let receiveAssetsButton = DAButton(title: S.Assets.receiveAssets, backgroundColor: UIColor.da.secondaryGrey)
    
    private let mainView = UIView()
    private let mainHeader = DAMainAssetHeader(S.Assets.createAssets)
    private let tableView = UITableView(frame: .zero)
    private let tableViewBorder = UIView()
    
    private let emptyLabel = UILabel(font: UIFont.da.customBold(size: 22), color: .white)
    
    private var decelerate: Bool = false
    private var showTableViewBorder: Bool = false {
        willSet {
            if newValue != showTableViewBorder {
                if newValue {
                    UIView.animate(withDuration: 0.3) { [weak tableViewBorder] in
                        tableViewBorder?.alpha = 1.0
                    }
                } else {
                    UIView.animate(withDuration: 0.3, animations: { [weak tableViewBorder] in
                        tableViewBorder?.alpha = 0.0
                    }) { [weak self] _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            self?.decelerate = false
                        })
                    }
                }
            }
        }
    }
    
    init(store: BRStore, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
        
        emptyImage.image = UIImage(named: "da-empty")
        
        tabBarItem = UITabBarItem(title: S.Assets.tabCreate, image: UIImage(named: "da-create")?.withRenderingMode(.alwaysTemplate), tag: 0)
        
        addSubviews()
        setContent()
        addEvents()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setContent() {
        emptyLabel.text = S.Assets.nothingFoundHere
        emptyLabel.text = ""
        
        createNewAssetButton.height = 46.0
        receiveAssetsButton.height = 46.0
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = .clear
        
        tableViewBorder.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        tableViewBorder.alpha = 0.0
    }
    
    private func addEvents() {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.tintColor = UIColor(red: 0xF2 / 255, green: 0xF9 / 255, blue: 0x41 / 255, alpha: 1.0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
        
        self.becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    private func addSubviews() {
        emptyContainer.addSubview(emptyImage)
        emptyContainer.addSubview(emptyLabel)
        emptyContainer.addSubview(createNewAssetButton)
        emptyContainer.addSubview(receiveAssetsButton)
        view.addSubview(emptyContainer)
        
        /* empty view, that is shown when there are no assets created yet */
        emptyImage.constrain([
            emptyImage.widthAnchor.constraint(equalTo: emptyContainer.widthAnchor, multiplier: 1.0),
            emptyImage.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyImage.topAnchor.constraint(equalTo: emptyContainer.topAnchor),
        ])
    
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = UIColor.gray
        
        emptyLabel.constrain([
            emptyLabel.topAnchor.constraint(equalTo: emptyImage.bottomAnchor, constant: 12),
            emptyLabel.leftAnchor.constraint(equalTo: emptyContainer.leftAnchor, constant: 0),
            emptyLabel.rightAnchor.constraint(equalTo: emptyContainer.rightAnchor, constant: 0),
        ])
        
        createNewAssetButton.constrain([
            createNewAssetButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 30),
            createNewAssetButton.leftAnchor.constraint(equalTo: emptyContainer.leftAnchor, constant: 0),
            createNewAssetButton.rightAnchor.constraint(equalTo: emptyContainer.rightAnchor, constant: 0),
        ])
        
        receiveAssetsButton.constrain([
            receiveAssetsButton.topAnchor.constraint(equalTo: createNewAssetButton.bottomAnchor, constant: 16),
            receiveAssetsButton.leftAnchor.constraint(equalTo: emptyContainer.leftAnchor, constant: 0),
            receiveAssetsButton.rightAnchor.constraint(equalTo: emptyContainer.rightAnchor, constant: 0),
            receiveAssetsButton.bottomAnchor.constraint(equalTo: emptyContainer.bottomAnchor, constant: 0),
        ])
        
        emptyContainer.constrain([
            emptyContainer.widthAnchor.constraint(equalToConstant: 198),
            emptyContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        /* main view, that is shown if at least one element is shown */
        view.addSubview(mainView)
        mainView.constrain(toSuperviewEdges: UIEdgeInsets(top: 32, left: 0, bottom: 0, right: 0))
        mainView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: 1.0).isActive = true
        
        mainView.addSubview(mainHeader)
        mainHeader.constrain([
            mainHeader.topAnchor.constraint(equalTo: mainView.topAnchor, constant: 58),
            mainHeader.leftAnchor.constraint(equalTo: mainView.leftAnchor, constant: 32),
            mainHeader.rightAnchor.constraint(equalTo: mainView.rightAnchor, constant: 0),
            mainHeader.heightAnchor.constraint(equalToConstant: 32) /* YOSHI */
        ])
        
        mainView.addSubview(tableViewBorder)
        tableViewBorder.constrain([
            tableViewBorder.topAnchor.constraint(equalTo: mainHeader.bottomAnchor, constant: 18),
            tableViewBorder.leftAnchor.constraint(equalTo: mainView.leftAnchor, constant: -50),
            tableViewBorder.rightAnchor.constraint(equalTo: mainView.rightAnchor, constant: 50),
            tableViewBorder.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        mainView.addSubview(tableView)
        tableView.constrain([
            tableView.topAnchor.constraint(equalTo: tableViewBorder.bottomAnchor, constant: 0),
            tableView.leftAnchor.constraint(equalTo: mainView.leftAnchor, constant: 0),
            tableView.rightAnchor.constraint(equalTo: mainView.rightAnchor, constant: 0),
            tableView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: 0),
        ])
        
        emptyContainer.isHidden = true /* YOSHI */
        mainView.bringSubviewToFront(tableViewBorder)
        
        tableView.backgroundColor = .clear
        tableView.register(AssetCell.self, forCellReuseIdentifier: "asset")
        tableView.register(CreateNewAssetCell.self, forCellReuseIdentifier: "get_started")
        tableView.contentInset = UIEdgeInsets(top: 5, left: 0, bottom: 20, right: 0)
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "get_started") as! CreateNewAssetCell
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= 0 {
            showTableViewBorder = false
        } else {
//            if !decelerate {
                showTableViewBorder = true
//            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        decelerate = false
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.decelerate = true
    }
}
