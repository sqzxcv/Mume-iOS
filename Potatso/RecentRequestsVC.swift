//
//  RecentRequestsViewController.swift
//  Potatso
//
//  Created by LEI on 4/19/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel
import RealmSwift
import PotatsoLibrary
import PotatsoBase
import SVPullToRefresh

private let kRecentRequestCellIdentifier = "recentRequests"
private let kRecentRequestCachedIdentifier = "requestsCached"

class RecentRequestsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var requests: [Request] = []
    let wormhole = Manager.shared.wormhole
    var timer: Timer?
    var appear = false
    var stopped = false
    var showingCache = false
    
    deinit {
        tableView.showsPullToRefresh = false
        wormhole.stopListeningForMessage(withIdentifier: "tunnelConnectionRecords")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        self.tableView.dataSource = self
        self.tableView.delegate = self

        super.viewDidLoad()
        navigationItem.title = "Recent Requests".localized()
        NotificationCenter.default.addObserver(self, selector: #selector(onVPNStatusChanged), name: NSNotification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        wormhole.listenForMessage(withIdentifier: "tunnelConnectionRecords") { [unowned self](response) in
            self.tableView.pullToRefreshView?.stopAnimating()
            self.updateUI(response as? String)
            Potatso.sharedUserDefaults().set(response as? String, forKey: kRecentRequestCachedIdentifier)
            Potatso.sharedUserDefaults().synchronize()
            return
        }
        self.updateUI(Potatso.sharedUserDefaults().string(forKey: kRecentRequestCachedIdentifier))
        if Manager.shared.vpnStatus == .off {
            showingCache = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear = true
        onVPNStatusChanged()
        tableView.addPullToRefresh( actionHandler: { [weak self] in
            self?.refresh()
            })
        tableView.triggerPullToRefresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.showsPullToRefresh = false
    }
    
    func refresh() {
        let on = [VPNStatus.on, VPNStatus.connecting].contains(Manager.shared.vpnStatus)
        if on {
            wormhole.passMessageObject(NSString(), identifier: "getTunnelConnectionRecords")
        } else {
            self.tableView.pullToRefreshView?.stopAnimating()
            tableView.showsPullToRefresh = false;
        }
    }
    
    func updateUI(_ requestString: String?) {
        if let responseStr = requestString, let jsonArray = responseStr.jsonArray() {
            self.requests = jsonArray.reversed().filter({ ($0 as? [String : AnyObject]) != nil }).flatMap({ Request(dict: $0 as! [String : AnyObject]) })
        }else {
            self.requests = []
        }
        tableView.reloadData()
    }
    
    @objc func onVPNStatusChanged() {
        let on = [VPNStatus.on, VPNStatus.connecting].contains(Manager.shared.vpnStatus)
        hintLabel.isHidden = on
        if on && showingCache {
            updateUI(nil)
        }
        showingCache = !on
    }
    
    // MARK: - TableView DataSource & Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        emptyView.isHidden = requests.count > 0
        return requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kRecentRequestCellIdentifier, for: indexPath) as! RecentRequestsCell
        cell.config(requests[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(RequestDetailVC(request: requests[indexPath.row]), animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        view.addSubview(tableView)
        view.addSubview(emptyView)
        view.addSubview(hintLabel)
        tableView.register(RecentRequestsCell.self, forCellReuseIdentifier: kRecentRequestCellIdentifier)
        setupLayout()
    }
    
    func setupLayout() {
        constrain(tableView, view) { tableView, view in
            tableView.edges == view.edges
        }
        constrain(hintLabel, emptyView, view) { hintLabel, emptyView, view in
            hintLabel.leading == view.leading
            hintLabel.trailing == view.trailing
            hintLabel.bottom == view.bottom
            hintLabel.height == 35
            
            emptyView.edges == view.edges
        }
    }
    
    var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .plain)
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .singleLine
        v.estimatedRowHeight = 70
        v.rowHeight = UITableView.automaticDimension
        return v
    }()
    
    lazy var emptyView: BaseEmptyView = {
        let v = BaseEmptyView()
        v.title = "You should manually refresh to see the request log.".localized()
        return v
    }()
    
    lazy var hintLabel: UILabel = {
        let v = UILabel()
        v.text = "Mume is not connected".localized()
        v.textColor = UIColor.white
        v.backgroundColor = "E74C3C".color
        v.textAlignment = .center
        v.font = UIFont.systemFont(ofSize: 14)
        v.alpha = 0.8
        v.isHidden = true
        return v
    }()
    
}
