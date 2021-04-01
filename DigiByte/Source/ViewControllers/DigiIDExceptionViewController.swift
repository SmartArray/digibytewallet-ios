//
//  DigiIDExceptionViewController.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 21.07.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit

fileprivate class FaqButton: UIButton {
    override var alignmentRectInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 16)
    }
}

class DigiIDExceptionViewController: UITableViewController {
    var presentScan: PresentDigiIdScan!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "siteCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "addCell")
        tableView.backgroundColor = C.Colors.background
        tableView.separatorColor = C.Colors.blueGrey
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        let positiveSeparator = UIBarButtonItem(barButtonSystemItem:.fixedSpace, target: nil, action: nil)
        positiveSeparator.width = 16
        
        let faqbtn = FaqButton(type: .system)
        
        faqbtn.setImage(UIImage(named: "Faq"), for: .normal)
        
        faqbtn.widthAnchor.constraint(equalToConstant: 24).isActive = true
        faqbtn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        faqbtn.translatesAutoresizingMaskIntoConstraints = false
        faqbtn.addTarget(self, action: #selector(self.digiIDLegacyHelpTapped), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: faqbtn)
    }
    
    
    @objc
    private func digiIDLegacyHelpTapped() {
        showAlert(title: S.Settings.digiIdLegacyTitle, message: S.Settings.digiIdLegacyDescription, buttonLabel: S.Alerts.defaultConfirmOkCaption)
    }

    @objc
    private func addSite() {
        presentScan({ [weak self] digiIdRequest in
            guard let request = digiIdRequest else { return }
            let url = URL(string: request.signString)
            
            if let host = url?.host {
                DigiIDLegacySites.default.sites.append(host)
                DigiIDLegacySites.default.save()
                self?.tableView.reloadData()
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? DigiIDLegacySites.default.sites.count : 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "siteCell")!
            cell.textLabel?.text = DigiIDLegacySites.default.sites[indexPath.row]
            cell.backgroundColor = UIColor.clear
            cell.textLabel?.textColor = C.Colors.lightText
            cell.selectionStyle = .none
            return cell
        }
        
        // add button
        let cell = tableView.dequeueReusableCell(withIdentifier: "addCell")!
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = C.Colors.lightGrey
        let str = S.Settings.addException
        cell.textLabel?.text = "+ \(str)"
        cell.backgroundColor = UIColor.clear
        cell.selectionStyle = .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            addSite()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if indexPath.section == 0 {
            return UITableViewCell.EditingStyle.delete
        }
        
        return UITableViewCell.EditingStyle.none
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            DigiIDLegacySites.default.sites.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
            DigiIDLegacySites.default.save()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DigiIDLegacySites.default.save()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
