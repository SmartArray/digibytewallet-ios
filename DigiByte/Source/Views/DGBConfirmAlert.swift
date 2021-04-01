//
//  DGBConfirmAlert.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 01.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit
import Kingfisher

fileprivate class ConfirmButton: DGBHapticButton {
    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? backgroundColor!.withAlphaComponent(0.8) : backgroundColor!.withAlphaComponent(1.0)
        }
    }
}

class DAModalAssetSelector: DGBModalWindow {
    var callback: ((AssetModel?) -> Void)? = nil
    let tableView: UITableView = UITableView()
    
    init() {
        super.init(title: S.Assets.selectAnAsset, padding: 0)
        
        let tv = tableView
        stackView.addArrangedSubview(tv)
        
        let hC = tv.heightAnchor.constraint(equalToConstant: 300)
        hC.priority = .defaultLow
        hC.isActive = true
        
        tv.delegate = self
        tv.dataSource = self
        tv.separatorInset = UIEdgeInsets.zero
        
        tv.register(DAModalAssetSelectorCell.self, forCellReuseIdentifier: "cell")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DAModalAssetSelectorCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
//        guard let iv = imageView else { return }
//        iv.constrain([
//            iv.heightAnchor.constraint(equalToConstant: 32),
//            iv.widthAnchor.constraint(equalToConstant: 32),
//        ])
//
//        iv.contentMode = .scaleAspectFit
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let bounds = CGRect(x: 22, y: 12, width: 32, height: 32)
        self.imageView?.frame = bounds
        self.imageView?.contentMode = .scaleAspectFit
        
        var tempFrame: CGRect!
        let targetX: CGFloat = 77
        var shift: CGFloat!
        
        let totalWidth = self.bounds.width
        
        tempFrame = textLabel!.frame
        shift = tempFrame.origin.x - targetX
        tempFrame.origin.x = targetX
        textLabel!.frame = CGRect(x: tempFrame.origin.x, y: tempFrame.origin.y, width: totalWidth - targetX - 20, height: tempFrame.height)
        
        tempFrame = detailTextLabel!.frame
        shift = tempFrame.origin.x - targetX
        tempFrame.origin.x = targetX
        detailTextLabel!.frame = CGRect(x: tempFrame.origin.x, y: tempFrame.origin.y, width: totalWidth - shift, height: tempFrame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DAModalAssetSelector: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AssetHelper.allAssets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        
        let assetId = AssetHelper.allAssets[indexPath.row]
        let assetModel = AssetHelper.getAssetModel(assetID: assetId) ?? AssetModel.dummy()
    
        cell.textLabel?.text = assetModel.getAssetName()
        
        let amount = AssetHelper.allBalances[assetId] ?? 0
        let subtitleStr = String(format: S.Send.balance, "\(amount)")
        cell.detailTextLabel?.text = subtitleStr
        
        if let urlStr = assetModel.getImage()?.url, let url = URL(string: urlStr) {
            cell.imageView?.kf.setImage(with: url, placeholder: nil, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 32, height: 32) )),
                .scaleFactor(UIScreen.main.scale),
                .transition(ImageTransition.fade(0.2)),
                .cacheOriginalImage
            ], progressBlock: nil, completionHandler: { (result) in
                cell.setNeedsLayout()
            })
            cell.imageView?.tintColor = .clear
        } else {
            cell.imageView?.image = UIImage(named: "digiassets_small")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = UIColor.black.withAlphaComponent(0.7)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let assetId = AssetHelper.allAssets[indexPath.row]
        let assetModel = AssetHelper.getAssetModel(assetID: assetId)
        callback?(assetModel)
        dismiss(animated: true, completion: nil)
    }
}

class DGBModalMediaOptionButton: UIView {
    let imageView = UIImageView()
    let titleLabel = UILabel(font: UIFont.da.customBold(size: 14), color: UIColor.black)
    let accessoryLabel = UILabel(font: UIFont.da.customMedium(size: 12), color: UIColor.lightGray)
    
    var callback: (() -> Void)? = nil
    var isEnabled: Bool {
        didSet {
            updateEnabledState()
        }
    }
    
    init(_ title: String, accessory: String, image: UIImage? = nil, isEnabled: Bool = true) {
        self.isEnabled = isEnabled
        super.init(frame: .zero)
        
        imageView.image = image
        titleLabel.text = title
        accessoryLabel.text = accessory
        
        accessoryLabel.numberOfLines = 3
        accessoryLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(onTap))
        isUserInteractionEnabled = true
        addGestureRecognizer(gr)
        
        let group = UIView()
        group.addSubview(titleLabel)
        group.addSubview(accessoryLabel)
        
        addSubview(imageView)
        addSubview(group)
        
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: group.topAnchor, constant: 0),
            titleLabel.leftAnchor.constraint(equalTo: group.leftAnchor, constant: 0),
            titleLabel.rightAnchor.constraint(equalTo: group.rightAnchor, constant: 0),
        ])
        
        accessoryLabel.constrain([
            accessoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            accessoryLabel.leftAnchor.constraint(equalTo: group.leftAnchor, constant: 0),
            accessoryLabel.rightAnchor.constraint(equalTo: group.rightAnchor, constant: 0),
            accessoryLabel.bottomAnchor.constraint(equalTo: group.bottomAnchor, constant: 0),
        ])
        
        group.constrain([
            group.centerYAnchor.constraint(equalTo: imageView.centerYAnchor, constant: 0),
            group.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: 10),
            group.rightAnchor.constraint(equalTo: rightAnchor, constant: -10),
        ])
        
        updateEnabledState()
    }
    
    private func updateEnabledState() {
        if isEnabled {
            alpha = 1.0
        } else {
            alpha = 0.3
        }
    }
    
    @objc
    private func onTap() {
        guard isEnabled else { return }
        backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.backgroundColor = .clear
        }
        callback?()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DGBModalMediaOptions: DGBModalWindow {
    let callback: ((String) -> Void)
    
    let addressBookBtn: DGBModalMediaOptionButton
    let pasteBtn: DGBModalMediaOptionButton
    let scanBtn: DGBModalMediaOptionButton
    let galleryBtn: DGBModalMediaOptionButton
    
    init(callback: @escaping (String) -> Void) {
        self.callback = callback
        
        if let previewText = UIPasteboard.general.string {
            pasteBtn = DGBModalMediaOptionButton(S.Assets.Send.pasteFromClipboard, accessory: previewText, image: UIImage(named: "paste-colored"))
        } else {
            pasteBtn = DGBModalMediaOptionButton(S.Assets.Send.pasteFromClipboard, accessory: S.Send.emptyPasteboard, image: UIImage(named: "paste-colored"), isEnabled: false)
        }
        
        addressBookBtn = DGBModalMediaOptionButton(S.Assets.Send.addressBook, accessory: S.Assets.Send.addressBookDescription, image: UIImage(named: "address-book-colored"))
        scanBtn = DGBModalMediaOptionButton(S.Assets.Send.scanQR, accessory: S.Assets.Send.scanQRDescription, image: UIImage(named: "scan-colored"))
        galleryBtn = DGBModalMediaOptionButton(S.Assets.Send.browseGallery, accessory: S.Assets.Send.browseGalleryDescription, image: UIImage(named: "gallery-colored"))
        
        super.init(title: S.Assets.Send.importAddress, padding: 0)
    
        stackView.addArrangedSubview(addressBookBtn)
        stackView.addArrangedSubview(pasteBtn)
        stackView.addArrangedSubview(scanBtn)
        stackView.addArrangedSubview(galleryBtn)
        
        addressBookBtn.callback = { [weak self] in
            self?.addressBookTapped()
        }
        
        pasteBtn.callback = { [weak self] in
            self?.pasteTapped()
        }
        
        scanBtn.callback = { [weak self] in
            self?.scanTapped()
        }
        
        galleryBtn.callback = { [weak self] in
            self?.galleryTapped()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func addressBookTapped() {
        let vc = AddressBookOverviewViewController()
        vc.view.backgroundColor = UIColor(red: 21/255, green: 21/255, blue: 31/255, alpha: 1.0)
        vc.contactSelectedCallback = { [weak self, weak vc] contact in
            self?.callback(contact.address)
            vc?.dismiss(animated: true) {
                self?.dismiss(animated: true)
            }
        }
        self.present(vc, animated: true, completion: nil)
    }
    
    @objc private func pasteTapped() {
        guard let pasteboard = UIPasteboard.general.string, pasteboard.utf8.count > 0 else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }
        guard let request = PaymentRequest(string: pasteboard) else {
            return showAlert(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressOnPasteboard, buttonLabel: S.Button.ok)
        }
        
        if let address = request.toAddress {
            callback(address)
            self.dismiss(animated: true, completion: nil)
        }
    }

    @objc private func scanTapped() {
        guard ScanViewController.isCameraAllowed else {
            //self.saveEvent("scan.cameraDenied")
            if let parent = parent {
                ScanViewController.presentCameraUnavailableAlert(fromRoot: parent)
            }
            return
        }
        
        let vc = ScanViewController(completion: { [weak self] paymentRequest in
            guard let address = paymentRequest?.toAddress else { return }
            self?.callback(address)
            self?.parent?.view.isFrameChangeBlocked = false
            self?.dismiss(animated: true, completion: nil)
        }, isValidURI: { address in
            return address.isValidAddress
        })
        
        self.present(vc, animated: true, completion: nil)
    }

    @objc private func galleryTapped() {
        let imagePicker = UIImagePickerController()

        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum;
            imagePicker.allowsEditing = false

            self.present(imagePicker, animated: true, completion: nil)
        }
    }
}

extension DGBModalMediaOptions: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: nil)

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
                            if
                                let payRequest = PaymentRequest(string: decode),
                                let address = payRequest.toAddress {
                                    self.dismiss(animated: true, completion: nil)
                                    self.callback(address)
                                    return
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
}

class DGBModalWindow: UIViewController, UIGestureRecognizerDelegate {
    private let headerTitle: String
    private let titleView = UIView()
    private let titleLabel = UILabel()
    private var tap: UITapGestureRecognizer!
    
    private let padding: CGFloat
    
    let containerView = UIView()
    let stackView = UIStackView()
    
    init(title: String, padding: CGFloat = 8.0) {
        self.headerTitle = title
        self.padding = padding
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .overFullScreen
        transitioningDelegate = self

        addSubviews()
        addConstraints()
        setStyle()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tap = UITapGestureRecognizer(target: self, action: #selector(onTap(sender:)))
        tap.numberOfTapsRequired = 1
        tap.numberOfTouchesRequired = 1
        tap.cancelsTouchesInView = false
        tap.delegate = self
        self.view.window?.addGestureRecognizer(tap)
    }
    
    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard presentedViewController == nil else { return false }
        
        let location = touch.location(in: self.containerView)
        
        if location.x < 0 || location.x > self.containerView.bounds.width {
            return true
        }
        
        if location.y < 0 || location.y > self.containerView.bounds.height {
            return true
        }
        
        return false
    }

    @objc private func onTap(sender: UITapGestureRecognizer) {
        self.view.window?.removeGestureRecognizer(sender)
        self.dismiss(animated: true, completion: nil)
    }
    
    private func addSubviews() {
        view.addSubview(containerView)
        
        titleView.addSubview(titleLabel)
        containerView.addSubview(titleView)
        containerView.addSubview(stackView)
    }
    
    private func addConstraints() {
        containerView.constrainToCenter()
        
        containerView.constrain([
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8),
        ])
        
        titleView.constrain([
            titleView.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            titleView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
        ])
        
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: padding),
            stackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: padding),
            stackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
        ])
        titleLabel.constrain(toSuperviewEdges: UIEdgeInsets(top: padding, left: padding, bottom: -padding, right: -padding))
    }
    
    private func setStyle() {
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        containerView.backgroundColor = UIColor.white
        
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        
        titleView.backgroundColor = UIColor.da.darkSkyBlue
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.text = headerTitle
        titleLabel.font = UIFont.da.customBold(size: 18)
        titleLabel.lineBreakMode = .byWordWrapping
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DGBModalWindow: UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DGBModalAnimationController(false)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DGBModalAnimationController(true)
    }
}

class DGBModalAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    private let presenting: Bool
    
    init(_ presenting: Bool) {
        self.presenting = presenting
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.15
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let vc = transitionContext.viewController(forKey: presenting ? .to : .from)!
        let containerView = transitionContext.containerView
        
        let animationDuration = transitionDuration(using: transitionContext)
        
        vc.view.alpha = presenting ? 0.0 : 1.0
        vc.view.transform = presenting ? CGAffineTransform(scaleX: 0.9, y: 0.9) : CGAffineTransform.identity
        
        if presenting {
            containerView.addSubview(vc.view)
        }
        
        UIView.animate(withDuration: animationDuration, animations: {
            vc.view.alpha = self.presenting ? 1.0 : 0.0
            vc.view.transform = self.presenting ? CGAffineTransform.identity : CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}

typealias DGBCallback = (() -> Void)

class DGBModalLoadingView: DGBModalWindow {
    let ai: UIActivityIndicatorView
    let label = UILabel()
    var gr: UITapGestureRecognizer!
    var tapCount = 0
    
    init(title: String) {
        ai = UIActivityIndicatorView(style: .gray)
        super.init(title: title)
        
        ai.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stackView.addArrangedSubview(ai)
        stackView.addArrangedSubview(label)
        
        gr = UITapGestureRecognizer(target: self, action: #selector(tapped))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(gr)
        
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.da.customBody(size: 14)
        label.lineBreakMode = .byWordWrapping
        label.textColor = UIColor.gray
    }
    
    func updateStep(current: Int, total: Int) {
        label.text = "\(current) / \(total)"
    }
    
    @objc
    private func tapped() {
        // Safe exit (if no outer vc ever dismissed modalLoadingView)
        tapCount = tapCount + 1
        if tapCount >= 3 { self.dismiss(animated: true, completion: nil) }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ai.startAnimating()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ai.stopAnimating()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DGBConfirmAlert: DGBModalWindow {
    let message: String
    let image: UIImage?
    let okTitle: String
    let cancelTitle: String?
    
    var confirmCallback: ((DGBCallback) -> Void)? = nil
    var cancelCallback: ((DGBCallback) -> Void)? = nil
    var alternativeCallback: ((DGBCallback) -> Void)? = nil
    
    let contentLabel = UILabel()
    var imageView: UIImageView!
    let alternativeTitle: String?
    
    private let buttonsView = UIStackView()
    
    private var imageContainer = UIView()
    private var imageView: UIImageView!
    private var okButton: ConfirmButton!
    private var cancelButton: ConfirmButton!
    
    private let alternativeTitle: String?
    
    init(title: String, message: String, image: UIImage?, okTitle: String = S.Alerts.defaultConfirmOkCaption, cancelTitle: String? = S.Alerts.defaultConfirmCancelCaption, alternativeButtonTitle: String? = nil) {
        
        self.message = message
        self.image = image
        self.okTitle = okTitle
        self.cancelTitle = cancelTitle
        self.alternativeTitle = alternativeButtonTitle
        
        super.init(title: title)
        
        imageView = UIImageView(image: image)
    
        okButton = ConfirmButton()
        cancelButton = ConfirmButton()
        
        addSubviews()
        addConstraints()
        setStyle()
        addEvents()
    }
    
    private func addSubviews() {
        // add buttons
        buttonsView.addArrangedSubview(okButton)
        
        if cancelTitle != nil {
            buttonsView.addArrangedSubview(cancelButton)
        }
        
        // add vertical views
        if image != nil {
            imageContainer.addSubview(imageView)
            stackView.addArrangedSubview(imageContainer)
        }
        stackView.addArrangedSubview(contentLabel)
        stackView.addArrangedSubview(buttonsView)
        
        if let title = alternativeTitle {
            let alternativeButton = UIButton()
            alternativeButton.setTitle(title, for: .normal)
            alternativeButton.setTitleColor(UIColor.gray, for: .normal)
            alternativeButton.titleLabel?.textAlignment = .center
            alternativeButton.titleLabel?.font = UIFont.da.customMedium(size: 12)
            alternativeButton.titleLabel?.numberOfLines = 0
            alternativeButton.titleLabel?.lineBreakMode = .byWordWrapping
            alternativeButton.tap = { [weak self] in
                guard let c = self?.closeCallback else { return }
                self?.alternativeCallback?(c)
            }
            stackView.addArrangedSubview(alternativeButton)
        }
    }
    
    private func addConstraints() {
        if image != nil {
            imageView.constrain([
                imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: 0),
                imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: 0),
                imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 180),
                imageView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            ])
        }
            
        if cancelTitle != nil {
            okButton.widthAnchor.constraint(equalTo: cancelButton.widthAnchor, multiplier: 1.0).isActive = true
            okButton.heightAnchor.constraint(equalTo: cancelButton.heightAnchor, multiplier: 1.0).isActive = true
        }
        
        okButton.heightAnchor.constraint(equalToConstant: 45).isActive = true
    }
    
    private func setStyle() {
        stackView.spacing = 16
        
        imageView.contentMode = .scaleAspectFit
        
        buttonsView.axis = .horizontal
        buttonsView.alignment = .fill
        buttonsView.distribution = .fill
        buttonsView.spacing = 8
        
        contentLabel.textAlignment = .left
        contentLabel.numberOfLines = 0
        contentLabel.text = message
        contentLabel.font = UIFont.da.customBody(size: 16)
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.textColor = UIColor.black
        
        okButton.setTitle(okTitle, for: .normal)
        okButton.setTitleColor(UIColor.white, for: .normal)
        okButton.titleLabel?.font = UIFont.da.customBody(size: 16)
        
        if let cancelTitle = self.cancelTitle {
            cancelButton.setTitleColor(UIColor.black, for: .normal)
            cancelButton.setTitle(cancelTitle, for: .normal)
            cancelButton.titleLabel?.font = UIFont.da.customBody(size: 16)
        } else {
            cancelButton.isHidden = true
        }
        
        okButton.backgroundColor = UIColor.da.darkSkyBlue
        okButton.layer.cornerRadius = 8
        okButton.layer.masksToBounds = true
        okButton.titleLabel?.numberOfLines = 0
        okButton.titleLabel?.textAlignment = .center
        okButton.titleLabel?.lineBreakMode = .byWordWrapping
        
        cancelButton.backgroundColor = UIColor(red: 228/255, green: 229/255, blue: 228/255, alpha: 1.0) // grey
        cancelButton.layer.cornerRadius = 8
        cancelButton.layer.masksToBounds = true
        cancelButton.titleLabel?.textAlignment = .center
        cancelButton.titleLabel?.numberOfLines = 0
        cancelButton.titleLabel?.lineBreakMode = .byWordWrapping
    }
    
    private func addEvents() {
        okButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    private lazy var closeCallback: DGBCallback = { () in
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc
    private func confirmTapped() {
        // User is responsible to call the close callback.
        confirmCallback?(closeCallback)
    }
    
    @objc
    private func cancelTapped() {
        cancelCallback?(closeCallback)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("proper deallocation")
    }
}
