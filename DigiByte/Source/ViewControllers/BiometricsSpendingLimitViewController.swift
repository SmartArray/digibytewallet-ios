//
//  BiometricsSpendingLimitViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

class BiometricsSpendingLimitViewController: UITableViewController, Subscriber {

    private let cellIdentifier = "CellIdentifier"
    private let store: BRStore
    private let walletManager: WalletManager
    private let limits: [UInt64] = [0, 10000000, 100000000, 1000000000, 10000000000, 100000000000, 1000000000000]
    private var selectedLimit: UInt64?
    private var header: UIView?
    private let amount = UILabel(font: .customMedium(size: 26.0), color: .white)
    private let body = UILabel.wrapping(font: .customBody(size: 13.0), color: C.Colors.lightText)
    
    init(walletManager: WalletManager, store: BRStore) {
        self.walletManager = walletManager
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 50.0
        } else {
            return 0
        }
    }

    override func viewDidLoad() {
        view.layer.masksToBounds = true
        view.backgroundColor = C.Colors.background
    
        selectedLimit = walletManager.spendingLimit
        
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.backgroundColor = C.Colors.background
        tableView.separatorStyle = .none

        let titleLabel = UILabel(font: .customMedium(size: 17.0), color: .white)
        let biometricsTitle = LAContext.biometricType() == .face ? S.FaceIdSpendingLimit.title : S.TouchIdSpendingLimit.title
        titleLabel.text = biometricsTitle
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        navigationController?.navigationBar.backgroundColor = C.Colors.background

        // TODO: Writeup support/FAQ documentation for digibyte wallet
        /*let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.touchIdSpendingLimit)
        faqButton.tintColor = .darkText
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]*/

        body.text = S.TouchIdSpendingLimit.body
        body.backgroundColor = C.Colors.background

        //If the user has a limit that is not a current option, we display their limit
        if !limits.contains(walletManager.spendingLimit) {
            if let rate = store.state.currentRate {
                let spendingLimit = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: store.state.maxDigits)
                setAmount(limitAmount: spendingLimit)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return limits.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.textColor = C.Colors.text
        cell.backgroundColor = C.Colors.background
        
        // predefined touch id spending limits
        if indexPath.section == 0 {
            let limit = limits[indexPath.row]
            if limit == 0 {
                cell.textLabel?.text = S.TouchIdSpendingLimit.requirePasscode
            } else {
                let displayAmount = DisplayAmount(amount: Satoshis(rawValue: limit), state: store.state, selectedRate: nil, minimumFractionDigits: 0)
                cell.textLabel?.text = displayAmount.combinedDescription
            }
            
            if limits[indexPath.row] == selectedLimit {
                let check = UIImageView(image: UIImage(named: "CircleCheck")?.withRenderingMode(.alwaysTemplate))
                check.tintColor = .orange
                cell.accessoryView = check
            } else {
                cell.accessoryView = nil
            }
            
        // Custom spending limit
        } else if indexPath.section == 1 {
            // ToDo: Export these strings
            let custom = S.TouchIdSpendingLimit.custom
            
            // If selectedLimit is not in limits, we assume a custom limit was entered.
            // In that case we will display the custom limit as a preview in this specific cell
            if let limit = selectedLimit, !limits.contains(limit) {
                let check = UIImageView(image: UIImage(named: "CircleCheck")?.withRenderingMode(.alwaysTemplate))
                check.tintColor = .orange
                cell.accessoryView = check
                
                // Preview of custom amount
                let displayAmount = DisplayAmount(amount: Satoshis(rawValue: limit), state: store.state, selectedRate: nil, minimumFractionDigits: 0)
                cell.textLabel?.text = "\(custom): \(displayAmount.combinedDescription)"
            } else {
                // No custom amount was entered
                cell.textLabel?.text = "\(custom) ..."
                cell.accessoryView = nil
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let newLimit = limits[indexPath.row]
            selectedLimit = newLimit
            walletManager.spendingLimit = newLimit
            amount.isHidden = true
            amount.constrain([
                amount.heightAnchor.constraint(equalToConstant: 0.0) ])
            tableView.reloadData()
        } else {
            let alert = AlertController(title: S.TouchIdSpendingLimit.customAmount, message: S.TouchIdSpendingLimit.customAmountDescription, preferredStyle: .alert)
            
            alert.addTextField { [unowned self] (textField) in
                if let current = self.selectedLimit, !self.limits.contains(current) {
                    // display the custom amount if there is one
                    let dgb = current / 100000000
                    textField.text = "\(dgb)"
                } else {
                    // otherwise display default max
                    textField.text = "10000"
                }
            }
            
            alert.addAction(AlertAction(title: S.Button.ok, style: .default, handler: { [unowned alert, unowned self] (_) in
            alert.addAction(AlertAction(title: "OK", style: .default, handler: { [unowned alert, unowned self] (_) in
                let textField = alert.textFields![0]
                guard let text = textField.text else { return }
                
                // try to parse user input
                if let dgb = UInt64(text) {
                    // convert input to internal satoshi format
                    let satoshis = dgb * 100000000
                    
                    // update app data
                    self.selectedLimit = satoshis
                    self.walletManager.spendingLimit = satoshis
                    self.amount.isHidden = true
                    self.amount.constrain([
                        self.amount.heightAnchor.constraint(equalToConstant: 0.0)
                    ])
                    
                    // reload
                    self.tableView.reloadData()
                }
            }))
            
            alert.addAction(AlertAction(title: S.Button.cancel, style: .cancel, handler: { _ in
            alert.addAction(AlertAction(title: "Cancel", style: .cancel, handler: { _ in
                //
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // the bottom section won't have any headers, it's just to control the program flow
        if section == 1 {
            return UIView()
        }
        
        // for upper section we will display a description
        if let header = self.header { return header }
        let header = UIView(color: C.Colors.background)
        header.addSubview(amount)
        header.addSubview(body)
        amount.pinTopLeft(padding: C.padding[2])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: amount.leadingAnchor),
            body.topAnchor.constraint(equalTo: amount.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -C.padding[2]),
            body.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -C.padding[2]) ])
        self.header = header
        return header
    }

    private func setAmount(limitAmount: Amount) {
        amount.text = ""
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
