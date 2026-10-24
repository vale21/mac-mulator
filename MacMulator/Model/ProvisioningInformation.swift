//
//  ProvisioningInformation.swift
//  MacMulator
//
//  Created by Vale on 24/10/2026.
//

import Foundation
import Security

class ProvisioningInformation: Codable, Hashable {
    var userFullName: String
    var userName: String
    var automaticLogin: Bool
    var enableSSh: Bool
    var passwordKeychainId: String

    var userPassword: String {
        get { ProvisioningPasswordStore.read(account: passwordKeychainId) ?? "" }
        set { ProvisioningPasswordStore.save(newValue, account: passwordKeychainId) }
    }

    enum CodingKeys: String, CodingKey {
        case userFullName, userName, automaticLogin, enableSSh, passwordKeychainId
    }

    init(userFullName: String, userName: String, userPassword: String, automaticLogin: Bool, enableSSh: Bool) {
        self.userFullName = userFullName
        self.userName = userName
        passwordKeychainId = UUID().uuidString
        self.automaticLogin = automaticLogin
        self.enableSSh = enableSSh
        self.userPassword = userPassword
    }

    static func == (lhs: ProvisioningInformation, rhs: ProvisioningInformation) -> Bool {
        lhs.userFullName == rhs.userFullName &&
            lhs.userName == rhs.userName &&
            lhs.passwordKeychainId == rhs.passwordKeychainId &&
            lhs.automaticLogin == rhs.automaticLogin &&
            lhs.enableSSh == rhs.enableSSh
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userFullName)
        hasher.combine(userName)
        hasher.combine(passwordKeychainId)
        hasher.combine(automaticLogin)
        hasher.combine(enableSSh)
    }

    func deletePassword() {
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
