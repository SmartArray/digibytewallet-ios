//
//  UIViewController+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIViewController {
    func addChildViewController(_ viewController: UIViewController, layout: () -> Void) {
        addChild(viewController)
        view.addSubview(viewController.view)
        layout()
        viewController.didMove(toParent: self)
    }

    func remove() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }

    func addCloseNavigationItem(tintColor: UIColor? = nil) {
        let close = UIButton.close
        close.tap = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        if let color = tintColor {
            close.tintColor = color
        }
    
        let negativeSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativeSpacer.width = -5

        navigationItem.leftBarButtonItems = [negativeSpacer, UIBarButtonItem(customView: close)]
    }
    
    
    func showAlert(with message: String, color: UIColor? = nil) {
        let alert = LightWeightAlert(message: message)
        
        if let color = color {
            alert.container.backgroundColor = color
        }
        
        view.addSubview(alert)
        
        alert.constrain([
            alert.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alert.centerYAnchor.constraint(equalTo: view.centerYAnchor) ])
        alert.alpha = 0
        
        UIView.animate(withDuration: 0.6, animations: {
            alert.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.6, delay: 2.0, options: [], animations: {
                alert.alpha = 0
            }, completion: { _ in
                alert.removeFromSuperview()
            })
        })
    }
    
    func showError(with message: String) {
        showAlert(with: message, color: UIColor.da.burnColor)
    }
    
    func showSuccess(with message: String) {
        showAlert(with: message, color: C.Colors.weirdGreen)
    }
}
