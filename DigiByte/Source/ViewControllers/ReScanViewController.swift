//
//  ReScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ReScanViewController : UIViewController, Subscriber {

    init(store: BRStore) {
        self.store = store
        self.faq = .buildFaqButton(store: store, articleId: ArticleIds.reScan)
        super.init(nibName: nil, bundle: nil)
    }

    private let header = UILabel(font: .customMedium(size: 26.0), color: C.Colors.text)
    private let body = UILabel.wrapping(font: .customBody(size: 15.0), color: C.Colors.text)
    private let button = ShadowButton(title: S.ReScan.buttonTitle, type: .primary)
    private let footer = UILabel.wrapping(font: .customBody(size: 16.0), color: C.Colors.greyBlue)
    private let store: BRStore
    private let faq: UIButton

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(faq)
        faq.isHidden = true // TODO: Writeup support/FAQ documentation for digibyte wallet
        view.addSubview(body)
        view.addSubview(button)
        view.addSubview(footer)
    }

    private func addConstraints() {
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]) ])
        faq.constrain([
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            faq.widthAnchor.constraint(equalToConstant: 44.0),
            faq.heightAnchor.constraint(equalToConstant: 44.0) ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: faq.trailingAnchor) ])
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: faq.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor, constant: -C.padding[3]) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -C.padding[2]),
            button.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = C.Colors.background
        header.text = S.ReScan.header
        body.attributedText = bodyText
        footer.text = S.ReScan.footer
        button.tap = { [weak self] in
            self?.presentRescanAlert()
        }
    }

    private func presentRescanAlert() {
        // Show privacy window
        let wnd = DGBConfirmAlert(title: S.ReScan.fastSync, message: S.ReScan.fastSyncDescription, image: UIImage(named: "privacy"), okTitle: S.ReScan.fastSync, cancelTitle: S.Button.cancel, alternativeButtonTitle: S.ReScan.regularSync)
        
        wnd.confirmCallback = { (close: DGBCallback) in
            UserDefaults.fastSyncEnabled = true
            close()
            
            self.store.trigger(name: .rescan)
            self.dismiss(animated: true, completion: nil)
        }
        
        wnd.cancelCallback = { (close: DGBCallback) in
            close()
        }
        
        wnd.alternativeCallback = { (close: DGBCallback) in
            UserDefaults.fastSyncEnabled = false
            close()
            
            self.store.trigger(name: .rescan)
            self.dismiss(animated: true, completion: nil)
        }
            
        self.present(wnd, animated: true, completion: nil)
    }

    private func showSyncView() {
        guard let window = UIApplication.shared.keyWindow else { return }
        let mask = UIView(color: .transparentBlack)
        mask.alpha = 0.0
        window.addSubview(mask)
        mask.constrain(toSuperviewEdges: nil)

        let syncView = SyncingView()
        syncView.backgroundColor = .white
        syncView.layer.cornerRadius = 4.0
        syncView.layer.masksToBounds = true

        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress },
                        callback: { state in
            syncView.timestamp = state.walletState.lastBlockTimestamp
            syncView.progress = CGFloat(state.walletState.syncProgress)
        })
        mask.addSubview(syncView)
        syncView.constrain([
            syncView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: C.padding[2]),
            syncView.topAnchor.constraint(equalTo: window.topAnchor, constant: 136.0 + C.padding[2]),
            syncView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -C.padding[2]),
            syncView.heightAnchor.constraint(equalToConstant: 88.0) ])

        /*
        UIView.animate(withDuration: C.animationDuration, animations: {
            mask.alpha = 1.0
        })
         */

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            mask.removeFromSuperview()
            self.dismiss(animated: true, completion: nil)
        })
    }

    private var bodyText: NSAttributedString {
        let body = NSMutableAttributedString()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10.0
        
        let headerAttributes = [ NSAttributedString.Key.font: UIFont.customMedium(size: 17.0),
                                 NSAttributedString.Key.foregroundColor: C.Colors.text,
                                 NSAttributedString.Key.paragraphStyle: paragraphStyle,
                               ]
        let bodyAttributes = [ NSAttributedString.Key.font: UIFont.customBody(size: 16.0),
                               NSAttributedString.Key.foregroundColor: C.Colors.text ]

        body.append(NSAttributedString(string: "\(S.ReScan.subheader1)\n", attributes: headerAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.body1)\n\n", attributes: bodyAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.subheader2)\n", attributes: headerAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.body2)\n\n\(S.ReScan.body3)", attributes: bodyAttributes))
        return body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
