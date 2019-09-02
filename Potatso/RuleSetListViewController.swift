//
//  RuleSetListViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import PotatsoModel
import Cartography
import Realm
import RealmSwift

private let rowHeight: CGFloat = 54
private let kRuleSetCellIdentifier = "ruleset"

class RuleSetListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var ruleSets: Results<RuleSet>
    var existingRules: [String] = []
    var chooseCallback: ((RuleSet?) -> Void)?
    // Observe Realm Notifications
    var heightAtIndex: [Int: CGFloat] = [:]
    fileprivate let pageSize = 20
    
    convenience init() {
        self.init(existing: [])
    }
    
    init(existing: [String], chooseCallback: ((RuleSet?) -> Void)? = nil) {
        self.chooseCallback = chooseCallback
        self.existingRules = existing
        self.ruleSets = DBUtils.all(RuleSet.self, filter: "uuid = ''", sorted: "createAt")
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadData() {
        API.getRuleSets() { (result) in
            self.tableView.pullToRefreshView?.stopAnimating()
            
            guard result.count > 0 else {
                return
            }
            for rule in result {
                do {
                    if rule.name.characters.count > 0 {
                        try RuleSet.addRemoteObject(rule)
                    } else {
                        try DBUtils.hardDelete(rule.uuid, type: RuleSet.self)
                    }
                } catch {
                    NSLog("Fail to subscribe".localized())
                }
            }
            self.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Rule Set".localized()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        reloadData()
        
        self.tableView.addPullToRefresh( actionHandler: { [weak self] in
            self?.loadData()
            })
        if self.ruleSets.count == 0 {
            tableView.triggerPullToRefresh()
        }
    }

    func reloadData() {
        let cond = self.existingRules.map{ "uuid != '\($0)'" }.joined(separator: " && ")
        self.ruleSets = DBUtils.all(RuleSet.self, filter: cond, sorted: "createAt")
        tableView.reloadData()
    }

    @objc func add() {
        let vc = RuleSetConfigurationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    func showRuleSetConfiguration(_ ruleSet: RuleSet?) {
        let vc = RuleSetConfigurationViewController(ruleSet: ruleSet)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ruleSets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kRuleSetCellIdentifier, for: indexPath) as! RuleSetCell
        heightAtIndex[indexPath.row] = cell.setRuleSet(ruleSets[indexPath.row])
        return cell
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let ruleSet = ruleSets[indexPath.row]
        if let cb = chooseCallback {
            cb(ruleSet)
            close()
        }else {
            showRuleSetConfiguration(ruleSet)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let h = RuleSetCell.caculateRSCellLayoutHeight(ruleSet: ruleSets[indexPath.row])
        if let height = heightAtIndex[indexPath.row] {
            print("Caculated: %lf real: %lf".localizedFormat(Double(h), Double(height)))
        }
        return h
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return chooseCallback == nil
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let item = ruleSets[indexPath.row]
        if item.isOfficial {
            return .none
        }
        return .delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = ruleSets[indexPath.row]
            do {
                try DBUtils.hardDelete(item.uuid, type: RuleSet.self)
                self.reloadData()
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clear
        view.addSubview(tableView)
        tableView.register(RuleSetCell.self, forCellReuseIdentifier: kRuleSetCellIdentifier)

        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.separatorStyle = .singleLine
        v.rowHeight = UITableView.automaticDimension
        return v
    }()

}
