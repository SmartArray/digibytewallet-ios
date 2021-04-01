//
//  AboutViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import SafariServices

class AboutViewController : UIViewController {

    private let scrollView = UIScrollView(frame: .zero)
    private let versionLabel = UILabel(frame: .zero)
    private let introductionLabel = UILabel(frame: .zero)
    private let logo = UIImageView(image: UIImage(named: "aboutHeaderImage"))
    private let credits = UITextView(frame: .zero)

    init() {
        super.init(nibName: nil, bundle: nil)
        addSubviews()
        addConstraints()
        setData()
        setActions()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubviews() {
        view.addSubview(scrollView)
        scrollView.addSubview(logo)
        scrollView.addSubview(versionLabel)
        scrollView.addSubview(introductionLabel)
        scrollView.addSubview(credits)
        
    }

    private func addConstraints() {
        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        
        logo.constrain([
            logo.topAnchor.constraint(equalTo: scrollView.topAnchor),
            logo.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            logo.widthAnchor.constraint(equalToConstant: 180),
        ])
        
        versionLabel.constrain([
            versionLabel.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 20),
            versionLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
        ])
        
        introductionLabel.constrain([
            introductionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 30),
            introductionLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 25),
            introductionLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -25),
        ])
        
        credits.constrain([
            credits.topAnchor.constraint(equalTo: introductionLabel.bottomAnchor, constant: 30),
            credits.centerXAnchor.constraint(equalTo: logo.centerXAnchor),
            credits.widthAnchor.constraint(equalToConstant: 230),
            credits.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -30)
        ])
    }

    private func setData() {
        view.backgroundColor = C.Colors.background
        
        scrollView.alwaysBounceVertical = true
        
        versionLabel.numberOfLines = 1
        versionLabel.textColor = C.Colors.blueGrey
        versionLabel.font = UIFont(name: "Helvetica", size: 16)
        versionLabel.textAlignment = .center
        
        introductionLabel.numberOfLines = 0
        introductionLabel.textColor = C.Colors.blueGrey
        introductionLabel.font = UIFont(name: "Helvetica", size: 14)
        introductionLabel.textAlignment = .center
        
        credits.font = UIFont(name: "Helvetica", size: 14)
        credits.textColor = C.Colors.blueGrey
        
        versionLabel.text = String(format: S.About.version, C.version)
        introductionLabel.text = S.About.introduction
        credits.attributedText = creditText()
        credits.backgroundColor = .clear
        credits.isScrollEnabled = false
        credits.setContentOffset(.zero, animated: false)
        credits.textAlignment = .center
        
        credits.isEditable = false
        credits.autocorrectionType = .no
        credits.isSelectable = false
    }
    
    private func createLine(_ text: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        
        return NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.foregroundColor: C.Colors.blueGrey,
                NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 14) ?? UIFont.systemFont(ofSize: 14),
                NSAttributedString.Key.paragraphStyle: style,
            ]
        )
    }
    
    private func createHeading(_ text: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 10
        
        return NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.white,
                NSAttributedString.Key.font: UIFont(name: "Helvetica-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14),
                NSAttributedString.Key.paragraphStyle: style,
            ]
        )
    }
    
    private func creditText() -> NSAttributedString {
        let res = NSMutableAttributedString(string: "")
        
        res.append(createHeading("\(S.About.development)\n"))
        res.append(createLine("GTO90\n"))
        res.append(createLine("Noah Seidmann\n"))
        res.append(createLine("Yoshi Jäger\n"))
        res.append(createLine("Thomas Ploentzke\n"))
        res.append(NSAttributedString(string: "\n"))
        
        res.append(createHeading("\(S.About.ui)\n"))
        res.append(createLine("Damir Čengić\n"))
        res.append(createLine("Antonela Bender\n"))
        res.append(NSAttributedString(string: "\n"))
        
        res.append(createHeading("\(S.About.specialThanks)\n"))
        res.append(createLine("Nigel Borreman\n"))
        res.append(createLine("Murat Akyurt\n"))
        res.append(createLine("Josiah Spackman\n"))
        res.append(createLine("Also special thanks to BRD\n"))
        res.append(NSAttributedString(string: "\n"))
        
        res.append(createHeading("\(S.About.translations)\n"))
        res.append(createLine("Rutger Krijnen\n"))
        res.append(createLine("Nigel Borreman\n"))
        res.append(createLine("Glenn\n"))
		res.append(createLine("GTO90\n"))
        res.append(NSAttributedString(string: "\n"))
        
        return res
    }

    private func setActions() {
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        let debugStr = GlobalDebug.default.serialize()
        UIPasteboard.general.string = debugStr
    }

//    private func presentURL(string: String) {
//        let vc = SFSafariViewController(url: URL(string: string)!)
//        self.present(vc, animated: true, completion: nil)
//    }
}
