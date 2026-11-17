//
//  SHA512Crypt.swift
//  MacMulator
//
//  Created by Vale on 16/11/2026.
//

import CryptoKit
import Foundation

/// SHA-512 based crypt ("$6$" hashes, as in /etc/shadow), as specified by Ulrich Drepper.
/// cloud-init accepts it for the user password, so that the password is never written in clear text.
enum SHA512Crypt {
    private static let rounds = 5000
    private static let alphabet = Array("./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    // The order in which the bytes of the final digest are encoded
    private static let encodingOrder: [(Int, Int, Int)] = [
        (0, 21, 42), (22, 43, 1), (44, 2, 23), (3, 24, 45), (25, 46, 4), (47, 5, 26), (6, 27, 48),
        (28, 49, 7), (50, 8, 29), (9, 30, 51), (31, 52, 10), (53, 11, 32), (12, 33, 54), (34, 55, 13),
        (56, 14, 35), (15, 36, 57), (37, 58, 16), (59, 17, 38), (18, 39, 60), (40, 61, 19), (62, 20, 41),
    ]

    /// The salt can contain only [./0-9A-Za-z], and at most 16 characters of it are used
    static func hash(_ password: String, salt: String) -> String {
        let p = Array(password.utf8)
        let s = Array(salt.utf8.prefix(16))

        let b = digest(p + s + p)
        var a = p + s + repeated(b, toLength: p.count)
        var length = p.count
        while length > 0 {
            a += (length & 1) != 0 ? b : p
            length >>= 1
        }
        let digestA = digest(a)

        let pBytes = repeated(digest(Array([[UInt8]](repeating: p, count: p.count).joined())), toLength: p.count)
        let sBytes = repeated(digest(Array([[UInt8]](repeating: s, count: 16 + Int(digestA[0])).joined())), toLength: s.count)

        var c = digestA
        for i in 0 ..< rounds {
            var input = i % 2 == 1 ? pBytes : c
            if i % 3 != 0 { input += sBytes }
            if i % 7 != 0 { input += pBytes }
            input += i % 2 == 1 ? c : pBytes
            c = digest(input)
        }

        var encoded = ""
        for (b2, b1, b0) in encodingOrder {
            encoded += encode(Int(c[b2]) << 16 | Int(c[b1]) << 8 | Int(c[b0]), characters: 4)
        }
        encoded += encode(Int(c[63]), characters: 2)
        return "$6$" + String(decoding: s, as: UTF8.self) + "$" + encoded
    }

    private static func digest(_ bytes: [UInt8]) -> [UInt8] {
        Array(SHA512.hash(data: bytes))
    }

    /// The bytes repeated (and truncated) to the given length
    private static func repeated(_ bytes: [UInt8], toLength length: Int) -> [UInt8] {
        (0 ..< length).map { bytes[$0 % bytes.count] }
    }

    private static func encode(_ value: Int, characters: Int) -> String {
        var value = value
        var result = ""
        for _ in 0 ..< characters {
            result.append(alphabet[value & 0x3F])
            value >>= 6
        }
        return result
    }
}
