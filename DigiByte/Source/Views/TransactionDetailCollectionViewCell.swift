//
//  TransactionDetailCollectionViewCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionDetailCollectionViewCell : UICollectionViewCell {

    //MARK: - Public
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func set(transaction: Transaction, isBtcSwapped: Bool, rate: Rate, rates: [Rate], maxDigits: Int) {
        timestamp1.text = transaction.dayTimestamp
        timestamp2.text = transaction.timeTimestamp
        timeSinceTransactionLabel.text = transaction.timeSince.0
        
        amount.text = transaction.amountDescription(isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: maxDigits)
        amountDGB.text = transaction.amountDescription(isBtcSwapped: false, rate: rate, maxDigits: maxDigits)
        
        directionLabel.text = String(format: transaction.direction.amountFormat, "")
        //amount.text = String(format: transaction.direction.amountFormat, "\(transaction.amountDescription(isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: maxDigits))")
        //address.text = transaction.detailsAddressText
        address.setTitle(transaction.toAddress ?? "unknown", for: .normal)
        status.text = transaction.status
        status.status = {
            switch transaction.statusCode {
            case .invalid:
                return .invalid
            case .unknown:
                return .unknown
            case .pending:
                return .progress
            case .success:
                return .complete
            }
        }()
        let confirmations = S.TransactionDetailView.confirmations.uppercased()
        confirmationsLabel.text = "\(confirmations): \(transaction.confirms)"
        comment.text = transaction.comment
        amountDetails.text = transaction.amountDetails(isBtcSwapped: isBtcSwapped, rate: rate, rates: rates, maxDigits: maxDigits)
        addressHeader.text = transaction.direction.addressHeader.capitalized
        fullAddress.setTitle(transaction.toAddress ?? "", for: .normal)
        txHash.setTitle(transaction.hash, for: .normal)
        availability.isHidden = !transaction.shouldDisplayAvailableToSpend
        blockHeight.text = transaction.blockHeight
        
        self.transaction = transaction
        self.rate = rate
                
        let directionSymbolImage: UIImage = {
            switch transaction.direction {
            case .sent:
                return UIImage(named: "sentTransaction")!
            case .received:
                return UIImage(named: "receivedTransaction")!
            case .moved:
                return UIImage(named: "transfer")!
            }
        }()
        
        directionSymbolImageView.image = directionSymbolImage
        directionSymbolImageView.tintColor = .white
    }

    var closeCallback: (() -> Void)? {
        didSet {
            header.closeCallback = closeCallback
        }
    }

    var didBeginEditing: (() -> Void)?
    var didEndEditing: (() -> Void)?
    var modalTransitioningDelegate: ModalTransitionDelegate?

    var kvStore: BRReplicatedKVStore?
    var transaction: Transaction?
    var rate: Rate?
    var store: BRStore? {
        didSet {
            if oldValue == nil {
                guard let store = store else { return }
                header.faqInfo = (store, ArticleIds.transactionDetails)
            }
        }
    }

    //MARK: - Private
    private let cardOffset: CGFloat = 45
    
    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .dark)
    private let timestamp1 = UILabel(font: .customBody(size: 18.0), color: C.Colors.text)
    private let timestamp2 = UILabel(font: .customBody(size: 18.0), color: C.Colors.text)
    private let confirmationsLabel = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let amount = UILabel(font: .customMedium(size: 26.0), color: C.Colors.text)
    private let amountDGB = UILabel(font: .customMedium(size: 18.0), color: C.Colors.text)
    private let directionLabel = UILabel(font: .customBody(size: 16.0), color: C.Colors.greyBlue)
    private let separators = (0...4).map { _ in UIView(color: C.Colors.text) }
    private let statusHeader = UILabel(font: .customMedium(size: 14.0), color: C.Colors.lightText)
    private let status = TransactionStatusView(font: .customBody(size: 14.0), color: C.Colors.text, status: .unknown)
    private let commentsHeader = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let comment = UITextView()
    private let amountHeader = UILabel(font: .customMedium(size: 14.0), color: C.Colors.lightText)
    private let amountDetailsHeader = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let timeSinceTransactionLabel = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let amountDetails = UILabel.wrapping(font: .customBody(size: 13.0), color: C.Colors.text)
    private let addressHeader = UILabel(font: .customBody(size: 14.0), color: C.Colors.lightText)
    private let fullAddress = UIButton(type: .system)
    private let headerHeight: CGFloat = 48.0
    private let transactionDetailCardView = TransactionCardView()
    private let scrollViewContent = UIView()
    let scrollView = UIScrollView()
    
    private let dateLabel = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let processedLabel = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let statusLabel = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    
    private let address: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .customBody(size: 14.0)
        
        btn.titleLabel?.lineBreakMode = .byCharWrapping
        btn.titleLabel?.numberOfLines = 0
        btn.titleLabel?.textAlignment = .center
        
        btn.setTitleColor(C.Colors.text, for: .normal)
        btn.contentHorizontalAlignment = .center
        
        return btn
    }()
    private let card: UIView = {
        let c = UIView()
        // #2E3046
        c.backgroundColor = UIColor(red: 0x2E / 255, green: 0x30 / 255, blue: 0x46 / 255, alpha: 1.0)
        c.layer.masksToBounds = true
        c.layer.cornerRadius = 15
        
        return c
    }()
    private let digiLogo: UIImageView = {
        let img = UIImageView(image: UIImage(named: "DigiByteSymbol"))
        img.contentMode = .scaleAspectFit
        return img
    }()
    
    // ToDo: Remove
    private let moreButton = UIButton(type: .system)
    private let moreContentView = UIView()
    
    private let txHash = UIButton(type: .system)
    private let txHashHeader = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let availability = UILabel(font: .customBold(size: 13.0), color: .txListGreen)
    private let blockHeightHeader = UILabel(font: .customBody(size: 14.0), color: C.Colors.greyBlue)
    private let blockHeight = UILabel(font: .customBody(size: 13.0), color: C.Colors.text)
    private var scrollViewHeight: NSLayoutConstraint?
    
    private let directionSymbolImageView = UIImageView(image: UIImage(named: "hamburger_001Info"))
    private let blurView = UIView()
    
    private var contentOffsetTop: NSLayoutConstraint? = nil

    private func setup() {
        addSubviews()
        addConstraints()
        setData()
        
        setGestures()
    }
    
    private var cardExpanded: Bool = false
    private var cardAnimating: Bool = false
    private var cardOriginalOffset: CGFloat? = nil
    private var cardInitialized: Bool = false
    private var cardStart: CGFloat? = nil
    
    private func setGestures() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.addTarget(self, action: #selector(cardTap))
        card.addGestureRecognizer(tapGesture)
        
        let swipeGesture = UIPanGestureRecognizer()
        swipeGesture.addTarget(self, action: #selector(cardPan))
        card.addGestureRecognizer(swipeGesture)
    }
    
    private func initCard() {
        guard !cardInitialized else { return }
        cardOriginalOffset = card.frame.origin.y
        
        blurView.backgroundColor = .black
        blurView.alpha = 0.0
        
        scrollViewContent.insertSubview(blurView, belowSubview: card)
        blurView.constrain(toSuperviewEdges: nil)
        
        var top: CGFloat = 0
        // top = UIScreen.main.bounds.height - self.scrollView.contentSize.height + 40
        top = 100 + (E.isIPhoneXOrGreater ? 60 : 0)
        if top > 0 {
            contentOffsetTop?.constant = top
            transactionDetailCardView.layoutIfNeeded()
            scrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        cardInitialized = true
        
        address.tap = { () in
            self.address.tempDisable()
            self.store?.trigger(name: .lightWeightAlert(S.Receive.copied))
            UIPasteboard.general.string = self.address.titleLabel?.text
        }
    }
    
    @objc private func cardPan(recognizer: UIPanGestureRecognizer) {
        guard !cardAnimating else { return }
        guard let cOffset = cardOriginalOffset else { return }
        
        let translation = recognizer.translation(in: scrollViewContent).y
        let scale: CGFloat = (self.card.frame.origin.y + translation) / cOffset
        
        let maxValue = cOffset - (self.card.frame.height - 80)
        let minValue = cOffset

        if recognizer.state == .began {
            cardStart = self.card.frame.origin.y
            
        } else if recognizer.state == .changed {
            guard let cardStart = cardStart else { return }
            
            if cardStart + translation < maxValue {
                if translation > 0 {
                    self.card.frame.origin.y = maxValue + sqrt(translation)
                } else {
                    self.card.frame.origin.y = maxValue - sqrt(-translation)
                }
            } else if cardStart + translation > minValue {
                if translation > 0 {
                    self.card.frame.origin.y = minValue + sqrt(translation)
                } else {
                    self.card.frame.origin.y = minValue - sqrt(-translation)
                }
            } else {
                self.card.frame.origin.y = cardStart + translation
            }
            
            let satScale = scale > 1 ? 1 : (scale < 0 ? 0 : scale);
            blurView.alpha = (1 - satScale) * 0.8
            
        } else {
            cardStart = nil
            
            if scale > 0.5 {
                cardExpanded = true
                hideCard()
            } else {
                cardExpanded = false
                showCard()
            }
        }
    }
    
    @objc private func cardTap() {
        if cardExpanded {
            // hideCard()
        } else {
            showCard()
        }
    }
    
    private func showCard() {
        guard !cardAnimating else { return }
        guard !cardExpanded else { return }
        guard let cOffset = cardOriginalOffset else { return }
        
        cardAnimating = true
        
        UIView.spring(0.3, animations: {
            self.card.frame.origin.y = cOffset - (self.card.frame.height - 80)
            self.blurView.alpha = 0.6
        }) { (c) in
            self.cardAnimating = false
            self.cardExpanded = true
        }
    }

    private func hideCard() {
        guard !cardAnimating else { return }
        guard cardExpanded else { return }
        guard let cOffset = cardOriginalOffset else { return }
        
        cardAnimating = true
        
        UIView.spring(0.3, animations: {
            self.card.frame.origin.y = cOffset
            self.blurView.alpha = 0.0
        }) { (c) in
            self.cardAnimating = false
            self.cardExpanded = false
        }
    }
    
    private func addSubviews() {
        scrollView.addSubview(transactionDetailCardView)
            
        transactionDetailCardView.addSubview(scrollViewContent)
        scrollViewContent.layer.masksToBounds = true
        
        directionSymbolImageView.contentMode = .scaleAspectFit
        scrollView.addSubview(directionSymbolImageView)
        scrollViewContent.addSubview(amount)
        scrollViewContent.addSubview(directionLabel)
        scrollViewContent.addSubview(address)
        
        scrollViewContent.addSubview(dateLabel)
        scrollViewContent.addSubview(processedLabel)
        scrollViewContent.addSubview(statusLabel)
        
        scrollViewContent.addSubview(timestamp1)
        scrollViewContent.addSubview(timestamp2)
        scrollViewContent.addSubview(status)
        
        scrollViewContent.addSubview(confirmationsLabel)
        
        // CARD
        scrollViewContent.addSubview(card)
        card.addSubview(digiLogo)
        card.addSubview(amountDGB)
        card.addSubview(timeSinceTransactionLabel)
        
        card.addSubview(amountDetailsHeader)
        card.addSubview(amountDetails)
        card.addSubview(blockHeightHeader)
        card.addSubview(blockHeight)
        card.addSubview(txHashHeader)
        card.addSubview(txHash)
        card.addSubview(commentsHeader)
        card.addSubview(comment)
        
        contentView.addSubview(scrollView)
    }

    private func addConstraints() {
        // ToDo: Do device specific calculations of padding?
        let padding: CGFloat = 22
        
        scrollViewHeight = scrollView.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: 20)
        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollViewHeight
        ])
        
        scrollView.contentInset.bottom = 30
        
        contentOffsetTop = transactionDetailCardView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 120)
        transactionDetailCardView.constrain([
            contentOffsetTop,
            transactionDetailCardView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            transactionDetailCardView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            transactionDetailCardView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            transactionDetailCardView.widthAnchor.constraint(equalTo: scrollView.widthAnchor) ])
 
        scrollViewContent.constrain(toSuperviewEdges: nil)
        
        scrollView.alwaysBounceVertical = true
        
        directionSymbolImageView.constrain([
            directionSymbolImageView.topAnchor.constraint(equalTo: transactionDetailCardView.topAnchor, constant: -30),
            directionSymbolImageView.centerXAnchor.constraint(equalTo: transactionDetailCardView.centerXAnchor),
            directionSymbolImageView.widthAnchor.constraint(equalToConstant: UIScreen.main.scale * 30),
            directionSymbolImageView.heightAnchor.constraint(equalToConstant: UIScreen.main.scale * 30),
        ])
        
        amount.constrain([
            amount.centerXAnchor.constraint(equalTo: directionSymbolImageView.centerXAnchor, constant: 0),
            amount.topAnchor.constraint(equalTo: directionSymbolImageView.bottomAnchor, constant: 24),
        ])
        
        directionLabel.constrain([
            directionLabel.centerXAnchor.constraint(equalTo: directionSymbolImageView.centerXAnchor, constant: 0),
            directionLabel.topAnchor.constraint(equalTo: amount.bottomAnchor, constant: 16),
        ])
        
        address.constrain([
            address.centerXAnchor.constraint(equalTo: directionSymbolImageView.centerXAnchor, constant: 0),
            address.topAnchor.constraint(equalTo: directionLabel.bottomAnchor, constant: 5),
            address.widthAnchor.constraint(equalTo: scrollViewContent.widthAnchor, multiplier: 0.85),
        ])
        
        dateLabel.constrain([
            dateLabel.topAnchor.constraint(equalTo: address.bottomAnchor, constant: 50 + 28),
            dateLabel.leftAnchor.constraint(equalTo: scrollViewContent.leftAnchor, constant: padding),
        ])
        timestamp1.constrain([
            timestamp1.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            timestamp1.leftAnchor.constraint(equalTo: dateLabel.leftAnchor, constant: 0),
            timestamp1.rightAnchor.constraint(equalTo: timestamp2.leftAnchor, constant: -padding),
        ])
        
        processedLabel.constrain([
            processedLabel.topAnchor.constraint(equalTo: address.bottomAnchor, constant: 50 + 28),
            processedLabel.rightAnchor.constraint(equalTo: scrollViewContent.rightAnchor, constant: -padding),
            processedLabel.widthAnchor.constraint(equalTo: scrollViewContent.widthAnchor, multiplier: 0.4, constant: 0),
        ])
        timestamp2.constrain([
            timestamp2.topAnchor.constraint(equalTo: processedLabel.bottomAnchor, constant: 10),
            timestamp2.leftAnchor.constraint(equalTo: processedLabel.leftAnchor, constant: 0),
        ])
        
        statusLabel.constrain([
            statusLabel.topAnchor.constraint(equalTo: timestamp1.bottomAnchor, constant: 30),
            statusLabel.leftAnchor.constraint(equalTo: scrollViewContent.leftAnchor, constant: padding),
        ])
        status.constrain([
            status.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            status.leftAnchor.constraint(equalTo: statusLabel.leftAnchor, constant: 0),
            status.heightAnchor.constraint(equalToConstant: 28),
        ])
        
        confirmationsLabel.constrain([
            confirmationsLabel.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 30),
            confirmationsLabel.leftAnchor.constraint(equalTo: scrollViewContent.leftAnchor, constant: padding),
        ])
        
        let cardTopAnchor = card.topAnchor.constraint(equalTo: confirmationsLabel.bottomAnchor, constant: 30)
        card.constrain([
            cardTopAnchor,
            card.leftAnchor.constraint(equalTo: scrollViewContent.leftAnchor, constant: padding),
            card.rightAnchor.constraint(equalTo: scrollViewContent.rightAnchor, constant: -padding),
        ])
        
        let walletOverlay = WalletOverlayView()
        scrollViewContent.addSubview(walletOverlay)
        walletOverlay.constrain([
            walletOverlay.topAnchor.constraint(equalTo: confirmationsLabel.bottomAnchor, constant: 30 + cardOffset),
            walletOverlay.bottomAnchor.constraint(equalTo: scrollViewContent.bottomAnchor, constant: 0),
            walletOverlay.leftAnchor.constraint(equalTo: scrollViewContent.leftAnchor, constant: 0),
            walletOverlay.rightAnchor.constraint(equalTo: scrollViewContent.rightAnchor, constant: 0),
            walletOverlay.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        /* CARD specific content */
        
        // header line
        digiLogo.constrain([
            digiLogo.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            digiLogo.leftAnchor.constraint(equalTo: card.leftAnchor, constant: 15),
            digiLogo.widthAnchor.constraint(equalToConstant: 31),
            digiLogo.heightAnchor.constraint(equalToConstant: 31),
        ])
        
        amountDGB.constrain([
            amountDGB.centerYAnchor.constraint(equalTo: digiLogo.centerYAnchor, constant: 0),
            amountDGB.leftAnchor.constraint(equalTo: digiLogo.rightAnchor, constant: 10),
            amountDGB.heightAnchor.constraint(equalToConstant: 31),
        ])
        
        timeSinceTransactionLabel.constrain([
            timeSinceTransactionLabel.centerYAnchor.constraint(equalTo: digiLogo.centerYAnchor, constant: 0),
            timeSinceTransactionLabel.leftAnchor.constraint(equalTo: amountDGB.rightAnchor, constant: 10),
            timeSinceTransactionLabel.rightAnchor.constraint(equalTo: card.rightAnchor, constant: -20)
        ])
        
        // elements beneath card's header line
        let margin: CGFloat = 20
        amountDetailsHeader.constrain([
            amountDetailsHeader.topAnchor.constraint(equalTo: timeSinceTransactionLabel.bottomAnchor, constant: margin),
            amountDetailsHeader.leftAnchor.constraint(equalTo: digiLogo.leftAnchor, constant: 0),
            amountDetailsHeader.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        amountDetails.constrain([
            amountDetails.topAnchor.constraint(equalTo: amountDetailsHeader.bottomAnchor, constant: 10),
            amountDetails.leftAnchor.constraint(equalTo: amountDetailsHeader.leftAnchor, constant: 0),
            amountDetails.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        
        blockHeightHeader.constrain([
            blockHeightHeader.topAnchor.constraint(equalTo: amountDetails.bottomAnchor, constant: margin),
            blockHeightHeader.leftAnchor.constraint(equalTo: digiLogo.leftAnchor, constant: 0),
            blockHeightHeader.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        blockHeight.constrain([
            blockHeight.topAnchor.constraint(equalTo: blockHeightHeader.bottomAnchor, constant: 10),
            blockHeight.leftAnchor.constraint(equalTo: blockHeightHeader.leftAnchor, constant: 0),
            blockHeight.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        
        txHashHeader.constrain([
            txHashHeader.topAnchor.constraint(equalTo: blockHeight.bottomAnchor, constant: margin),
            txHashHeader.leftAnchor.constraint(equalTo: digiLogo.leftAnchor, constant: 0),
            txHashHeader.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        txHash.constrain([
            txHash.topAnchor.constraint(equalTo: txHashHeader.bottomAnchor, constant: 10),
            txHash.leftAnchor.constraint(equalTo: txHashHeader.leftAnchor, constant: 0),
            txHash.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        
        commentsHeader.constrain([
            commentsHeader.topAnchor.constraint(equalTo: txHash.bottomAnchor, constant: margin),
            commentsHeader.leftAnchor.constraint(equalTo: digiLogo.leftAnchor, constant: 0),
            commentsHeader.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
        ])
        comment.constrain([
            comment.topAnchor.constraint(equalTo: commentsHeader.bottomAnchor, constant: 0),
            comment.leftAnchor.constraint(equalTo: commentsHeader.leftAnchor, constant: 0),
            comment.rightAnchor.constraint(equalTo: timeSinceTransactionLabel.rightAnchor, constant: 0),
            comment.heightAnchor.constraint(equalToConstant: 30),
        ])
        
        let commentBottomBorder = UIView(color: C.Colors.greyBlue)
        card.addSubview(commentBottomBorder)
        commentBottomBorder.constrain([
            commentBottomBorder.heightAnchor.constraint(equalToConstant: 1),
            commentBottomBorder.bottomAnchor.constraint(equalTo: comment.bottomAnchor, constant: 0),
            commentBottomBorder.leftAnchor.constraint(equalTo: comment.leftAnchor, constant: 0),
            commentBottomBorder.rightAnchor.constraint(equalTo: comment.rightAnchor, constant: 0),
        ])
        
        // card height
        comment.constrain([
            comment.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -80),
        ])

        layoutIfNeeded()
    }

    private func setData() {
        scrollView.showsVerticalScrollIndicator = false
        
        timeSinceTransactionLabel.textAlignment = .right
        timeSinceTransactionLabel.lineBreakMode = .byWordWrapping
        timeSinceTransactionLabel.numberOfLines = 0
        
        amountDGB.lineBreakMode = .byCharWrapping
        
        backgroundColor = .clear

        statusHeader.text = S.TransactionDetails.statusHeader
        commentsHeader.text = S.TransactionDetails.commentsHeader
        amountHeader.text = S.TransactionDetails.amountHeader
        availability.text = S.Transaction.available
    
        blockHeightHeader.text = S.TransactionDetails.blockHeightLabel
        txHashHeader.text = S.TransactionDetails.txHashHeader
        amountDetailsHeader.text = S.TransactionDetails.amountHeader
        
        processedLabel.text = S.TransactionDetailView.processed.uppercased()
        dateLabel.text = S.TransactionDetailView.date.uppercased()
        statusLabel.text = S.TransactionDetailView.status.uppercased()
        
        comment.font = .customBody(size: 13.0)
        comment.textColor = C.Colors.text
        comment.isScrollEnabled = false
        comment.returnKeyType = .done
        comment.delegate = self
        comment.backgroundColor = .clear

        timestamp1.numberOfLines = 0
        timestamp1.lineBreakMode = .byWordWrapping
        
        moreButton.setTitle(S.TransactionDetails.more, for: .normal)
        moreButton.tintColor = C.Colors.text
        moreButton.titleLabel?.font = .customBold(size: 14.0)

        moreButton.tap = { [weak self] in
            self?.addMoreView()
        }

        amount.minimumScaleFactor = 0.5
        amount.adjustsFontSizeToFitWidth = true

        fullAddress.titleLabel?.font = .customBody(size: 13.0)
        fullAddress.titleLabel?.numberOfLines = 0
        fullAddress.titleLabel?.lineBreakMode = .byCharWrapping
        fullAddress.tintColor = C.Colors.text
        
        fullAddress.tap = strongify(self) { myself in
            myself.fullAddress.tempDisable()
            myself.store?.trigger(name: .lightWeightAlert(S.Receive.copied))
            UIPasteboard.general.string = myself.fullAddress.titleLabel?.text
        }
        fullAddress.contentHorizontalAlignment = .left

        txHash.titleLabel?.font = .customBody(size: 13.0)
        txHash.titleLabel?.numberOfLines = 0
        txHash.titleLabel?.lineBreakMode = .byCharWrapping
        txHash.tintColor = C.Colors.text
        txHash.contentHorizontalAlignment = .left
        txHash.tap = strongify(self) { myself in
            myself.txHash.tempDisable()
            myself.store?.trigger(name: .lightWeightAlert(S.Receive.copied))
            UIPasteboard.general.string = myself.txHash.titleLabel?.text
        }
    }

    private func addMoreView() {
        moreButton.removeFromSuperview()
        let newSeparator = UIView(color: C.Colors.greyBlue)
        moreContentView.addSubview(newSeparator)
        moreContentView.addSubview(txHashHeader)
        moreContentView.addSubview(txHash)
        txHashHeader.text = S.TransactionDetails.txHashHeader
        txHashHeader.constrain([
            txHashHeader.leadingAnchor.constraint(equalTo: moreContentView.leadingAnchor),
            txHashHeader.topAnchor.constraint(equalTo: moreContentView.topAnchor) ])
        txHash.constrain([
            txHash.leadingAnchor.constraint(equalTo: txHashHeader.leadingAnchor),
            txHash.topAnchor.constraint(equalTo: txHashHeader.bottomAnchor, constant: 2.0),
            txHash.trailingAnchor.constraint(lessThanOrEqualTo: moreContentView.trailingAnchor) ])

        let blockHeightHeader = UILabel(font: txHashHeader.font, color: txHashHeader.textColor)
        blockHeightHeader.text = S.TransactionDetails.blockHeightLabel
        moreContentView.addSubview(blockHeightHeader)
        moreContentView.addSubview(blockHeight)
        blockHeightHeader.constrain([
            blockHeightHeader.leadingAnchor.constraint(equalTo: txHashHeader.leadingAnchor),
            blockHeightHeader.topAnchor.constraint(equalTo: txHash.bottomAnchor, constant: C.padding[1]) ])
        blockHeight.constrain([
            blockHeight.leadingAnchor.constraint(equalTo: blockHeightHeader.leadingAnchor),
            blockHeight.topAnchor.constraint(equalTo: blockHeightHeader.bottomAnchor) ])

        newSeparator.constrain([
            newSeparator.leadingAnchor.constraint(equalTo: blockHeight.leadingAnchor),
            newSeparator.topAnchor.constraint(equalTo: blockHeight.bottomAnchor, constant: C.padding[2]),
            newSeparator.trailingAnchor.constraint(equalTo: moreContentView.trailingAnchor),
            newSeparator.heightAnchor.constraint(equalToConstant: 1.0),
            newSeparator.bottomAnchor.constraint(equalTo: moreContentView.bottomAnchor) ])

        //Scroll to expaned more view
        scrollView.layoutIfNeeded()
        if scrollView.contentSize.height > scrollView.bounds.height {
            let point = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height)
            self.scrollView.setContentOffset(point, animated: true)
        }
    }
    
    

    override func layoutSubviews() {
        super.layoutSubviews()
        
        DispatchQueue.main.async {
            // save important properties of views
            self.transactionDetailCardView.foldLineTop = self.address.frame.origin.y + self.address.frame.height + 35
            self.initCard()
        }
    }
    
    func resetView() {
        cardExpanded = true
        hideCard()
        cardExpanded = false
    }
    
    fileprivate func saveComment(comment: String) {
        guard let kvStore = self.kvStore else { return }
        if let metaData = transaction?.metaData {
            metaData.comment = comment
            do {
                let _ = try kvStore.set(metaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        } else {
            guard let rate = self.rate else { return }
            guard let transaction = self.transaction else { return }
            let newMetaData = TxMetaData(transaction: transaction.rawTransaction, exchangeRate: rate.rate, exchangeRateCurrency: rate.code, feeRate: 0.0, deviceId: UserDefaults.standard.deviceID)
            newMetaData.comment = comment
            do {
                let _ = try kvStore.set(newMetaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        }
        if let tx = transaction {
            store?.trigger(name: .txMemoUpdated(tx.hash))
        }
    }

    //MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        modalTransitioningDelegate?.shouldDismissInteractively = false
        card.gestureRecognizers?.first?.isEnabled = false
        respondToKeyboardAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        modalTransitioningDelegate?.shouldDismissInteractively = true
        card.gestureRecognizers?.first?.isEnabled = true
        respondToKeyboardAnimation(notification: notification)
    }

    private func respondToKeyboardAnimation(notification: Notification) {
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        guard let height = scrollViewHeight else { return }
        height.constant = height.constant + info.deltaY
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TransactionDetailCollectionViewCell : UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        didBeginEditing?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        didEndEditing?()
        guard let text = textView.text else { return }
        saveComment(comment: text)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.rangeOfCharacter(from: CharacterSet.newlines) == nil else {
            textView.resignFirstResponder()
            return false
        }

        let count = (textView.text ?? "").utf8.count + text.utf8.count
        if count > C.maxMemoLength {
            return false
        } else {
            return true
        }
    }
}
