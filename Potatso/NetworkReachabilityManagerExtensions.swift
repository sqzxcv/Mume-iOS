//
//  NetworkReachabilityManagerExtensions.swift
//  Potatso
//
//  Created by 盛强 on 2019/9/2.
//  Copyright © 2019 TouchingApp. All rights reserved.
//

import Foundation
import Alamofire

extension NetworkReachabilityManager {
    
    static func networkStatusName(manager: NetworkReachabilityManager?) -> String {
        if let ma = manager {
            switch ma.networkReachabilityStatus {
            case NetworkReachabilityManager.NetworkReachabilityStatus.notReachable:
                return "notReachable"
            case NetworkReachabilityManager.NetworkReachabilityStatus.unknown:
                return "unknown"
            default:
                if (ma.isReachableOnWWAN) {
                    return "reachableOnWWAN"
                } else if (ma.isReachableOnEthernetOrWiFi) {
                    return "reachableOnEthernetOrWiFi"
                } else {
                    return ""
                }
            }
        } else {
            return ""
        }
    }
}
