//
//  ProvisioningInformation.swift
//  MacMulator
//
//  Created by Vale on 24/10/2026.
//

import Foundation
import Security

enum CloudInitIPv4Mode: String, Codable {
    case staticAddress, dhcp
}

enum CloudInitIPv6Mode: String, Codable {
    case staticAddress, dhcp, slaac
}

struct CloudInitIPConfiguration: Codable, Hashable {
    var ipv4Mode: CloudInitIPv4Mode = .staticAddress
    var ipv4Cidr: String = ""
    var ipv4Gateway: String = ""
    var ipv6Mode: CloudInitIPv6Mode = .staticAddress
    var ipv6Cidr: String = ""
    var ipv6Gateway: String = ""
}

class ProvisioningInformation: Codable, Hashable {
    var userFullName: String
    var userName: String
    var automaticLogin: Bool
    var enableSSh: Bool
    var passwordKeychainId: String

    // Cloud-init only (Linux VMs)
    var dnsDomains: [String] = []
    var dnsServers: [String] = []
    var sshKeys: [String] = []
    var upgradePackages: Bool = false
    var ipConfiguration: CloudInitIPConfiguration?

    var userPassword: String {
        get { ProvisioningPasswordStore.read(account: passwordKeychainId) ?? "" }
        set { ProvisioningPasswordStore.save(newValue, account: passwordKeychainId) }
    }

    enum CodingKeys: String, CodingKey {
        case userFullName, userName, automaticLogin, enableSSh, passwordKeychainId
        case dnsDomains, dnsServers, sshKeys, upgradePackages, ipConfiguration
    }

    // Custom decoding so that VMs saved before the cloud-init fields existed can still be loaded
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userFullName = try container.decode(String.self, forKey: .userFullName)
        userName = try container.decode(String.self, forKey: .userName)
        automaticLogin = try container.decode(Bool.self, forKey: .automaticLogin)
        enableSSh = try container.decode(Bool.self, forKey: .enableSSh)
        passwordKeychainId = try container.decode(String.self, forKey: .passwordKeychainId)
        dnsDomains = try container.decodeIfPresent([String].self, forKey: .dnsDomains) ?? []
        dnsServers = try container.decodeIfPresent([String].self, forKey: .dnsServers) ?? []
        sshKeys = try container.decodeIfPresent([String].self, forKey: .sshKeys) ?? []
        upgradePackages = try container.decodeIfPresent(Bool.self, forKey: .upgradePackages) ?? false
        ipConfiguration = try container.decodeIfPresent(CloudInitIPConfiguration.self, forKey: .ipConfiguration)
    }

    init(userFullName: String, userName: String, userPassword: String, automaticLogin: Bool, enableSSh: Bool) {
        self.userFullName = userFullName
        self.userName = userName
        passwordKeychainId = UUID().uuidString
        self.automaticLogin = automaticLogin
        self.enableSSh = enableSSh
        self.userPassword = userPassword
    }

    convenience init(userFullName: String, userName: String, userPassword: String, dnsDomains: [String], dnsServers: [String], sshKeys: [String], upgradePackages: Bool, ipConfiguration: CloudInitIPConfiguration?) {
        self.init(userFullName: userFullName, userName: userName, userPassword: userPassword, automaticLogin: false, enableSSh: !sshKeys.isEmpty)
        self.dnsDomains = dnsDomains
        self.dnsServers = dnsServers
        self.sshKeys = sshKeys
        self.upgradePackages = upgradePackages
        self.ipConfiguration = ipConfiguration
    }

    static func == (lhs: ProvisioningInformation, rhs: ProvisioningInformation) -> Bool {
        lhs.userFullName == rhs.userFullName &&
            lhs.userName == rhs.userName &&
            lhs.passwordKeychainId == rhs.passwordKeychainId &&
            lhs.automaticLogin == rhs.automaticLogin &&
            lhs.enableSSh == rhs.enableSSh &&
            lhs.dnsDomains == rhs.dnsDomains &&
            lhs.dnsServers == rhs.dnsServers &&
            lhs.sshKeys == rhs.sshKeys &&
            lhs.upgradePackages == rhs.upgradePackages &&
            lhs.ipConfiguration == rhs.ipConfiguration
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userFullName)
        hasher.combine(userName)
        hasher.combine(passwordKeychainId)
        hasher.combine(automaticLogin)
        hasher.combine(enableSSh)
        hasher.combine(dnsDomains)
        hasher.combine(dnsServers)
        hasher.combine(sshKeys)
        hasher.combine(upgradePackages)
        hasher.combine(ipConfiguration)
    }

    func cleanup() {
        ProvisioningPasswordStore.delete(account: passwordKeychainId)
    }
}

enum ProvisioningPasswordStore {
    private static let service = "MacMulator.provisioning"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func save(_ password: String, account: String) {
        delete(account: account)
        var attributes = query(account)
        attributes[kSecValueData as String] = Data(password.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}

/// A validation failure: the localization key of the message and an optional offending value
struct CloudInitValidationError: Error {
    let messageKey: String
    let argument: CVarArg?

    init(_ messageKey: String, _ argument: CVarArg? = nil) {
        self.messageKey = messageKey
        self.argument = argument
    }

    var localizedMessage: String {
        let format = NSLocalizedString(messageKey, comment: "")
        guard let argument else { return format }
        return String(format: format, argument)
    }
}

enum CloudInitValidator {
    private static let keyPrefix = "CloudInitOptionsViewController."

    private static let sshKeyTypes: Set<String> = [
        "ssh-rsa", "ssh-ed25519", "ssh-dss", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521",
        "sk-ssh-ed25519@openssh.com", "sk-ecdsa-sha2-nistp256@openssh.com",
    ]

    private static func tokens(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",").union(.whitespacesAndNewlines)).filter { !$0.isEmpty }
    }

    static func isValidUserName(_ name: String) -> Bool {
        name.range(of: "^[a-z_][a-z0-9_-]{0,31}$", options: .regularExpression) != nil
    }

    static func isValidIPv4(_ address: String) -> Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, address, &addr) == 1
    }

    static func isValidIPv6(_ address: String) -> Bool {
        var addr = in6_addr()
        return inet_pton(AF_INET6, address, &addr) == 1
    }

    static func isValidDomain(_ domain: String) -> Bool {
        guard domain.count <= 253 else { return false }
        let label = "[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
        return domain.range(of: "^\(label)(\\.\(label))*$", options: .regularExpression) != nil
    }

    static func isValidCidr(_ cidr: String, ipv6: Bool) -> Bool {
        let parts = cidr.components(separatedBy: "/")
        guard parts.count == 2, let prefix = Int(parts[1]), String(prefix) == parts[1] else { return false }
        return ipv6 ? (isValidIPv6(parts[0]) && (1 ... 128).contains(prefix)) : (isValidIPv4(parts[0]) && (1 ... 32).contains(prefix))
    }

    static func parseDnsDomains(_ text: String) throws -> [String] {
        let domains = tokens(text)
        if let invalid = domains.first(where: { !isValidDomain($0) }) {
            throw CloudInitValidationError(keyPrefix + "dnsDomainInvalid", invalid)
        }
        return domains
    }

    static func parseDnsServers(_ text: String) throws -> [String] {
        let servers = tokens(text)
        if let invalid = servers.first(where: { !isValidIPv4($0) && !isValidIPv6($0) }) {
            throw CloudInitValidationError(keyPrefix + "dnsServerInvalid", invalid)
        }
        return servers
    }

    static func parseSshKeys(_ text: String) throws -> [String] {
        var keys: [String] = []
        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2, sshKeyTypes.contains(String(fields[0])), Data(base64Encoded: String(fields[1])) != nil else {
                throw CloudInitValidationError(keyPrefix + "sshKeyInvalid", index + 1)
            }
            keys.append(line)
        }
        return keys
    }

    static func buildIPConfiguration(ipv4Mode: CloudInitIPv4Mode, ipv4Cidr: String, ipv4Gateway: String, ipv6Mode: CloudInitIPv6Mode, ipv6Cidr: String, ipv6Gateway: String) throws -> CloudInitIPConfiguration {
        var config = CloudInitIPConfiguration(ipv4Mode: ipv4Mode, ipv6Mode: ipv6Mode)

        if ipv4Mode == .staticAddress {
            let cidr = ipv4Cidr.trimmingCharacters(in: .whitespaces)
            let gateway = ipv4Gateway.trimmingCharacters(in: .whitespaces)
            guard isValidCidr(cidr, ipv6: false) else { throw CloudInitValidationError(keyPrefix + "ipv4CidrInvalid") }
            guard gateway.isEmpty || isValidIPv4(gateway) else { throw CloudInitValidationError(keyPrefix + "ipv4GatewayInvalid") }
            config.ipv4Cidr = cidr
            config.ipv4Gateway = gateway
        }

        if ipv6Mode == .staticAddress {
            let cidr = ipv6Cidr.trimmingCharacters(in: .whitespaces)
            let gateway = ipv6Gateway.trimmingCharacters(in: .whitespaces)
            guard isValidCidr(cidr, ipv6: true) else { throw CloudInitValidationError(keyPrefix + "ipv6CidrInvalid") }
            guard gateway.isEmpty || isValidIPv6(gateway) else { throw CloudInitValidationError(keyPrefix + "ipv6GatewayInvalid") }
            config.ipv6Cidr = cidr
            config.ipv6Gateway = gateway
        }
        return config
    }
}
