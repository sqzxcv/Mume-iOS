//
//  Proxy.swift
//  Potatso
//
//  Created by LEI on 4/6/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import RealmSwift
import CloudKit

public let kProxyServiceAdded = "kProxyServiceAdded"

public enum ProxyType: String {
    case Shadowsocks = "Shadowsocks"
    case ShadowsocksR = "ShadowsocksR"
    //case Https = "HTTPS"
    case Socks5 = "SOCKS5"
}

extension ProxyType: CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }

    public var isShadowsocks: Bool {
        return self == .Shadowsocks || self == .ShadowsocksR
    }
    
}

public enum ProxyError: Error {
    case invalidType
    case invalidName
    case invalidHost
    case invalidPort
    case invalidAuthScheme
    case nameAlreadyExists
    case invalidUri
    case invalidPassword
}

extension ProxyError: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .invalidType:
            return "Invalid type"
        case .invalidName:
            return "Invalid name"
        case .invalidHost:
            return "Invalid host"
        case .invalidAuthScheme:
            return "Invalid encryption"
        case .invalidUri:
            return "Invalid uri"
        case .nameAlreadyExists:
            return "Name already exists"
        case .invalidPassword:
            return "Invalid password"
        case .invalidPort:
            return "Invalid port"
        }
    }
    
}

open class Proxy: BaseModel {
    @objc open dynamic var typeRaw = ProxyType.Shadowsocks.rawValue
    @objc open dynamic var host = ""
    @objc open dynamic var port = 0
    @objc open dynamic var ip: String?
    @objc open dynamic var authscheme: String?  // method in SS
    @objc open dynamic var user: String?
    @objc open dynamic var password: String?
    @objc open dynamic var ota: Bool = false
    @objc open dynamic var ssrProtocol: String?
    @objc open dynamic var ssrObfs: String?
    @objc open dynamic var ssrObfsParam: String?

    open static let ssUriMethod = "ss"
    open static let ssrUriMethod = "ssr"

    open static let ssrSupportedProtocol = [
        "origin",
        "verify_simple",
        "auth_simple",
        "auth_sha1",
        "auth_sha1_v2"
    ]

    open static let ssrSupportedObfs = [
        "plain",
        "http_simple",
        "tls1.0_session_auth",
        "tls1.2_ticket_auth"
    ]

    open static let ssSupportedEncryption = [
        "table",
        "rc4",
        "rc4-md5",
        "aes-128-cfb",
        "aes-192-cfb",
        "aes-256-cfb",
        "bf-cfb",
        "camellia-128-cfb",
        "camellia-192-cfb",
        "camellia-256-cfb",
        "cast5-cfb",
        "des-cfb",
        "idea-cfb",
        "rc2-cfb",
        "seed-cfb",
        "salsa20",
        "chacha20",
        "chacha20-ietf"
    ]

    open override static func indexedProperties() -> [String] {
        return ["host","port"]
    }

    open override func validate() throws {
        guard let _ = ProxyType(rawValue: typeRaw)else {
            throw ProxyError.invalidType
        }
        guard host.characters.count > 0 else {
            throw ProxyError.invalidHost
        }
        guard port > 0 && port <= Int(UINT16_MAX) else {
            throw ProxyError.invalidPort
        }
        switch type {
        case .Shadowsocks, .ShadowsocksR:
            guard let _ = authscheme else {
                throw ProxyError.invalidAuthScheme
            }
        default:
            break
        }
    }
    
    open override var description: String {
        return String.init(format: "%@:%d", host, port)
    }
    
    open func shareUri() -> String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme,
                let password = password,
                let ss = "\(authscheme):\(password)@\(host):\(port)".data(using: .ascii)
            {
                return "https://mumevpn.com/ss.php?s=" + ss.base64EncodedString()
            }
            return ""
        
        case .Socks5:
            if let ss = "\(host):\(port)".data(using: .ascii) {
                return "https://mumevpn.com/socks5.php?s=" + ss.base64EncodedString()
            }
            return ""
            
        default:
            return ""
        }
    }
    
    public static func delete(proxy: Proxy) {
        let proxies = DBUtils.all(Proxy.self, sorted: "createAt").map({ $0 })
        for ep in proxies {
            if ep.host == proxy.host,
                ep.port == proxy.port {
                print ("Remove existing: " + proxy.description)
                try? DBUtils.hardDelete(ep.uuid, type: Proxy.self)
            }
        }
    }
    
    public static func insertOrUpdate(proxy: Proxy) -> Bool {
        do {
            try proxy.validate()
            self.delete(proxy: proxy)
            try DBUtils.add(proxy)
            NotificationCenter.default.post(name: Foundation.Notification.Name(rawValue: kProxyServiceAdded), object: nil)
            return true
        } catch {
            let errorDesc = "(\(error))"
            print ("\("Fail to save config.".localized()) \(errorDesc)")
        }
        return false
    }
}

// Public Accessor
extension Proxy {
    
    public var type: ProxyType {
        get {
            return ProxyType(rawValue: typeRaw) ?? .Shadowsocks
        }
        set(v) {
            typeRaw = v.rawValue
        }
    }
    
    public var uri: String {
        switch type {
        case .Shadowsocks:
            if let authscheme = authscheme, let password = password {
                return "ss://\(authscheme):\(password)@\(host):\(port)"
            }
        case .Socks5:
            if let user = user, let password = password {
                return "socks5://\(user):\(password)@\(host):\(port)"
            }
            return "socks5://\(host):\(port)" // TODO: support username/password
        default:
            break
        }
        return ""
    }
    
}

// Import
extension Proxy {
    public convenience init(string: String) throws {
        if let rawUri = URL(string: string) {
            try self.init(url: rawUri)
        } else {
            throw ProxyError.invalidUri
        }
    }
    
    public convenience init(url rawUri: URL) throws {
        self.init()
        let s = rawUri.scheme?.lowercased() ?? (rawUri.user == nil ? "socks5" : "shadowsocks")
            if let fragment = rawUri.fragment, fragment.characters.count == 36 {
                self.uuid = fragment
            }
            
            if s == "socks5" || s == "socks" {
                guard let host = rawUri.host else {
                    throw ProxyError.invalidUri
                }
                self.type = .Socks5
                self.host = host
                self.port = rawUri.port ?? 1080
                return
            }
            
            // mume://method:base64(password)@hostname:port
            if s == "mume" || s == "shadowsocks" {
                guard let fullAuthscheme = rawUri.user?.lowercased(),
                    let host = rawUri.host,
                    let port = rawUri.port else {
                        throw ProxyError.invalidUri
                }
                
                if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                    self.authscheme = fullAuthscheme.substring(to: pOTA)
                    self.ota = true
                } else {
                    self.authscheme = fullAuthscheme
                }
                self.password = base64DecodeIfNeeded((rawUri.password ?? "").removingPercentEncoding ?? "")
                self.host = host
                self.port = Int(port)
                self.type = .Shadowsocks
                return
            }
            
            // Shadowsocks ss://cmM0LW1kNTp4aWFtaS5sYUBjbjEuc3hpYW1pLmNvbTo0NTQwMg==
            guard let undecodedString = rawUri.host else {
                throw ProxyError.invalidUri
            }
            self.type = .Shadowsocks

            // SIP002 Spec
            if let b64MP = rawUri.user,
                rawUri.password == nil,
                let host = rawUri.host,
                let port = rawUri.port {
                let MP = base64DecodeIfNeeded(b64MP)
                self.host = host
                self.port = port
                let comps = MP.components(separatedBy: ":")
                if comps.count > 1 {
                    self.authscheme = comps[0].localized()
                    self.password = comps[1..<comps.count].joined(separator: ":")
                    return
                }
            }
        
            let proxyString = base64DecodeIfNeeded(undecodedString)
            let detailsParser = "([a-zA-Z0-9-_]+):(.*)@([a-zA-Z0-9-_.]+):(\\d+)"
            if let regex = try? Regex(detailsParser),
                regex.test(proxyString),
                let parts = regex.capturedGroup(string: proxyString),
                parts.count >= 4 {
                let fullAuthscheme = parts[0].lowercased()
                if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                    self.authscheme = fullAuthscheme.substring(to: pOTA)
                    self.ota = true
                } else {
                    self.authscheme = fullAuthscheme
                    self.ota = false
                }
                self.password = parts[1]
                self.host = parts[2]
                self.port = Int(parts[3]) ?? 8388
                return
            }
            
            if let httpsURL = URL(string: "https://" + proxyString),
                let fullAuthscheme = httpsURL.user?.lowercased(),
                let host = httpsURL.host,
                let port = httpsURL.port {
        
                if let pOTA = fullAuthscheme.range(of: "-auth", options: .backwards)?.lowerBound {
                    self.authscheme = fullAuthscheme.substring(to: pOTA)
                    self.ota = true
                }else {
                    self.authscheme = fullAuthscheme
                }
                self.password = httpsURL.password
                self.host = host
                self.port = Int(port)
                self.type = .Shadowsocks
                if s == Proxy.ssUriMethod {
                    return
                }
            }
    
            if s == Proxy.ssrUriMethod || s.hasPrefix("shadowsocksr") {
                var hostString: String = proxyString
                var queryString = ""
                if let queryMarkRange = proxyString.range(of: "?", options: .backwards) {
                    hostString = proxyString.substring(to: queryMarkRange.lowerBound)
                    queryString = proxyString.substring(from: queryMarkRange.upperBound)
                }
                if let hostSlashIndex = hostString.range(of: "/", options: .backwards)?.lowerBound {
                    hostString = hostString.substring(to: hostSlashIndex)
                }
                let hostComps = hostString.components(separatedBy: ":")
                guard hostComps.count == 6 else {
                    throw ProxyError.invalidUri
                }
                self.host = hostComps[0]
                guard let p = Int(hostComps[1]) else {
                    throw ProxyError.invalidPort
                }
                self.port = p
                self.ssrProtocol = hostComps[2]
                self.authscheme = hostComps[3]
                self.ssrObfs = hostComps[4]
                self.password = base64DecodeIfNeeded(hostComps[5])
                for queryComp in queryString.components(separatedBy: "&") {
                    let comps = queryComp.components(separatedBy: "=")
                    guard comps.count == 2 else {
                        continue
                    }
                    switch comps[0] {
                    case "obfsparam":
                        self.ssrObfsParam = comps[1]
                    default:
                        continue
                    }
                }
                self.type = .ShadowsocksR
            } else {
                // Not supported yet
                throw ProxyError.invalidUri
            }
    }
    
    public convenience init(host: String, port: Int, authscheme: String, password: String, type: ProxyType) throws {
        self.init()
        self.host = host
        self.port = port
        self.password = password
        self.authscheme = authscheme
        self.type = type
        try validate()
    }
    
    public static func nsproxy(dictionary: NSDictionary) -> Proxy? {
        do {
            if let uriString = dictionary["uri"] as? String {
                
                let p = try Proxy(string: uriString.trimmingCharacters(in: CharacterSet.whitespaces))
                if let ip = dictionary["ip"] as? String {
                    p.ip = ip
                } else {
                    
                }
                return p
            }
            
            guard let host = dictionary["host"] as? String else {
                return nil
            }
            guard let typeRaw = dictionary["type"] as? String, let type = ProxyType(rawValue: typeRaw) else {
                throw ProxyError.invalidType
            }
            guard let port = dictionary["port"] as? Int else {
                throw ProxyError.invalidPort
            }
            guard let encryption = dictionary["encryption"] as? String else {
                throw ProxyError.invalidAuthScheme
            }
            guard let password = dictionary["password"] as? String else {
                throw ProxyError.invalidPassword
            }
            return try Proxy(host: host, port: port, authscheme: encryption, password: password, type: type)
        } catch {
        }
        return nil
    }

    public static func proxy(dictionary: [String: String]) -> Proxy? {
        do {
            if let uriString = dictionary["uri"] {
                
                let p = try Proxy(string: uriString.trimmingCharacters(in: CharacterSet.whitespaces))
                if let ip = dictionary["ip"] {
                    p.ip = ip
                } else {
                    
                }
                return p
            }
            
            guard let host = dictionary["host"] else {
                return nil
            }
            guard let typeRaw = dictionary["type"]?.uppercased(), let type = ProxyType(rawValue: typeRaw) else {
                throw ProxyError.invalidType
            }
            guard let portStr = dictionary["port"], let port = Int(portStr) else {
                throw ProxyError.invalidPort
            }
            guard let encryption = dictionary["encryption"] else {
                throw ProxyError.invalidAuthScheme
            }
            guard let password = dictionary["password"] else {
                throw ProxyError.invalidPassword
            }
            return try Proxy(host: host, port: port, authscheme: encryption, password: password, type: type)
        } catch {
        }
        return nil
    }

    fileprivate func base64DecodeIfNeeded(_ proxyString: String) -> String {
        let base64String = proxyString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let base64Charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        if CharacterSet(charactersIn: base64String).isSubset(of: base64Charset) {
            let padding = base64String.characters.count + (base64String.characters.count % 4 != 0 ? (4 - base64String.characters.count % 4) : 0)
            if let decodedData = Data(base64Encoded: base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData, encoding: String.Encoding.utf8.rawValue) {
                return decodedString as String
            }
            return proxyString
        }
        return proxyString
    }

    private static func schemeIsProxy(_ scheme: String) -> Bool {
        return (scheme == Proxy.ssUriMethod)
            || (scheme == Proxy.ssrUriMethod)
            || (scheme == "mume")
            || (scheme == "shadowsocks")
            || (scheme == "shadowsocksr")
            || (scheme == "mss")
            || (scheme == "socks5")
            || (scheme == "socks")
    }

    public static func uriIsProxy(_ uri: String) -> Bool {
        if let url = URL(string: uri) {
            return Proxy.urlIsProxy(url)
        }
        return false
    }
    
    public static func urlIsProxy(_ url: URL) -> Bool {
        if let scheme = url.scheme {
            return Proxy.schemeIsProxy(scheme.lowercased()) && (url.host != "on") && (url.host != "off")
        }
        return false
    }
}

public func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.uuid == rhs.uuid
}

open class CloudProxy: Proxy {
    @objc open dynamic var due: String?
    @objc open dynamic var provider: String?
    @objc open dynamic var link: String?

    public static func cloudProxy(dictionary: NSDictionary) -> CloudProxy? {
        if let uriString = dictionary["uri"] as? String,
            let p = try? CloudProxy(string: uriString.trimmingCharacters(in: CharacterSet.whitespaces)) {
            
            if let ip = dictionary["ip"] as? String {
                p.ip = ip
            }
            if let due = dictionary["due"] as? String {
                p.due = due
            }
            if let provider = dictionary["provider"] as? String {
                p.provider = provider
            }
            if let link = dictionary["link"] as? String {
                p.link = link
            }
            return p
        }
        return nil
    }
}
