//
//  DAReceiveViewController.swift
//  digibyte
//
//  Created by Yoshi Jaeger on 29.03.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

fileprivate let qrBorder: CGFloat = 200
fileprivate let qrBorderSize: CGFloat = 16
fileprivate let qrSize: CGFloat = qrBorder - qrBorderSize * 2

fileprivate func createVerticalSpacingView(_ height: CGFloat = 16) -> UIView {
    let v = UIView()
    
    v.heightAnchor.constraint(equalToConstant: height).isActive = true
    v.backgroundColor = .clear
    
    return v
}

fileprivate func createHorizontalSpacingView(_ width: CGFloat = 16) -> UIView {
    let v = UIView()
    
    v.widthAnchor.constraint(equalToConstant: width).isActive = true
    v.backgroundColor = .clear
    
    return v
}


fileprivate class ColorButton: UIView {
    let color: UIColor
    let innerView = UIView()
    var tapGr: UITapGestureRecognizer!
    
    private let callback: ((UIColor) -> Void)
    
    init(_ color: UIColor, callback: @escaping ((UIColor) -> Void)) {
        self.color = color
        self.callback = callback
        super.init(frame: .zero)
        
        addSubview(innerView)
        innerView.constrain([
            innerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            innerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            innerView.widthAnchor.constraint(equalToConstant: 16),
            innerView.heightAnchor.constraint(equalToConstant: 16),
        ])
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        
        innerView.layer.cornerRadius = 8
        innerView.layer.masksToBounds = true
        innerView.layer.borderColor = UIColor.white.cgColor
        innerView.backgroundColor = color
        innerView.layer.borderWidth = 1
        
        isUserInteractionEnabled = true
        tapGr = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tapGr)
    }
    
    func select() {
        innerView.layer.borderWidth = 3
    }
    
    func deselect() {
        innerView.layer.borderWidth = 1
    }
    
    @objc
    private func tapped() {
        callback(color)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate func pad(_ pad: CGFloat, _ view: UIView) -> UIView {
    let v = UIView()
    
    v.addSubview(view)
    
    v.heightAnchor.constraint(equalToConstant: qrBorder).isActive = true
    v.widthAnchor.constraint(equalToConstant: qrBorder).isActive = true
    
    view.constrain([
        view.centerXAnchor.constraint(equalTo: v.centerXAnchor),
        view.centerYAnchor.constraint(equalTo: v.centerYAnchor),
    ])
    
    return v
}

class DAReceiveViewController: UIViewController {
    private var hc: NSLayoutConstraint? = nil
    private let store: BRStore
    private let walletManager: WalletManager
    private var useSegwit: Bool = false
    private var currentAddress: String = ""
    private var selectedColor = UIColor.black
    
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    
    let header = UILabel(font: UIFont.da.customBold(size: 20), color: .white)
    let assetDropdown = DADropDown()
    let totalBalanceLabel = UILabel(font: UIFont.da.customMedium(size: 13), color: UIColor.da.secondaryGrey)
    let receivingAddressBox = DATextBox(showPasteButton: true)
    let colorSelectionContainer = UIStackView()
    let shareButton = UIButton()
    private var colors = [ColorButton]()
    private let requestLegacyAddressButton = UIButton()
    
    let qrCodeContainer = UIView()
    let qrCode = UIImageView()
    
    var selectedModel: AssetModel? = nil {
        didSet {
            modelSelected()
        }
    }
    
    init(store: BRStore, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
        
        tabBarItem = UITabBarItem(title: S.Assets.tabReceive, image: UIImage(named: "da-receive")?.withRenderingMode(.alwaysTemplate), tag: 0)
        
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        scrollView.alwaysBounceVertical = true
        
        stackView.spacing = 9
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.axis = .vertical
        
        header.text = S.Assets.receiveAssets
        header.textAlignment = .left
        
        totalBalanceLabel.text = " "
        totalBalanceLabel.textAlignment = .left
        
        shareButton.setImage(UIImage(named: "da-share")?.withRenderingMode(.alwaysTemplate), for: .normal)
        shareButton.tintColor = UIColor.white
        
        requestLegacyAddressButton.titleLabel?.textAlignment = .center
        requestLegacyAddressButton.titleLabel?.font = UIFont.da.customMedium(size: 12)
        requestLegacyAddressButton.titleLabel?.numberOfLines = 0
        requestLegacyAddressButton.setTitleColor(UIColor.whiteTint, for: .normal)
        requestLegacyAddressButton.titleLabel?.lineBreakMode = .byWordWrapping
        requestLegacyAddressButton.addTarget(self, action: #selector(segwitSwitchTapped), for: .touchUpInside)
        
        updateAlternativeAddressButton()
        
        colorSelectionContainer.axis = .horizontal
        colorSelectionContainer.alignment = .center
        colorSelectionContainer.distribution = .equalCentering
        colorSelectionContainer.spacing = 5
        
        [UIColor.black, UIColor.da.darkSkyBlue, UIColor.da.orange, UIColor.da.greenApple, UIColor.da.burnColor].forEach { color in
            colors.append(ColorButton(color, callback: { [unowned self] (c) in
                self.selectedColor = c
                self.updateColors()
            }))
        }
        
        colorSelectionContainer.addArrangedSubview(createHorizontalSpacingView(50))
        colors.forEach { (color) in
            colorSelectionContainer.addArrangedSubview(color)
        }
        colorSelectionContainer.addArrangedSubview(createHorizontalSpacingView(50))
        
        assetDropdown.setContent(asset: nil)
        
        let q = pad(qrBorderSize, qrCode)
        qrCodeContainer.addSubview(q)
        q.constrain([
            q.centerXAnchor.constraint(equalTo: qrCodeContainer.centerXAnchor),
            q.topAnchor.constraint(equalTo: qrCodeContainer.topAnchor),
            q.bottomAnchor.constraint(equalTo: qrCodeContainer.bottomAnchor),
        ])
        
        qrCode.constrain([
            qrCode.widthAnchor.constraint(equalToConstant: qrSize),
            qrCode.heightAnchor.constraint(equalToConstant: qrSize),
        ])
        q.layer.borderWidth = 16
        q.layer.borderColor = UIColor.white.cgColor
        q.layer.cornerRadius = 12
        q.layer.masksToBounds = true
        
        qrCode.image = UIImage.qrCode(data: "NO DATA ENCODED HERE, DAWG!".data(using: .ascii)!, color: CIColor(color: .black))?.resize(CGSize(width: qrSize, height: qrSize))
        
        
        if !UserDefaults.excludeLogoInQR {
            qrCode.image = placeLogoIntoQR(qrCode.image!, width: qrSize, height: qrSize, logo: UIImage(named: "da_filled"))
        }
        
        qrCodeContainer.isUserInteractionEnabled = true
        qrCodeContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(qrCodeTapped)))
        qrCodeContainer.alpha = 0.3
        qrCode.backgroundColor = UIColor.white
        qrCode.contentMode = .scaleAspectFit
        
        stackView.addArrangedSubview(header)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        // Asset request disabled for this release build.
        // Wait until we have a proposal for requesting certain assets
//        stackView.addArrangedSubview(assetDropdown)
//        stackView.addArrangedSubview(totalBalanceLabel)
//        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(qrCodeContainer)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(colorSelectionContainer)
        stackView.addArrangedSubview(createVerticalSpacingView())
    
        stackView.addArrangedSubview(receivingAddressBox)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(shareButton)
        stackView.addArrangedSubview(createVerticalSpacingView())
        
        stackView.addArrangedSubview(UIView())
        
        receivingAddressBox.placeholder = S.Receive.receiveAddress
        receivingAddressBox.copyMode = true
        receivingAddressBox.textBox.isEnabled = false
        receivingAddressBox.textBox.text = S.Assets.unknown
        
        stackView.addArrangedSubview(requestLegacyAddressButton)
        
        addConstraints()
        addEvents()
        
        if let wallet = walletManager.wallet {
            currentAddress = wallet.getReceiveAddress(useSegwit: useSegwit)
            receivingAddressBox.textBox.text = currentAddress
        }
        
        updateColors()
    }
    
    private func updateColors() {
        colors.forEach { (button) in
            if button.color == selectedColor {
                button.select()
            } else {
                button.deselect()
            }
        }
        
        updateQr(enabled: true)
    }
    
    private func updateAlternativeAddressButton() {
        if useSegwit {
            requestLegacyAddressButton.setTitle(S.Receive.showLegacyAddress, for: .normal)
        } else {
            requestLegacyAddressButton.setTitle(S.Receive.showSegwitAddress, for: .normal)
        }
    }
    
    @objc
    private func qrCodeTapped() {
        guard qrCodeContainer.alpha == 1 else { return }
        
        qrCodeContainer.alpha = 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.qrCodeContainer.alpha = 1.0
        }
        
        showAlert(with: S.Receive.copied)
        UIPasteboard.general.image = qrCode.image
        
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
    }
    
    @objc
    private func segwitSwitchTapped() {
        guard let wallet = walletManager.wallet else { return }
        useSegwit = !useSegwit
        
        currentAddress = wallet.getReceiveAddress(useSegwit: useSegwit)
        receivingAddressBox.textBox.text = currentAddress
        updateAlternativeAddressButton()
        
        updateQr(enabled: true)
    }
    
    @objc
    private func assetDropdownTapped() {
        let assetSelector = DAModalAssetSelector()
        assetSelector.callback = { [weak self] asset in
            self?.selectedModel = asset
        }
        self.present(assetSelector, animated: true, completion: {
            assetSelector.tableView.reloadData()
        })
    }
    
    @objc
    private func shareButtonTapped() {
        let addr = currentAddress
        
        let request = PaymentRequest.requestString(withAddress: addr)
        
        if
            let qrImage = qrCode.image,
            let imgData = qrImage.jpegData(compressionQuality: 1.0),
            let jpegRep = UIImage(data: imgData) {
            let activityViewController = UIActivityViewController(activityItems: [request, jpegRep], applicationActivities: nil)
            activityViewController.completionWithItemsHandler = {(activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
                guard completed else { return }
                if error == nil {
                    self.store.trigger(name: .lightWeightAlert(S.Import.success))
                }
            }
            activityViewController.excludedActivityTypes = [UIActivity.ActivityType.assignToContact, UIActivity.ActivityType.addToReadingList, UIActivity.ActivityType.postToVimeo]
                present(activityViewController, animated: true, completion: {})
        }
    }
    
    private func updateQr(enabled: Bool) {
        let pr = currentAddress
        qrCode.image = UIImage.qrCode(data: pr.data(using: .ascii)!, color: CIColor(color: .black))?.resize(CGSize(width: qrSize, height: qrSize))
        qrCodeContainer.alpha = enabled ? 1.0 : 0.3
        
        if !UserDefaults.excludeLogoInQR {
            var image = UIImage(named: "da_filled")?.withRenderingMode(.alwaysTemplate)
            image = image?.imageWithTintColor(color: selectedColor)
            qrCode.image = placeLogoIntoQR(qrCode.image!, width: 800, height: 800, logo: image)
        }
    }
    
    private func modelSelected() {
        assetDropdown.setContent(asset: selectedModel)
        
        guard
            let assetModel = selectedModel
        else {
            return
        }
        
        // Update total balance
        let balance = AssetHelper.allBalances[assetModel.assetId] ?? 0
        totalBalanceLabel.text = "\(S.Assets.totalBalance): \(balance)"
        totalBalanceLabel.textColor = UIColor(red: 248 / 255, green: 156 / 255, blue: 78 / 255, alpha: 1.0) // 248 156 78
        
        updateQr(enabled: true)
        
        qrCode.image = UIImage.qrCode(data: pr.data(using: .ascii)!, color: CIColor(color: .black))?.resize(CGSize(width: qrSize, height: qrSize))
        qrCodeContainer.alpha = 1.0
        
        if !UserDefaults.excludeLogoInQR {
            qrCode.image = placeLogoIntoQR(qrCode.image!, width: qrSize, height: qrSize, logo: UIImage(named: "da_filled"))
        }
    }
    
    private func addEvents() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(assetDropdownTapped))
        assetDropdown.isUserInteractionEnabled = true
        assetDropdown.addGestureRecognizer(gr)
        
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        
        receivingAddressBox.clipboardButtonTapped = { [unowned self] in
            UIPasteboard.general.string = self.receivingAddressBox.textBox.text
            self.showAlert(with: S.Receive.copied)
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
        tabBarController?.tabBar.tintColor = UIColor.da.greenApple
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
