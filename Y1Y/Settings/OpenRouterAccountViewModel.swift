//
//  OpenRouterAccountViewModel.swift
//  Y1Y
//

import Combine
import Foundation

@MainActor
final class OpenRouterAccountViewModel: ObservableObject {
    @Published private(set) var state: OpenRouterAccountState = .initial

    private let client: any OpenRouterAccountServing
    private let cacheStore: BalanceCacheStore
    private let now: () -> Date
    private var refreshTask: Task<Void, Never>?
    private var refreshID: UUID?

    init(
        client: (any OpenRouterAccountServing)? = nil,
        cacheStore: BalanceCacheStore? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client ?? OpenRouterAccountClient()
        self.cacheStore = cacheStore ?? BalanceCacheStore()
        self.now = now
    }

    func refresh(baseURL: String, apiKey: String) {
        refreshTask?.cancel()

        let refreshID = UUID()
        self.refreshID = refreshID
        let scope = BalanceCacheStore.scope(
            baseURL: baseURL,
            apiKey: apiKey
        )

        guard !apiKey.isEmpty else {
            state = OpenRouterAccountState(
                connection: .disconnected(message: "请先配置 API Key。"),
                balance: nil,
                isStale: false,
                balanceErrorMessage: "请先配置 API Key。"
            )
            return
        }

        state = OpenRouterAccountState(
            connection: .loading,
            balance: nil,
            isStale: false,
            balanceErrorMessage: nil
        )

        refreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await client.checkConnection(
                    baseURL: baseURL,
                    apiKey: apiKey
                )
            } catch is CancellationError {
                return
            } catch {
                applyFailure(
                    error,
                    scope: scope,
                    refreshID: refreshID,
                    connectionFailed: true
                )
                return
            }

            do {
                let amount = try await client.fetchAvailableBalance(
                    baseURL: baseURL,
                    apiKey: apiKey
                )
                guard isCurrent(refreshID), !Task.isCancelled else { return }

                let snapshot = BalanceSnapshot(
                    availableAmount: amount,
                    updatedAt: now(),
                    scope: scope
                )
                cacheStore.saveSnapshot(snapshot)
                state = OpenRouterAccountState(
                    connection: .connected,
                    balance: snapshot,
                    isStale: false,
                    balanceErrorMessage: nil
                )
            } catch is CancellationError {
                return
            } catch {
                applyFailure(
                    error,
                    scope: scope,
                    refreshID: refreshID,
                    connectionFailed: false
                )
            }
        }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
    }

    private func applyFailure(
        _ error: Error,
        scope: String,
        refreshID: UUID,
        connectionFailed: Bool
    ) {
        guard isCurrent(refreshID), !Task.isCancelled else { return }
        let cachedBalance = cacheStore.loadSnapshot(matching: scope)
        let message = error.localizedDescription
        state = OpenRouterAccountState(
            connection: connectionFailed
                ? .disconnected(message: message)
                : .connected,
            balance: cachedBalance,
            isStale: cachedBalance != nil,
            balanceErrorMessage: message
        )
    }

    private func isCurrent(_ refreshID: UUID) -> Bool {
        self.refreshID == refreshID
    }

    deinit {
        refreshTask?.cancel()
    }
}
