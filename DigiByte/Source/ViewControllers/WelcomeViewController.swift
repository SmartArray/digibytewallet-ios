//
//  WelcomeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-09-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

fileprivate class WelcomeViewStartPage: UIViewController {
    fileprivate let titleLabel: UILabel = {
        let lbl = UILabel(font: .customBody(size: 36), color: C.Colors.text)
        
        lbl.numberOfLines = 0
        lbl.lineBreakMode = .byWordWrapping
        
        return lbl
    }()
    
    fileprivate let descLabel: UILabel = {
        let lbl = UILabel(font: .customBody(size: 16), color: UIColor(red: 156 / 255, green: 158 / 255, blue: 185 / 255, alpha: 1))
        
        lbl.numberOfLines = 0
        lbl.lineBreakMode = .byWordWrapping
        
        return lbl
    }()
    
    fileprivate let smallImage: UIImageView = {
        let img = UIImageView(image: nil)
        img.contentMode = .scaleAspectFit
        return img
    }()
    
    func animate() {
        
    }
    
    init(smallImage: UIImage?, title: String, description: String) {
        super.init(nibName: nil, bundle: nil)
        
        self.smallImage.image = smallImage
        titleLabel.text = title
        descLabel.text = description
        
        addSubviews()
        addConstraints()
        setStyle()
    }
    
    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(descLabel)
        view.addSubview(smallImage)
    }
    
    private func addConstraints() {
        titleLabel.constrain([
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 32),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -32),
        ])
        
        descLabel.constrain([
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            descLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor, constant: 0),
            descLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: 0),
        ])
        
        smallImage.constrain([
            smallImage.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -50),
            smallImage.leftAnchor.constraint(equalTo: titleLabel.leftAnchor, constant: 0),
        ])
    }
    
    private func setStyle() {
        view.backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class WelcomeViewPage: UIViewController {
    fileprivate let bigImage: UIImageView = {
        let img = UIImageView(image: nil)
        img.contentMode = .scaleAspectFit
        return img
    }()
    fileprivate let smallImage = UIImageView(image: nil)
    fileprivate let titleLabel = UILabel(font: .customBody(size: 26), color: C.Colors.text)
    fileprivate let subTitleLabel = UILabel(font: .customBody(size: 18), color: UIColor(red: 156 / 255, green: 158 / 255, blue: 185 / 255, alpha: 1))
    
    init(image: UIImage?, title: String, description: String) {
        super.init(nibName: nil, bundle: nil)
        
        titleLabel.text = title
        subTitleLabel.text = description
        
        addSubviews()
        addConstraints()
        setStyle()
        
        if let image = image {
            bigImage.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            bigImage.image = image
        }
    }
    
    init(smallImage: UIImage?, title: String, description: String, topView: UIView) {
        super.init(nibName: nil, bundle: nil)
        
        titleLabel.text = title
        subTitleLabel.text = description
        self.smallImage.image = smallImage
        self.smallImage.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        
        view.addSubview(topView)
        topView.constrain([
            topView.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            topView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            topView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            topView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3)
        ])
        
        addSubviews()
        addConstraints()
        setStyle()
    }
    
    private func addSubviews() {
        view.addSubview(bigImage)
        view.addSubview(titleLabel)
        view.addSubview(subTitleLabel)
        view.addSubview(smallImage)
    }
    
    private func addConstraints() {
        let topConstraint = bigImage.topAnchor.constraint(equalTo: view.topAnchor, constant: 60)
        topConstraint.priority = UILayoutPriority(rawValue: 230)
        
        let widthConstraint = bigImage.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.25)
        widthConstraint.priority = UILayoutPriority(rawValue: 300)

        bigImage.constrain([
            bigImage.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
            widthConstraint,
        ])
        
        let subtitleBottomAnchor = subTitleLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        subTitleLabel.constrain([
            subtitleBottomAnchor,
            subTitleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 50),
            subTitleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -50),
        ])
        
        titleLabel.constrain([
            titleLabel.bottomAnchor.constraint(equalTo: subTitleLabel.topAnchor, constant: -15),
            titleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 30),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -30),
        ])
        
        if smallImage.image != nil {
            smallImage.constrain([
                smallImage.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
                smallImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                smallImage.widthAnchor.constraint(equalToConstant: 62),
                smallImage.heightAnchor.constraint(equalToConstant: 62)
            ])
            
            bigImage.constrain([ topConstraint ])
        } else {
            let titleMarginToImage = titleLabel.topAnchor.constraint(greaterThanOrEqualTo: bigImage.bottomAnchor, constant: 60)
            titleMarginToImage.priority = UILayoutPriority(231)
            
            titleLabel.constrain([
                titleMarginToImage
            ])
            
            bigImage.constrain([
                bigImage.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50)
            ])
        }
    }
    
    private func setStyle() {
        view.backgroundColor = .clear
        
        titleLabel.textAlignment = .center
        subTitleLabel.textAlignment = .center
        
        subTitleLabel.numberOfLines = 0
    }
    
    func animate() {
        if #available(iOS 10.0, *) {
            if self.bigImage.transform != CGAffineTransform(scaleX: 1.0, y: 1.0) ||
                self.smallImage.transform != CGAffineTransform(scaleX: 1.0, y: 1.0)
            {
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.prepare()
                feedback.impactOccurred()
            }
        }
        
        UIView.spring(0.3, animations: {
            self.bigImage.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.smallImage.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }) { (_) in
            
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class WelcomeViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    private var callback: (() -> Void)?
    
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let first = WelcomeViewStartPage(smallImage: UIImage(named: "welcome_midniteIcon"), title: S.Welcome.page1Title, description: S.Welcome.page1Text)
    private let second = WelcomeViewPage(image: UIImage(named: "welcome_send"), title: S.Welcome.page2Title, description: S.Welcome.page2Text)
    private let third = WelcomeViewPage(image: UIImage(named: "welcome_receive"), title: S.Welcome.page3Title, description: S.Welcome.page3Text)
    private let fourth: WelcomeViewPage = {
        let view = UIView()
        let card = UIImageView(image: UIImage(named: "welcome_mainCard"))
        view.addSubview(card)
        
        let p = WelcomeViewPage(
            smallImage: UIImage(named: "welcome_touchId"),
            title: S.Welcome.page4Title,
            description: S.Welcome.page4Text,
            topView: view
        )
        
        card.constrain([
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0),
        ])
        
        return p
    }()
    private let fifth: WelcomeViewPage = {
        let page = WelcomeViewPage(
            image: UIImage(named: "welcome_digiid"),
            title: S.Welcome.page5Title,
            description: S.Welcome.page4Text
        )
        
        return page
    }()
    private let sixth: WelcomeViewPage = {
        let page = WelcomeViewPage(
            image: nil,
            title: "",
            description: ""
        )
        
        return page
    }()
    
    // pages as array
    private lazy var pages = {
        return [first, second, third, fourth, fifth, sixth]
    }()
    
    // additional background images
    let blurryBackground: UIImageView = {
        let img = UIImageView(image: UIImage(named: "welcome_bluryBg"))
        img.contentMode = .scaleAspectFill
        return img
    }()
    
    private let digiLogo: UIImageView = {
        let img = UIImageView(image: UIImage(named: "DigiLogo")?.withRenderingMode(.alwaysTemplate))
        img.layer.opacity = 0.1
        img.contentMode = .scaleAspectFit
        img.tintColor = .black
        return img
    }()
    
    private let dismissBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setBackgroundImage(UIImage(named: "welcome_dismiss"), for: .normal)
        return btn
    }()
    
    override func viewDidLoad() {
        dataSource = self
        delegate = self
        setViewControllers([first], direction: .forward, animated: true, completion: nil)
        
        addSubviews()
        addConstraints()
        setInitialData()
        setStyle()
    }
    
    private func setStyle() {
        view.backgroundColor = C.Colors.background
        blurryBackground.layer.opacity = 0
        dismissBtn.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
    }

    private func addSubviews() {
        view.insertSubview(blurryBackground, at: 0)
        view.insertSubview(digiLogo, at: 0)
        pages.last!.view.addSubview(dismissBtn)
    }

    private func addConstraints() {
        blurryBackground.constrain([
            blurryBackground.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            blurryBackground.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            blurryBackground.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0)
        ])
        
        digiLogo.constrain([
            digiLogo.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 100),
            digiLogo.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            digiLogo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.1),
            digiLogo.heightAnchor.constraint(equalToConstant: 500),
        ])
        
        dismissBtn.constrain([
            dismissBtn.centerYAnchor.constraint(equalTo: pages.last!.view.centerYAnchor, constant: 0),
            dismissBtn.centerXAnchor.constraint(equalTo: pages.last!.view.centerXAnchor, constant: 0),
            dismissBtn.widthAnchor.constraint(equalToConstant: 140),
            dismissBtn.heightAnchor.constraint(equalToConstant: 140),
        ])
    }

    private func setInitialData() {
        dismissBtn.tap = strongify(self) { myself in
            // myself.dismiss(animated: true, completion: nil)
            self.callback?()
        }
    }

    private func setBodyText() {

    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let viewControllerIndex = self.pages.firstIndex(of: viewController) {
            if viewControllerIndex != 0 {
                // go to previous page in array
                return self.pages[viewControllerIndex - 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let viewControllerIndex = self.pages.firstIndex(of: viewController) {
            if viewControllerIndex < self.pages.count - 1 {
                // go to next page in array
                return self.pages[viewControllerIndex + 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        // self.pageControl.currentPage = pageViewController.viewControllers!.first!.view.tag
        guard let page = pageViewController.viewControllers!.first else { return }
        var showBlurryBg = false
        var showDigiLogo = false
        
        if first == page {
            first.animate()
            showDigiLogo = true
        } else if fourth == page {
            fourth.animate()
            showBlurryBg = true
        } else {
            let vc = page as? WelcomeViewPage
            vc?.animate()
        }
        
        
        UIView.animate(withDuration: 0.3) {
            self.blurryBackground.layer.opacity = showBlurryBg ? 1.0 : 0
        }
        
        if self.sixth == page {
            if #available(iOS 10.0, *) {
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.prepare()
                feedback.impactOccurred()
            }
            
            UIView.spring(0.3, animations: {
                self.dismissBtn.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.callback?()
                })
            }
        }

        UIView.animate(withDuration: 1) {
            self.digiLogo.layer.opacity = showDigiLogo ? 0.1 : 0
        }
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pages.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
}
