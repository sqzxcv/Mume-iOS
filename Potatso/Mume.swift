//
//  Mume.swift
//  Potatso
//
//  Created by Ruqi on 7/8/2017.
//  Copyright © 2017 TouchingApp. All rights reserved.
//

import Foundation

class Mume {
    static let xAppSharedGroupIdentifier = "group.com.nina.mtfly2"
    
    static func sharedUserDefaults() -> UserDefaults? {
        return UserDefaults(suiteName: xAppSharedGroupIdentifier)
    }
}
