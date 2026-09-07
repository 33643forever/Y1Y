//
//  BalanceCacheStore.swift
//  Y1Y
//

import CryptoKit
import Foundation

struct BalanceCacheStore {
    private enum Keys {
        static let snapshot = "openRouterBalanceSnapshot"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot(matching scope: String) -> BalanceSnapshot? {
        guard !scope.isEmpty,
              let data = defaults.data(forKey: Keys.snapshot),
              let snapshot = try? decoder.decode(BalanceSnapshot.self, from: data),
              snapshot.scope == scope
        else {
            return nil
        }

        return snapshot
    }

    func saveSnapshot(_ snapshot: BalanceSnapshot) {
        guard !snapshot.scope.isEmpty,
              let data = try? encoder.encode(snapshot)
        else {
            return
        }

        defaults.set(data, forKey: Keys.snapshot)
    }

    static func scope(baseURL: String, apiKey: String) -> String {
        let normalizedHost = URL(string: baseURL)?.host?.lowercased()
            ?? baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let input = Data("\(normalizedHost)\u{0}\(apiKey)".utf8)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
