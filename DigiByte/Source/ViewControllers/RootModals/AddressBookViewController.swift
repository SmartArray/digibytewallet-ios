//
//  ReceiveViewController.swift
//  breadwallet
//
//  Created by Yoshi Jaeger on 2018-11-18.
//  Copyright © 2018 DigiByte. All rights reserved.
//

import UIKit

fileprivate let ADDRESSBOOK_VERSION: Int = 2

func hBox(_ view: UIView, horizontal padding: CGFloat) -> UIView {
    let v = UIView()
    v.addSubview(view)
    view.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: padding, bottom: 0, right: -padding))
    return v
}

fileprivate class NameCell: SendCell, UITextViewDelegate {
    init(placeholder: String) {
        super.init()
        textView.delegate = self
        textView.textColor = C.Colors.text
        textView.font = .customBody(size: 16.0)
        textView.returnKeyType = .done
        textView.keyboardAppearance = .dark
        
        self.placeholder.textColor = C.Colors.blueGrey
        self.placeholder.text = placeholder
        backgroundColor = .clear
        setupViews()
    }
    
    var didBeginEditing: (() -> Void)?
    var didReturn: ((UITextView) -> Void)?
    var didChange: ((String) -> Void)?
    var content: String? {
        didSet {
            textView.text = content
            textViewDidChange(textView)
        }
    }
    
    let textView = UITextView()
    fileprivate let placeholder = UILabel(font: .customBody(size: 16.0), color: C.Colors.lightText)
    private func setupViews() {
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        addSubview(textView)
        textView.constrain([
            textView.constraint(.leading, toView: self, constant: 11.0),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30.0),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        
        textView.addSubview(placeholder)
        placeholder.constrain([
            placeholder.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 5.0) ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = textView.text != ""
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.rangeOfCharacter(from: CharacterSet.newlines) == nil else {
            textView.resignFirstResponder()
            return false
        }
        
        let count = (textView.text ?? "").utf8.count + text.utf8.count
        return count <= C.maxContactNameLength
    }
}

fileprivate class AddressBookAddContactViewController: UIViewController {
    // MARK: Private
    private let topBox = UIView()
    private let icon = UIImageView(image: UIImage(named: "AddressBook_AddContact_white"))
    private let headerLabel = UILabel()
    private let stackView = UIStackView()
    
    private let nameBox = NameCell(placeholder: S.AddressBook.name)
    private let addressCell = AddressCell()
    
    private var switchContainer: UIView!
    private let favoriteSwitch = UISwitch(frame: .zero)
    private let favoriteLabel = UILabel()
    
    private let addButton = ShadowButton(title: S.AddressBook.addContactButtonTitle, type: .primary)
    private let deleteButton = DGBHapticButton(frame: .zero)
    private let closeButton = UIButton.close
    
    private var fav: UIImageView!
    private var favWidth: NSLayoutConstraint!
    
    // MARK: Public
    var presentScan: PresentScan?
    
    var id: String = ""
    var callback: ((AddressBookContact) -> Bool)? = nil
    var deleteCallback: ((String /* uuid*/) -> Void)? = nil
    
    enum Style {
        case add
        case edit
    }
    
    func reset() {
        nameBox.content = ""
        addressCell.setContent("")
        favoriteSwitch.isOn = false
        fav.transform = CGAffineTransform(scaleX: 0, y: 0)
    }
    
    func initialize(_ data: AddressBookContact) {
        id = data.id
        nameBox.content = data.name
        addressCell.setContent(data.address)
        favoriteSwitch.isOn = data.isFavorite
    }
    
    init(style: Style = .add) {
        super.init(nibName: nil, bundle: nil)
        
        let padding: CGFloat = 16
        
        view.addSubview(topBox)
        topBox.addSubview(icon)
        topBox.addSubview(headerLabel)
        topBox.addSubview(closeButton)
        
        if style == .edit {
            topBox.addSubview(deleteButton)
        }
        
        view.addSubview(stackView)
        
        topBox.constrain([
            topBox.topAnchor.constraint(equalTo: view.topAnchor),
            topBox.leftAnchor.constraint(equalTo: view.leftAnchor),
            topBox.rightAnchor.constraint(equalTo: view.rightAnchor),
            topBox.heightAnchor.constraint(equalToConstant: 127)
        ])
        
        icon.constrain([
            icon.centerYAnchor.constraint(equalTo: topBox.centerYAnchor),
            icon.centerXAnchor.constraint(equalTo: topBox.centerXAnchor),
            icon.heightAnchor.constraint(equalToConstant: 25),
            icon.widthAnchor.constraint(equalToConstant: 25),
        ])
        
        closeButton.constrain([
            closeButton.centerYAnchor.constraint(equalTo: icon.bottomAnchor, constant: 0),
            closeButton.leftAnchor.constraint(equalTo: topBox.leftAnchor, constant: 0),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.widthAnchor.constraint(equalToConstant: 44)
        ])
        
        if style == .edit {
            deleteButton.constrain([
                deleteButton.centerYAnchor.constraint(equalTo: icon.bottomAnchor, constant: 0),
                deleteButton.rightAnchor.constraint(equalTo: topBox.rightAnchor, constant: -15),
                deleteButton.heightAnchor.constraint(equalToConstant: 24),
                deleteButton.widthAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        headerLabel.constrain([
            headerLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 15),
            headerLabel.centerXAnchor.constraint(equalTo: topBox.centerXAnchor),
        ])
        
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: topBox.bottomAnchor, constant: 15),
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        icon.contentMode = .scaleAspectFit
        icon.tintColor = UIColor.white
        
        headerLabel.textColor = UIColor.white
        headerLabel.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        
        topBox.backgroundColor = UIColor(red: 36 / 255, green: 37 / 255, blue: 55 / 255, alpha: 1.0) // 36 37 55
        view.backgroundColor = C.Colors.background
        
        stackView.addArrangedSubview(hBox(nameBox, horizontal: 0))
        stackView.addArrangedSubview(hBox(addressCell, horizontal: 0))
        
        nameBox.heightAnchor.constraint(equalToConstant: NameCell.defaultHeight).isActive = true
        
        switchContainer = UIView()
        switchContainer.addSubview(favoriteLabel)
        switchContainer.addSubview(favoriteSwitch)
        
        fav = UIImageView(image: UIImage(named: "AddressBook_favorite")?.withRenderingMode(.alwaysTemplate))
        switchContainer.addSubview(fav)
        
        fav.constrain([
            fav.leftAnchor.constraint(equalTo: switchContainer.leftAnchor),
            fav.centerYAnchor.constraint(equalTo: switchContainer.centerYAnchor, constant: 0),
        ])
        
        favWidth = fav.widthAnchor.constraint(equalToConstant: 0)
        favWidth.isActive = true
        fav.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
        fav.tintColor = C.Colors.favoriteYellow
        
        favoriteLabel.constrain([
            favoriteLabel.centerYAnchor.constraint(equalTo: switchContainer.centerYAnchor, constant: 0),
            favoriteLabel.leftAnchor.constraint(equalTo: fav.rightAnchor, constant: 10),
        ])
        
        favoriteSwitch.constrain([
            favoriteSwitch.topAnchor.constraint(equalTo: switchContainer.topAnchor, constant: 10),
            favoriteSwitch.rightAnchor.constraint(equalTo: switchContainer.rightAnchor, constant: 0),
            favoriteSwitch.bottomAnchor.constraint(equalTo: switchContainer.bottomAnchor, constant: -10)
        ])
        
        favoriteSwitch.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        favoriteSwitch.onTintColor = C.Colors.blue
        favoriteSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        
        stackView.addArrangedSubview(hBox(switchContainer, horizontal: padding))
        stackView.addArrangedSubview(hBox(addButton, horizontal: padding))
        stackView.addArrangedSubview(UIView())
        
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 10
        stackView.axis = .vertical
        
        favoriteLabel.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        favoriteLabel.textColor = UIColor.white
        favoriteLabel.text = S.AddressBook.favorite

        closeButton.imageView?.tintColor = UIColor.white
        
        if style == .add {
            headerLabel.text = S.AddressBook.addContact
            icon.image = UIImage(named: "AddressBook_AddContact_white")
            addButton.title = S.AddressBook.addContactButtonTitle
            deleteButton.isHidden = true
        } else {
            headerLabel.text = S.AddressBook.editContact
            icon.image = UIImage(named: "AddressBook_AddContact_white") // ToDo: ask Damir to provide an edit icon
            addButton.title = S.AddressBook.editContactButtonTitle
            deleteButton.isHidden = false
            deleteButton.setImage(UIImage(named: "AddressBook_DeleteContact_white")?.withRenderingMode(.alwaysTemplate), for: .normal)
            deleteButton.tintColor = UIColor.white
            deleteButton.contentMode = .scaleAspectFit
        }
        
        // close callback
        closeButton.tap = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        
        addButton.tap = { [unowned self] in
            self.resetInputFieldStates()
            
            // reject input if contact name is empty
            if self.nameBox.textView.text == "" {
                self.nameBox.border.backgroundColor = C.Colors.weirdRed
                self.nameBox.placeholder.textColor = C.Colors.weirdRed
                return
            }
            
            // also reject input if address cell is empty
            if self.addressCell.address == "" {
                self.addressCell.textField.border.backgroundColor = C.Colors.weirdRed
                self.addressCell.textField.placeholder.textColor = C.Colors.weirdRed
                return
            }
            
            self.resetInputFieldStates()
            
            if self.callback?(AddressBookContact(id: self.id, name: self.nameBox.textView.text, address: self.addressCell.address, isFavorite: self.favoriteSwitch.isOn)) == true {
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        addressCell.didEdit = { [unowned self] in
            self.stackView.layoutIfNeeded()
        }
        
        deleteButton.tap = { [unowned self] in
            let alertController = AlertController(title: S.AddressBook.deleteContactHeader, message: S.AddressBook.deleteContact, preferredStyle: .alert)
            alertController.addAction(AlertAction(title: S.Button.no, style: .default, handler: nil))
            alertController.addAction(AlertAction(title: S.Button.yes, style: .destructive, handler: { _ in
                self.deleteCallback?(self.id)
                self.dismiss(animated: true, completion: nil)
            }))
            self.present(alertController, animated: true, completion: nil)
        }
        
        addressCell.paste.tap = { [unowned self] in self.pasteTapped() }
        addressCell.qrImage.tap = { [unowned self] in self.qrImageTapped() }
        addressCell.scan.tap = { [unowned self] in self.scanTapped() }
    }
    
    private func resetInputFieldStates() {
        self.nameBox.border.backgroundColor = C.Colors.blueGrey
        self.addressCell.textField.border.backgroundColor = C.Colors.blueGrey
        self.nameBox.placeholder.textColor = C.Colors.blueGrey
        self.addressCell.textField.placeholder.textColor = C.Colors.blueGrey
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func switchChanged() {
        if favoriteSwitch.isOn {
            UIView.spring(0.4, animations: {
                // visible
                self.favWidth.isActive = false
                self.fav.transform = CGAffineTransform.identity
                self.switchContainer.layoutIfNeeded()
            }) { _ in }
        } else {
            UIView.spring(0.4, animations: {
                // hidden
                self.favWidth.isActive = true
                self.fav.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
                self.switchContainer.layoutIfNeeded()
            }) { _ in }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        self.favWidth.isActive = true
        icon.transform = CGAffineTransform(scaleX: 0, y: 0)
        self.view.layoutIfNeeded()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIView.spring(0.4, animations: {
                self.icon.transform = CGAffineTransform.identity
                self.topBox.layoutIfNeeded()
            }) { _ in
                // completed
            }
        }
    }
    
    @objc private func pasteTapped() {
        guard let pasteboard = UIPasteboard.general.string, pasteboard.utf8.count > 0 else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }
        guard let request = PaymentRequest(string: pasteboard) else {
            return showAlert(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressOnPasteboard, buttonLabel: S.Button.ok)
        }
        handleRequest(request)
    }
    
    @objc private func scanTapped() {
        nameBox.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            self?.handleRequest(request)
        }
    }
    
    @objc private func qrImageTapped() {
        addressCell.textField.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        
        let imagePicker = UIImagePickerController()
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum;
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    private func handleRequest(_ request: PaymentRequest) {
        switch request.type {
        case .local:
            addressCell.setContent(request.toAddress)
            addressCell.isEditable = true
        case .remote:
            showAlert(title: "Unsupported", message: "Payment request is unsupported", buttonLabel: "OK")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        switchChanged()
    }
}


extension AddressBookAddContactViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: { () -> Void in })
        
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
                            if PaymentRequest(string: decode) != nil {
                                self.addressCell.setContent(decode)
                                return;
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

fileprivate class AddressBookSearchBar: UITextField {
    init() {
        super.init(frame: .zero)
        
        backgroundColor = UIColor(red: 36 / 255, green: 37 / 255, blue: 55 / 255, alpha: 1.0) // 36 37 55
        
        textColor = UIColor.white
        tintColor = UIColor.white
        
        font = UIFont.systemFont(ofSize: 14)
        
        // add search bar text
        let placeholderColor = UIColor(red: 71 / 255, green: 73 / 255, blue: 108 / 255, alpha: 1.0) // 71 73 108
        let placeholder = NSMutableAttributedString(string: S.AddressBook.searchPlaceholder)
        placeholder.addAttribute(NSAttributedString.Key.foregroundColor, value: placeholderColor, range: NSRange(location:0,length: placeholder.length))
        placeholder.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location:0,length: placeholder.length))
        attributedPlaceholder = placeholder
        
        // search icon
        let searchIcon = UIImageView(image: UIImage(named: "SearchIcon")?.withRenderingMode(.alwaysTemplate))
        
        let view = UIView()
        view.addSubview(searchIcon)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.widthAnchor.constraint(equalToConstant: 45).isActive = true
        
        searchIcon.constrain([
            searchIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            searchIcon.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        searchIcon.contentMode = .scaleAspectFit
        searchIcon.tintColor = placeholderColor
        leftView = view
        leftViewMode = .always
    
        layer.cornerRadius = 5
        layer.masksToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class AddressBookContactCell: UITableViewCell {
    private let title = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        contentView.addSubview(title)
        title.constrain([
            title.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 28),
            title.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0),
            title.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0),
        ])
    }
    
    func setData(_ contact: AddressBookContact) {
        title.text = contact.name
        title.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        title.textColor = UIColor.white
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//class AddressBookContact: NSCoder, NSCoding {
//    func encode(with aCoder: NSCoder) {
//        aCoder.encode(self.id)
//        aCoder.encode(self.name)
//        aCoder.encode(self.address)
//        aCoder.encode(self.isFavorite)
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        id = aDecoder.decodeObject() as! String
//        name = aDecoder.decodeObject() as! String
//        address = aDecoder.decodeObject() as! String
//        isFavorite = aDecoder.decodeObject() as! Bool
//    }
//
//    var id: String
//    var name: String
//    var address: String
//    var isFavorite: Bool
//
//    func matches(_ str: String) -> Bool {
//        guard str != "" else { return true }
//        let uname = name.uppercased()
//        let uaddress = address // case sensitive
//        let search = str.uppercased()
//
//        return uname.contains(search) || uaddress.contains(search)
//    }
//
//    init(id: String, name: String, address: String, isFavorite: Bool = false) {
//        self.id = id
//        self.name = name
//        self.address = address
//        self.isFavorite = isFavorite
//        super.init()
//    }
//
//    // loads the contacts from memory
//    static func loadContacts() -> [AddressBookContact] {
//        do {
//            if let version = try keychainItem(key: "addressBookVersion") as NSInteger? {
//                if version < ADDRESSBOOK_VERSION {
//                    // migrate old data to new data (for future versions)
//                    // ...
//                }
//            } else {
//                // addressbook version not set, so set it cleanly
//                try setKeychainItem(key: "addressBook", item: [] as NSArray)
//                try setKeychainItem(key: "addressBookVersion", item: ADDRESSBOOK_VERSION)
//            }
//        } catch {
//            // Skip error handling.. Shouldn't be too bad
//        }
//
//        do {
//            if
//                let s = try keychainItem(key: "addressBook") as NSArray?,
//                let addressBook: [AddressBookContact] = s as? [AddressBookContact] {
//                return addressBook
//            }
//        } catch {
//            return []
//        }
//
//        return []
//    }
//}

class AddressBookContact: Codable {
    var id: String
    var name: String
    var address: String
    var isFavorite: Bool
    
    func matches(_ str: String) -> Bool {
        guard str != "" else { return true }
        let uname = name.uppercased()
        let uaddress = address // case sensitive
        let search = str.uppercased()
        
        return uname.contains(search) || uaddress.contains(search)
    }
    
    init(id: String, name: String, address: String, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.isFavorite = isFavorite
    }
    
    // Loads the contacts from memory
    static func loadContacts() -> [AddressBookContact] {
        do {
            if let version = try keychainItem(key: "addressBookVersion") as NSInteger? {
                if version == 1 {
                    // Delete alpha version data (objects are now stored as JSON)
                    try setKeychainItem(key: "addressBook", item: "[]" as String)
                    try setKeychainItem(key: "addressBookVersion", item: ADDRESSBOOK_VERSION)
                    
                } else if version < ADDRESSBOOK_VERSION {
                    // Future migrations...
                }
            } else {
                // Addressbook version not set, so set it cleanly
                try setKeychainItem(key: "addressBook", item: "[]" as String)
                try setKeychainItem(key: "addressBookVersion", item: ADDRESSBOOK_VERSION)
            }
        } catch {
            // Skip error handling.. Shouldn't be too bad
        }
        
        do {
            let jsonDecoder = JSONDecoder()
            if let serializedAddressbook = try keychainItem(key: "addressBook") as String? {
                let deserializedAddressbook = try jsonDecoder.decode([AddressBookContact].self, from: serializedAddressbook.data(using: .utf8)!)
                return deserializedAddressbook
            }
        } catch {
            return []
        }
        
        return []
    }
}

fileprivate class AddressBookHeaderLine: UIView {
    let stackView = UIStackView()
    let image = UIImageView()
    let letter = UILabel()
    let line = UIView()
    
    private func initialize(text: String, img: UIImage? = nil) {
        addSubview(stackView)
        
        if img != nil {
            image.image = img
            stackView.addArrangedSubview(image)
        }
        
        stackView.addArrangedSubview(letter)
        stackView.addArrangedSubview(line)
        
        letter.text = text
        letter.font = UIFont.systemFont(ofSize: 14)
        letter.textColor = C.Colors.blueGrey
        
        image.translatesAutoresizingMaskIntoConstraints = false
        image.widthAnchor.constraint(equalToConstant: 19).isActive = true
        image.heightAnchor.constraint(equalToConstant: 19).isActive = true
        
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.backgroundColor = C.Colors.blueGrey
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 10
        
        stackView.constrain([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leftAnchor.constraint(equalTo: leftAnchor),
            stackView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
    }
    
    init(_ character: Character, img: UIImage? = nil) {
        super.init(frame: .zero)
        initialize(text: "\(character)", img: img)
    }
    
    init() {
        super.init(frame: .zero)
        initialize(text: S.AddressBook.favorites.uppercased(), img: UIImage(named: "AddressBook_favorite")) 
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AddressBookOverviewViewController: UIViewController, Trackable, Subscriber {
    // MARK: - Public
    var presentScanForAdd: PresentScan?
    var presentScanForEdit: PresentScan?
    var addContactVC: UIViewController!
    var editContactVC: UIViewController!
    var contactSelectedCallback: ((AddressBookContact) -> Void)? = nil
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        addSubviews()
        addConstraints()
        setStyle()
        addActions()
        setupCopiedMessage()
        createVC()
    }
    
    //MARK: - Private
    private let searchBox = AddressBookSearchBar()
    private let addContactButton = DGBHapticButton()
    private let tableView = UITableView(frame: .zero, style: UITableView.Style.grouped)
    private var contacts = [AddressBookContact]() {
        didSet {
            reindex()
            tableView.reloadData()
        }
    }
    
    private var indexedContacts = [Int: [AddressBookContact]]()
    private var filterString: String = ""
    
    private func reindex(filterString: String = "") {
        // prepare data structure
        indexedContacts = [Int: [AddressBookContact]]()
        
        // index 0: favorites
        indexedContacts[0] = []
        
        // sort alphabetically
        let sorted = contacts.sorted { $0.name < $1.name }
        var letters = [Character]()
        
        // process each entry and start from index 1
        var counter: Int = 0
        sorted.forEach { (contact) in
            let c = contact.name.first!
            
            // add letter to section index, if letter does not exist yet
            if !letters.contains(c) {
                counter = counter + 1
                letters.append(c)
                indexedContacts[counter] = []
            }
            
            // append the contact to the section index
            if filterString == "" || contact.matches(filterString) {
                indexedContacts[counter]!.append(contact)
            }
        }
        
        // add each favorite
        sorted.forEach { (contact) in
            if contact.isFavorite {
                if filterString == "" || contact.matches(filterString) {
                    indexedContacts[0]?.append(contact)
                }
            }
        }
        
        // reorganize section indexes
        let c = indexedContacts.filter({ contact in contact.value.count > 0 })
        indexedContacts = [Int: [AddressBookContact]]()
        indexedContacts[0] = []
        
        counter = 1
        
        c.sorted{ (a, b) -> Bool in
            return a.key < b.key
        }.forEach {
            guard $0.value.count > 0 else { return }
            
            if $0.key == 0 {
                indexedContacts[0] = $0.value
            } else {
                indexedContacts[counter] = $0.value
                counter = counter + 1
            }
        }
    }
    
    // saves the contacts into keychain
    private func saveContacts() {
        do {
            let jsonEncoder = JSONEncoder()
            let serializedAddressbook = try jsonEncoder.encode(contacts)
            try setKeychainItem(key: "addressBook", item: serializedAddressbook)
        } catch let e {
            print(e)
        }
    }
    
    private func createVC() {
        // We are creating the view controllers in initialization because we need to have access on it
        // from ModalPresenter class (scan presenter).
        addContactVC = AddressBookAddContactViewController(style: .add)
        editContactVC = AddressBookAddContactViewController(style: .edit)
    }
    
    private func addSubviews() {
        view.addSubview(addContactButton)
        view.addSubview(searchBox)
        view.addSubview(tableView)
    }
    
    private func addConstraints() {
        addContactButton.constrain([
            addContactButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            addContactButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),
            addContactButton.heightAnchor.constraint(equalToConstant: 30),
            addContactButton.widthAnchor.constraint(equalToConstant: 30)
        ])
        
        searchBox.constrain([
            searchBox.centerYAnchor.constraint(equalTo: addContactButton.centerYAnchor, constant: 0),
            searchBox.rightAnchor.constraint(equalTo: addContactButton.leftAnchor, constant: -15),
            searchBox.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            searchBox.heightAnchor.constraint(equalToConstant: 37)
        ])
        
        tableView.constrain([
            tableView.topAnchor.constraint(equalTo: searchBox.bottomAnchor, constant: 0),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 10),
        ])
        
        tableView.contentInset = UIEdgeInsets(top: 30, left: 0, bottom: 100, right: 0)
//        tableView.contentInsetAdjustmentBehavior = .never // iOS 11
        automaticallyAdjustsScrollViewInsets = false
        
        let h = view.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height)
        h.priority = UILayoutPriority(999)
        h.isActive = true
    }
    
    private func setStyle() {
        view.backgroundColor = .clear
        
        addContactButton.setImage(UIImage(named: "AddressBook_AddContact")?.withRenderingMode(.alwaysTemplate), for: .normal) // YOSHI
//        addContactButton.tintColor = UIColor(red: 0, green: 85 / 255, blue: 173 / 255, alpha: 1) // 0 85 173
        addContactButton.tintColor = UIColor.white
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AddressBookContactCell.self, forCellReuseIdentifier: "cell")
        
        tableView.backgroundColor = UIColor.clear
        tableView.separatorColor = UIColor.clear
        tableView.keyboardDismissMode = .onDrag
        
        searchBox.keyboardAppearance = .dark
        searchBox.keyboardType = .alphabet
        searchBox.returnKeyType = .search
        searchBox.delegate = self
    }
    
    private func setQrCode(){
        
    }
    
    private func setReceiveAddress() {
        
    }
    
    private func addActions() {
        searchBox.addTarget(self, action: #selector(searchTermChanged), for: UIControl.Event.editingChanged)
        addContactButton.addTarget(self, action: #selector(addContactTapped), for: .touchUpInside)
    }
    
    @objc private func addContactTapped() {
        let vc = addContactVC as! AddressBookAddContactViewController
        
        vc.transitioningDelegate = nil
        vc.presentScan = presentScanForAdd
        
        vc.id = UUID().uuidString
        
        // if user saves contact
        vc.callback = { [weak self] contact in
            // add the new contact
            self?.contacts.append(contact)
            // persist them to memory
            self?.saveContacts()
            self?.reindex()
            return true
        }
        
        // reset contents (name, address, favorite switch)
        vc.reset()
        
        if let root = UIApplication.shared.keyWindow?.rootViewController {
            root.show(vc, sender: nil)
        }
    }
    
    @objc private func searchTermChanged() {
        reindex(filterString: searchBox.text ?? "")
        tableView.reloadData()
    }
    
    @objc private func shareTapped() {
        
    }
    
    private func setupCopiedMessage() {

    }
    
    @objc private func addressTapped() {

    }
    
    private func toggle(alertView: InViewAlert, shouldAdjustPadding: Bool, shouldShrinkAfter: Bool = false) {
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        contacts = AddressBookContact.loadContacts()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
//        saveContacts()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AddressBookOverviewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension AddressBookOverviewViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return indexedContacts.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return indexedContacts[section]!.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let c = indexedContacts[0]!
            return c.count == 0 ? UIView() : AddressBookHeaderLine()
        }
        
        let c = indexedContacts[section]!
        guard c.count >= 0 else { return UIView() }
        
        return AddressBookHeaderLine(c[0].name.uppercased().first ?? " ".first!)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 27
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 33
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var cellData = indexedContacts[indexPath.section]!
        let contact = cellData[indexPath.row]
        
        // If contactSelectedCallback is set, this view controller was
        // definitely called from send dialog. In that case, we just execute the callback
        // with the selected data.
        if let callback = contactSelectedCallback {
            callback(contact)
            return
        }
        
        // create AddressBookAddContactViewController
        let vc = editContactVC as! AddressBookAddContactViewController
        
        vc.transitioningDelegate = nil
        vc.presentScan = presentScanForEdit
        
        // if user saves contact
        vc.callback = { [weak self] newContactData in
            cellData[indexPath.row] = newContactData
            if let me = self {
                /* find contact by id, update contact */
                if let toUpdate = me.contacts.firstIndex(where: { (contact) -> Bool in
                    return contact.id == newContactData.id
                }) {
                    me.contacts[toUpdate] = newContactData
                    me.saveContacts()
                    me.reindex()
                    return true
                }
            }
            
            return false
        }
        
        vc.deleteCallback = { [weak self] id in
            // delete the contact
            if let me = self {
                me.contacts = me.contacts.filter({ (contact) -> Bool in
                    return contact.id != id
                })
                me.saveContacts()
                me.reindex()
            }
        }
        
        // reset contents (name, address, favorite switch)
        vc.reset()
        vc.initialize(contact)
        
        if let root = UIApplication.shared.keyWindow?.rootViewController {
            root.show(vc, sender: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! AddressBookContactCell
        let cellData = indexedContacts[indexPath.section]!
        cell.setData(cellData[indexPath.row])
        return cell
    }
}

extension AddressBookOverviewViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.addressBook
    }

    var modalTitle: String {
        return S.AddressBook.title
    }
}
