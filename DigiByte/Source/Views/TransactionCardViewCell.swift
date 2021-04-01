//
//  TransactionCardViewCell.swift
//  breadwallet
//
//  Created by Yoshi Jäger on 2018-08-04.
//  Copyright © 2018 DigiByte Foundation, All rights reserved.
//

import UIKit

private let timestampRefreshRate: TimeInterval = 10.0

fileprivate class CardView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 0x2E / 255, green: 0x30 / 255, blue: 0x46 / 255, alpha: 1.0)
        layer.masksToBounds = true
        layer.cornerRadius = 15
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TransactionCardViewCell: UITableViewCell, Subscriber {
    
    let container: UIView = CardView()
    
    //MARK: - Private
    private let overlay = WalletOverlayView()
    private let transactionLabel = UILabel(font: UIFont.customBody(size: 13.0))
    private let address = UILabel(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let status = UILabel(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let comment = UILabel.wrapping(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let timestamp = UILabel(font: UIFont.customMedium(size: 13.0), color: C.Colors.text)
    private let shadowView = MaskedShadow()
    private let innerShadow = UIView()
    private let topPadding: CGFloat = 19.0
    private var style: TransactionCellStyle = .first
    private var transaction: Transaction?
    private let availability = UILabel(font: .customBold(size: 13.0), color: .txListGreen)
    private var timer: Timer? = nil
    private let receivedImage = UIImage(named: "receivedTransaction")
    private let sentImage = UIImage(named: "sentTransaction")
    
    private let glyphContainer = UIView()
    private let glyph = UIImageView()
    private let assetReceivedImage = UIImage(named: "da-receive")?.withRenderingMode(.alwaysTemplate)
    private let assetSentImage = UIImage(named: "da-send")?.withRenderingMode(.alwaysTemplate)
    private let assetBurnedImage = UIImage(named: "da-burn")?.withRenderingMode(.alwaysTemplate)
    private let assetUnknownImage = UIImage(named: "da-unknown")?.withRenderingMode(.alwaysTemplate)
    
    private let arrow = UIImageView(image: UIImage(named: "receivedTransaction"))
    private let amountCommentContainer = UIView()
    
    private static let GlyphSize: CGFloat = 26.0
    
    private class TransactionCardViewCellWrapper {
        weak var target: TransactionCardViewCell?
        init(target: TransactionCardViewCell) {
            self.target = target
        }
        
        @objc func timerDidFire() {
            target?.updateTimestamp()
        }
    }
    
    //MARK: - Public
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func setStyle(_ style: TransactionCellStyle) {
        // container.style = style
        shadowView.style = style
        if style == .last || style == .single {
            innerShadow.isHidden = true
        } else {
            innerShadow.isHidden = false
        }
    }
    
    private func findAssetIndex(_ utxos: [ExtendedTransactionOutputModel]) -> Int {
        return utxos.firstIndex { $0.assets.count > 0 } ?? 0
    }
    
    func setTransaction(_ transaction: Transaction, isBtcSwapped: Bool, rate: Rate, maxDigits: Int, isSyncing: Bool) {
        self.transaction = transaction
        
        if
            !UserDefaults.showRawTransactionsOnly,
                if utxos.count > 0 {
            let assetTitle = transaction.assetTitle
                    
        {
            // Get Asset Preview Text
                        if let assetModel = AssetHelper.getAssetModel(assetID: utxo.assets[0].assetId) {
            var previewText: String = assetTitle
                        } else {
                            transactionLabel.text = S.Assets.unresolved
                        }
            if let amountPreview = transaction.assetAmount {
                        // Multiple assets were transferred in one transaction
                        transactionLabel.text = S.Assets.multipleAssets
                    } else {
                        // No assets
                        transactionLabel.text = S.Assets.noMetadata
                    }
                previewText = "\(previewText) (\(amountPreview))"
                    // No data available
                    transactionLabel.text = S.Assets.noMetadata
                }
            } else {
                // Asset not resolved yet
                transactionLabel.text = S.Assets.unresolved
            }
            transactionLabel.text = previewText
        } else {
            // No asset, just a regular transaction:
            // use amount as preview
            transactionLabel.text = transaction.assetTitle ?? transaction.amountDescription(isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: maxDigits)
        }
        
        address.text = String(format: transaction.direction.addressTextFormat, transaction.toAddress ?? "")
        status.text = transaction.status
        comment.text = transaction.comment
        availability.text = transaction.shouldDisplayAvailableToSpend ? S.Transaction.available : ""
        
        if transaction.status == S.Transaction.complete {
            status.isHidden = false
        } else {
            status.isHidden = isSyncing
        }
        
        let timestampInfo = transaction.timeSince
        timestamp.text = timestampInfo.0
        if timestampInfo.1 {
            timer = Timer.scheduledTimer(timeInterval: timestampRefreshRate, target: TransactionCardViewCellWrapper(target: self), selector: NSSelectorFromString("timerDidFire"), userInfo: nil, repeats: true)
        } else {
            timer?.invalidate()
        }
        timestamp.isHidden = !transaction.isValid
        
        if !UserDefaults.showRawTransactionsOnly, transaction.isAssetTx {
            // Choose image by asset direction type
            transactionLabel.textColor = UIColor.da.darkSkyBlue
            glyphContainer.isHidden = false
            arrow.isHidden = true
            
            switch (transaction.assetType) {
            case .received:
                glyph.image = assetReceivedImage
                glyphContainer.backgroundColor = UIColor.da.greenApple
            case .sent:
                glyph.image = assetSentImage
                glyphContainer.backgroundColor = UIColor.da.darkSkyBlue
            case .burned:
                glyph.image = assetBurnedImage
                glyphContainer.backgroundColor = UIColor.da.burnColor
            case .none:
                glyph.image = assetUnknownImage
                glyphContainer.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            }
        } else {
            glyphContainer.isHidden = true
            arrow.isHidden = false
            
            // Choose image by (raw-)transaction direction
            if transaction.direction == .received {
                arrow.image = receivedImage
                transactionLabel.textColor = C.Colors.weirdGreen
            } else {
                arrow.image = sentImage
                transactionLabel.textColor = C.Colors.weirdRed
            }
        }
    }
    
    let container: UIView = CardView()
    
    //MARK: - Private
    private let transactionLabel = UILabel(font: UIFont.customBody(size: 13.0))
    private let address = UILabel(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let status = UILabel(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let comment = UILabel.wrapping(font: UIFont.customBody(size: 13.0), color: C.Colors.text)
    private let timestamp = UILabel(font: UIFont.customMedium(size: 13.0), color: C.Colors.text)
    private let shadowView = MaskedShadow()
    private let innerShadow = UIView()
    private let topPadding: CGFloat = 19.0
    private var style: TransactionCellStyle = .first
    private var transaction: Transaction?
    private let availability = UILabel(font: .customBold(size: 13.0), color: .txListGreen)
    private var timer: Timer? = nil
    private let receivedImage = UIImage(named: "receivedTransaction")
    private let sentImage = UIImage(named: "sentTransaction")
    private let arrow = UIImageView(image: UIImage(named: "receivedTransaction"))
    private let amountCommentContainer = UIView()
    
    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }
    
    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(arrow)
        
        container.addSubview(glyphContainer)
        glyphContainer.addSubview(glyph)
        
        container.addSubview(timestamp)
        
        container.addSubview(amountCommentContainer)
        amountCommentContainer.addSubview(transactionLabel)
        amountCommentContainer.addSubview(comment)
        
        contentView.addSubview(overlay)
    }
    
    private func addConstraints() {
//        contentView.layer.borderColor = UIColor.red.cgColor
//        contentView.layer.borderWidth = 1
        
        contentView.clipsToBounds = true
        overlay.constrain([
            overlay.leftAnchor.constraint(equalTo: container.leftAnchor, constant: -25),
            overlay.rightAnchor.constraint(equalTo: container.rightAnchor, constant: 25),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 11),
            overlay.heightAnchor.constraint(equalToConstant: 35),
        ])
        
//        let maxWidth = container.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
//        maxWidth.priority = .defaultHigh
//
//        let width = container.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8)
//        width.priority = .defaultLow
        
        let width = container.widthAnchor.constraint(equalToConstant: 300)
        
        container.constrain([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),
//            maxWidth,
            width,
            container.heightAnchor.constraint(equalToConstant: 68),
            container.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        arrow.constrain([
            arrow.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 20.0),
            arrow.topAnchor.constraint(equalTo: container.topAnchor, constant: 15.0),
            arrow.heightAnchor.constraint(equalToConstant: TransactionCardViewCell.GlyphSize),
            arrow.widthAnchor.constraint(equalToConstant: TransactionCardViewCell.GlyphSize)
        ])
        
        glyphContainer.constrain([
            glyphContainer.topAnchor.constraint(equalTo: arrow.topAnchor),
            glyphContainer.leftAnchor.constraint(equalTo: arrow.leftAnchor),
            glyphContainer.rightAnchor.constraint(equalTo: arrow.rightAnchor),
            glyphContainer.bottomAnchor.constraint(equalTo: arrow.bottomAnchor),
        ])
        
        let padding: CGFloat = 6.0
        glyph.constrain(toSuperviewEdges: UIEdgeInsets(top: padding, left: padding, bottom: -padding, right: -padding))
        
        timestamp.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        timestamp.constrain([
            timestamp.constraint(.right, toView: container, constant: -20),
            timestamp.constraint(.centerY, toView: arrow),
        ])
        
        transactionLabel.constrain([
            transactionLabel.topAnchor.constraint(equalTo: amountCommentContainer.topAnchor, constant: 0),
            transactionLabel.leftAnchor.constraint(equalTo: amountCommentContainer.leftAnchor, constant: 0),
            transactionLabel.rightAnchor.constraint(lessThanOrEqualTo: amountCommentContainer.rightAnchor, constant: 0)
        ])
        
        comment.constrain([
            comment.topAnchor.constraint(equalTo: transactionLabel.bottomAnchor, constant: 0),
            comment.leftAnchor.constraint(equalTo: transactionLabel.leftAnchor, constant: 0),
            comment.rightAnchor.constraint(equalTo: amountCommentContainer.rightAnchor, constant: 0),
            comment.bottomAnchor.constraint(equalTo: amountCommentContainer.bottomAnchor, constant: 0),
        ])
        
        amountCommentContainer.constrain([
            amountCommentContainer.leftAnchor.constraint(equalTo: arrow.rightAnchor, constant: 10),
            amountCommentContainer.rightAnchor.constraint(lessThanOrEqualTo: timestamp.leftAnchor, constant: -8),
            amountCommentContainer.centerYAnchor.constraint(equalTo: arrow.centerYAnchor, constant: 0),
        ])
        
//        transactionLabel.layer.borderColor = UIColor.green.cgColor
//        transactionLabel.layer.borderWidth = 1
//                comment.layer.borderColor = UIColor.red.cgColor
//                comment.layer.borderWidth = 1
        
        comment.numberOfLines = 1
        comment.lineBreakMode = .byTruncatingTail
        
        /*
         address.constrain([
         address.leadingAnchor.constraint(equalTo: transactionLabel.leadingAnchor),
         address.topAnchor.constraint(equalTo: transactionLabel.bottomAnchor),
         address.trailingAnchor.constraint(lessThanOrEqualTo: timestamp.leadingAnchor, constant: -C.padding[4])])
         address.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .horizontal) */
        /*
         status.constrain([
         status.constraint(.leading, toView: container, constant: C.padding[2]),
         status.constraint(toBottom: comment, constant: C.padding[1]),
         status.constraint(.trailing, toView: container, constant: -C.padding[2]) ]) */
        /*
         availability.constrain([
         availability.leadingAnchor.constraint(equalTo: status.leadingAnchor),
         availability.topAnchor.constraint(equalTo: status.bottomAnchor),
         availability.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2]) ]) */
    }
    
    private func setupStyle() {
        backgroundColor = .clear
        
        comment.textColor = C.Colors.greyBlue
        status.textColor = .darkText
        timestamp.textColor = .grayTextTint
        
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowRadius = 4.0
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 0)
        
        innerShadow.backgroundColor = .secondaryShadow
        
        transactionLabel.numberOfLines = 2
        transactionLabel.lineBreakMode = .byWordWrapping
        transactionLabel.setContentHuggingPriority(UILayoutPriority.defaultHigh, for: .horizontal)
        
        address.lineBreakMode = .byTruncatingMiddle
        address.numberOfLines = 1
        
        transactionLabel.textColor = C.Colors.weirdGreen
        
        glyphContainer.layer.cornerRadius = TransactionCardViewCell.GlyphSize / 2
        glyphContainer.layer.masksToBounds = true
        
        arrow.contentMode = .scaleAspectFit
        glyph.contentMode = .scaleAspectFit
        glyph.tintColor = .white
    }
    
    func updateTimestamp() {
        guard let tx = transaction else { return }
        let timestampInfo = tx.timeSince
        timestamp.text = timestampInfo.0
        if !timestampInfo.1 {
            timer?.invalidate()
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        //intentional noop for now
        //The default selected state doesn't play nicely
        //with this custom cell
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        guard selectionStyle != .none else { container.backgroundColor = .clear; return }
        //container.backgroundColor = .clear ? .secondaryShadow : .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
