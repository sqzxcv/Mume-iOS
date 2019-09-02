//
//  HomePresenter.swift
//  Potatso
//
//  Created by LEI on 6/22/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Async

protocol HomePresenterProtocol: class {
    func handleRefreshUI(_ error: Error?)
}

class HomePresenter: NSObject {

    static var kAddConfigGroup = "AddConfigGroup"
    static var errorCnt = 0
    var configError = 0
    var vc: UIViewController!

    var group: ConfigurationGroup {
        return CurrentGroupManager.shared.group
    }

    var proxy: Proxy? {
        return group.proxies.first
    }

    weak var delegate: HomePresenterProtocol?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onVPNStatusChanged), name: NSNotification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showAddConfigGroup), name: NSNotification.Name(rawValue: HomePresenter.kAddConfigGroup), object: nil)
        CurrentGroupManager.shared.onChange = { group in
            self.delegate?.handleRefreshUI(nil)
        }
        try? Manager.shared.regenerateConfigFiles()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func bindToVC(_ vc: UIViewController) {
        self.vc = vc
    }

    // MARK: - Actions

    func switchVPN() {
        if self.configError > 0 {
            do {
                try Manager.shared.regenerateConfigFiles()
                self.configError = 0
            } catch {
                print("switchVPN failed: ", error)
                self.configError += 1
                return
            }
        }
        VPN.switchVPN(group) { [unowned self] (error) in
            if let error = error as NSError? {
                HomePresenter.errorCnt += 1
                self.delegate?.handleRefreshUI(error)
                // https://forums.developer.apple.com/thread/25928
                if error.code == 1, HomePresenter.errorCnt == 1 {
                    NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServicePermissionChanged), object: nil)
                    return
                }
                Alert.show(self.vc, message: "\("Fail to switch VPN.".localized()) (\(error))")
            }
        }
    }

    func change(proxy: Proxy, status: VPNStatus) -> Bool {
        if (proxy.uuid == self.proxy?.uuid) {
            print("HomePresenter.change(proxy): not changed");
            return false
        }
        try? DBUtils.modify(ConfigurationGroup.self, id: self.group.uuid) { (realm, group) -> Error? in
            group.proxies.removeAll()
            group.proxies.append(proxy)
            return nil
        }
        
        // apply changes
        do {
            try Manager.shared.generateShadowsocksConfig()
            self.restartVPN()
            return true
        } catch {
            print(error)
            self.configError += 1
            return false
        }
    }
    
    func restartVPN() {
        guard Manager.shared.stopVPN() else {
            return
        }
        Async.main(after: 1) {
            Manager.shared.switchVPN { (manager, error) in
                if let _ = manager {
                    Async.background(after: 2, { () -> Void in
                        Appirater.userDidSignificantEvent(false)
                    })
                }
            }
        }
    }
    
    @objc func chooseConfigGroups() {
        ConfigGroupChooseManager.shared.show()
    }

    @objc func showAddConfigGroup() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Add Config Group".localized(), message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Name".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { (action) in
            if let input = urlTextField?.text {
                do {
                    try self.addEmptyConfigGroup(input)
                }catch{
                    Alert.show(self.vc, message: "\("Failed to add config group".localized()): \(error)")
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }

    func addEmptyConfigGroup(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmedName.characters.count == 0 {
            throw "Name can't be empty".localized()
        }
        let group = ConfigurationGroup()
        group.name = trimmedName
        try DBUtils.add(group)
        CurrentGroupManager.shared.setConfigGroupId(group.uuid)
    }

    func addRuleSet(existing: [String]) {
        let destVC: UIViewController
        if defaultRealm.objects(RuleSet.self).count <= existing.count {
            destVC = RuleSetConfigurationViewController() { [unowned self] ruleSet in
                self.appendRuleSet(ruleSet)
            }
        } else {
            destVC = RuleSetListViewController(existing: existing) { [unowned self] ruleSet in
                self.appendRuleSet(ruleSet)
            }
        }
        vc.navigationController?.pushViewController(destVC, animated: true)
    }

    func appendRuleSet(_ ruleSet: RuleSet?) {
        guard let ruleSet = ruleSet, !group.ruleSets.contains(ruleSet) else {
            return
        }
        do {
            try ConfigurationGroup.appendRuleSet(forGroupId: group.uuid, rulesetId: ruleSet.uuid)
            Manager.shared.setDefaultConfigGroup(group.uuid, name: group.name)
            self.delegate?.handleRefreshUI(nil)
            restartVPN()
        } catch {
            self.configError += 1
            self.vc.showTextHUD("\("Fail to add ruleset".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
        }
    }

    func updateDNS(_ dnsString: String) {
        var dns: String = ""
        let trimmedDNSString = dnsString.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmedDNSString.characters.count > 0 {
            let dnsArray = dnsString.components(separatedBy: ",").map({ $0.components(separatedBy: "，") }).flatMap({ $0 }).map({ $0.trimmingCharacters(in: CharacterSet.whitespaces)}).filter({ $0.characters.count > 0 })
            let ipRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
            guard let regex = try? Regex(ipRegex) else {
                fatalError()
            }
            let valids = dnsArray.map({ regex.test($0) })
            let valid = valids.reduce(true, { $0 && $1 })
            if !valid {
                dns = ""
                Alert.show(self.vc, title: "Invalid DNS".localized(), message: "DNS should be valid ip addresses (separated by commas if multiple). e.g.: 8.8.8.8,8.8.4.4".localized())
            }else {
                dns = dnsArray.joined(separator: ",")
            }
        }
        do {
            try ConfigurationGroup.changeDNS(forGroupId: group.uuid, dns: dns)
            self.configError += 1
        }catch {
            self.vc.showTextHUD("\("Fail to change dns".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
        }
    }

    @objc func onVPNStatusChanged() {
        self.delegate?.handleRefreshUI(nil)
    }

    func changeGroupName() {
        var urlTextField: UITextField?
        let alert = UIAlertController(title: "Change Name".localized(), message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Input New Name".localized()
            urlTextField = textField
        }
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: { [unowned self] (action) in
            if let newName = urlTextField?.text {
                do {
                    try ConfigurationGroup.changeName(forGroupId: self.group.uuid, name: newName)
                }catch {
                    Alert.show(self.vc, title: "Failed to change name", message: "\(error)")
                }
                self.delegate?.handleRefreshUI(nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "CANCEL".localized(), style: .cancel, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }

}

class CurrentGroupManager {

    static let shared = CurrentGroupManager()

    fileprivate init() {
        _groupUUID = Manager.shared.defaultConfigGroup.uuid
    }

    var onChange: ((ConfigurationGroup?) -> Void)?

    fileprivate var _groupUUID: String {
        didSet(o) {
            self.onChange?(group)
        }
    }

    var group: ConfigurationGroup {
        if let group = DBUtils.get(_groupUUID, type: ConfigurationGroup.self) {
            return group
        } else {
            let defaultGroup = Manager.shared.defaultConfigGroup
            setConfigGroupId(defaultGroup.uuid)
            return defaultGroup
        }
    }

    func setConfigGroupId(_ id: String) {
        if let _ = DBUtils.get(id, type: ConfigurationGroup.self) {
            _groupUUID = id
        } else {
            _groupUUID = Manager.shared.defaultConfigGroup.uuid
        }
    }
    
}
