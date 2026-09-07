//
//  AppModels.swift
//  Y1Y
//

import CoreGraphics
import Foundation

struct ResponsePanelSize: Codable, Equatable, Sendable {
    static let defaultSize = ResponsePanelSize(width: 380, height: 360)

    var width: CGFloat
    var height: CGFloat
}

enum PanelPhase: String, Codable, Equatable, Sendable {
    case promptList
    case response
}

enum PinState: String, Codable, Equatable, Sendable {
    case unpinned
    case pinned

    mutating func toggle() {
        self = self == .pinned ? .unpinned : .pinned
    }
}

struct BalanceSnapshot: Codable, Equatable, Sendable {
    var availableAmount: Decimal
    var updatedAt: Date
    var scope: String
}

enum OpenRouterConnectionState: Equatable, Sendable {
    case idle
    case loading
    case connected
    case disconnected(message: String)
}

struct OpenRouterAccountState: Equatable, Sendable {
    static let initial = OpenRouterAccountState(
        connection: .idle,
        balance: nil,
        isStale: false,
        balanceErrorMessage: nil
    )

    var connection: OpenRouterConnectionState
    var balance: BalanceSnapshot?
    var isStale: Bool
    var balanceErrorMessage: String?
}
