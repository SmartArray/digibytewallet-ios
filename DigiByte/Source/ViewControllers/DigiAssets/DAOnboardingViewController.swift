//
//  DAMainViewController.swift
//  digibyte
//
//  Created by Yoshi Jäger on 28.02.19.
//  Copyright © 2019 DigiByte Foundation. All rights reserved.
//

import UIKit

fileprivate class DAOnboardingPage: UIViewController {
    private let containerView = UIView()
    
    private let imageView = UIImageView()
    private let titleLabel = UILabel(font: UIFont.customBold(size: 44), color: UIColor.white)
    
    private let descriptionLabel = UILabel()
    
    init(image: UIImage?, title: String, description: String) {
        super.init(nibName: nil, bundle: nil)
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.0),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1.0),
        ])
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            titleLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor),
        ])
        
        descriptionLabel.constrain([
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            descriptionLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 0),
            descriptionLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: 0),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
        ])
        
        view.addSubview(containerView)
        
        containerView.constrain([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280)
        ])
        
        // style
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        imageView.contentMode = .scaleAspectFit
        
        // content
        titleLabel.text = title
        imageView.image = image
        
        // line height of description label
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 7
        p.alignment = .center
        let attrStr = NSMutableAttributedString(string: description, attributes: [
            .paragraphStyle : p,
            .foregroundColor: UIColor(red: 0xc6 / 255, green: 0xc6 / 255, blue: 0xc6 / 255, alpha: 1.0),
            .font: UIFont.customBody(size: 18)
        ])
        descriptionLabel.attributedText = attrStr
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DAOnboardingViewController: UIViewController {
    // MARK: Static data
    static let ActionButtonCircleSize: CGFloat = 200
    
    // MARK: Public properties
    
    // crash if not set, as it MUST be set
    var nextVC: UIViewController!
    
    // MARK: Private properties
    private let header = ModalHeaderView(title: S.AssetsWelcome.welcomeTitle, style: ModalHeaderViewStyle.light)
    
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private let createViewController = DAOnboardingPage(image: UIImage(named: "da-onboarding-create"), title: S.AssetsWelcome.createHeading, description: S.AssetsWelcome.createText)
    private let sendViewController = DAOnboardingPage(image: UIImage(named: "da-onboarding-send"), title: S.AssetsWelcome.sendHeading, description: S.AssetsWelcome.sendText)
    private let receiveViewController = DAOnboardingPage(image: UIImage(named: "da-onboarding-receive"), title: S.AssetsWelcome.receiveHeading, description: S.AssetsWelcome.receiveText)
    
    private let actionButtonBackgroundCircle = UIButton(frame: CGRect(x: 0, y: 0, width: DAOnboardingViewController.ActionButtonCircleSize, height: DAOnboardingViewController.ActionButtonCircleSize))
    private let actionButton = UIImageView(frame: CGRect(x: 0, y: 0, width: DAOnboardingViewController.ActionButtonCircleSize / 2, height: DAOnboardingViewController.ActionButtonCircleSize / 2))
    private let actionButtonEventShape = UIButton()
    
    private lazy var pages: [UIViewController] = [createViewController, sendViewController, receiveViewController]
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        addSubviews()
        addConstraints()
        
        setEvents()
        setStyle()
        
        pageViewController.setViewControllers([createViewController], direction: UIPageViewController.NavigationDirection.forward, animated: true, completion: nil)
    }
    
    private func addSubviews() {
        // action button (placed intentionally behind the pageviewcontroller)
        view.addSubview(actionButtonBackgroundCircle)
        view.addSubview(actionButton)
        
        // add the page view controller
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
    
        // this shape receives the tap events
        view.addSubview(actionButtonEventShape)
        
        // header with close button and title
        view.addSubview(header)
    }
    
    private func addConstraints() {
        header.constrain([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: E.isIPhoneXOrGreater ? 50.0 : 20.0),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: C.Sizes.headerHeight)
        ])
        
        pageViewController.view.constrain([
            pageViewController.view.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 0),
            pageViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            pageViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        actionButtonBackgroundCircle.constrain([
            actionButtonBackgroundCircle.rightAnchor.constraint(equalTo: view.rightAnchor, constant: DAOnboardingViewController.ActionButtonCircleSize / 2),
            actionButtonBackgroundCircle.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: DAOnboardingViewController.ActionButtonCircleSize / 2),
            actionButtonBackgroundCircle.widthAnchor.constraint(equalToConstant: DAOnboardingViewController.ActionButtonCircleSize),
            actionButtonBackgroundCircle.heightAnchor.constraint(equalToConstant: DAOnboardingViewController.ActionButtonCircleSize)
        ])
        
        actionButton.constrain([
            actionButton.topAnchor.constraint(equalTo: actionButtonBackgroundCircle.topAnchor, constant: 50),
            actionButton.leftAnchor.constraint(equalTo: actionButtonBackgroundCircle.leftAnchor, constant: 50),
        ])
        
        actionButtonEventShape.constrain([
            actionButtonEventShape.topAnchor.constraint(equalTo: actionButtonBackgroundCircle.topAnchor),
            actionButtonEventShape.leftAnchor.constraint(equalTo: actionButtonBackgroundCircle.leftAnchor),
            actionButtonEventShape.widthAnchor.constraint(equalToConstant: DAOnboardingViewController.ActionButtonCircleSize),
            actionButtonEventShape.heightAnchor.constraint(equalToConstant: DAOnboardingViewController.ActionButtonCircleSize)
        ])
    }
    
    private func setEvents() {
        pageViewController.delegate = self
        pageViewController.dataSource = self
        
        header.closeCallback = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        
        actionButtonEventShape.tap = { [unowned self] in
            if let idx = self.pages.firstIndex(of: self.pageViewController.viewControllers![0]) {
                if idx < self.pages.count - 1 {
                    let nextPage = self.pages[idx+1]
                    self.pageViewController.setViewControllers([nextPage], direction: UIPageViewController.NavigationDirection.forward, animated: true, completion: nil)
                } else {
                    // last page
                    self.navigationController?.pushViewController(self.nextVC, animated: true)
                }
            }
        }
    }
    
    private func setStyle() {
        // 23233c
        view.backgroundColor = UIColor(red: 0x23 / 255, green: 0x23 / 255, blue: 0x3c / 255, alpha: 1.0)
        
        // 292944
        actionButtonBackgroundCircle.backgroundColor = UIColor(red: 0x29 / 255, green: 0x29 / 255, blue: 0x44 / 255, alpha: 1.0)
        actionButtonBackgroundCircle.layer.cornerRadius = DAOnboardingViewController.ActionButtonCircleSize / 2
        actionButtonBackgroundCircle.layer.masksToBounds = true
        actionButton.image = UIImage(named: "da-onboarding-arrow-right") // initial
        
        actionButtonEventShape.frame = actionButtonBackgroundCircle.frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setEvents()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UserDefaults.digiAssetsOnboardingShown = true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension DAOnboardingViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let idx = pages.firstIndex(of: viewController) {
            if idx != 0 {
                return pages[idx - 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let idx = pages.firstIndex(of: viewController) {
            if idx < pages.count - 1 {
                return pages[idx + 1]
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let vcs = pageViewController.viewControllers {
            if var idx = self.pages.firstIndex(of: vcs[0]) {
                idx = { idx }()
//                pageControl.currentPage = idx
//                updateNextButtonTitle(idx: idx)
            }
        }
    }
    
}
