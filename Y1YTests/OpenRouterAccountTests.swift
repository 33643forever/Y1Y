import Foundation
import XCTest
@testable import Y1Y

private enum AccountStubError: LocalizedError {
    case connection
    case balance

    var errorDescription: String? {
        switch self {
        case .connection: return "connection failed"
        case .balance: return "balance failed"
        }
    }
}

@MainActor
private final class AccountClientStub: OpenRouterAccountServing {
    enum Plan {
        case success(Decimal)
        case connectionFailure
        case balanceFailure
        case delayedSuccess(Decimal, Duration)
    }

    var plans: [String: Plan] = [:]
    private(set) var connectionCalls = 0
    private(set) var balanceCalls = 0

    func checkConnection(baseURL: String, apiKey: String) async throws {
        connectionCalls += 1
        guard let plan = plans[apiKey] else { return }
        switch plan {
        case .connectionFailure:
            throw AccountStubError.connection
        case .delayedSuccess(_, let delay):
            do {
                try await Task.sleep(for: delay)
            } catch {
                // Ignore cancellation to verify the ViewModel revision guard.
            }
        case .success, .balanceFailure:
            return
        }
    }

    func fetchAvailableBalance(
        baseURL: String,
        apiKey: String
    ) async throws -> Decimal {
        balanceCalls += 1
        guard let plan = plans[apiKey] else { return 0 }
        switch plan {
        case .success(let amount), .delayedSuccess(let amount, _):
            return amount
        case .connectionFailure:
            throw AccountStubError.connection
        case .balanceFailure:
            throw AccountStubError.balance
        }
    }
}

@MainActor
final class OpenRouterAccountTests: XCTestCase {
    private let baseURL = "https://openrouter.ai/api/v1"

    func testSuccessfulRefreshWritesScopedCache() async throws {
        let (cache, defaults, suiteName) = makeCache()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let client = AccountClientStub()
        client.plans["success-key"] = .success(Decimal(string: "42.50")!)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = OpenRouterAccountViewModel(
            client: client,
            cacheStore: cache,
            now: { now }
        )

        viewModel.refresh(baseURL: baseURL, apiKey: "success-key")
        XCTAssertEqual(viewModel.state.connection, .loading)
        try await waitUntil {
            viewModel.state.connection == .connected
        }

        XCTAssertEqual(viewModel.state.balance?.availableAmount, Decimal(string: "42.50"))
        XCTAssertFalse(viewModel.state.isStale)
        let scope = BalanceCacheStore.scope(
            baseURL: baseURL,
            apiKey: "success-key"
        )
        XCTAssertEqual(
            cache.loadSnapshot(matching: scope),
            viewModel.state.balance
        )
        XCTAssertNil(
            cache.loadSnapshot(
                matching: BalanceCacheStore.scope(
                    baseURL: baseURL,
                    apiKey: "different-key"
                )
            )
        )
    }

    func testFailureUsesOnlyMatchingOldData() async throws {
        let (cache, defaults, suiteName) = makeCache()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let client = AccountClientStub()
        client.plans["stale-key"] = .balanceFailure
        let matchingScope = BalanceCacheStore.scope(
            baseURL: baseURL,
            apiKey: "stale-key"
        )
        let oldSnapshot = BalanceSnapshot(
            availableAmount: 7,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            scope: matchingScope
        )
        cache.saveSnapshot(oldSnapshot)
        let viewModel = OpenRouterAccountViewModel(
            client: client,
            cacheStore: cache
        )

        viewModel.refresh(baseURL: baseURL, apiKey: "stale-key")
        try await waitUntil { viewModel.state.balanceErrorMessage != nil }

        XCTAssertEqual(viewModel.state.connection, .connected)
        XCTAssertEqual(viewModel.state.balance, oldSnapshot)
        XCTAssertTrue(viewModel.state.isStale)

        let otherViewModel = OpenRouterAccountViewModel(
            client: client,
            cacheStore: cache
        )
        client.plans["other-key"] = .connectionFailure
        otherViewModel.refresh(baseURL: baseURL, apiKey: "other-key")
        try await waitUntil {
            if case .disconnected = otherViewModel.state.connection {
                return true
            }
            return false
        }
        XCTAssertNil(otherViewModel.state.balance)
        XCTAssertFalse(otherViewModel.state.isStale)
    }

    func testOlderRequestCannotOverwriteNewConfiguration() async throws {
        let (cache, defaults, suiteName) = makeCache()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let client = AccountClientStub()
        client.plans["old-key"] = .delayedSuccess(
            1,
            .milliseconds(200)
        )
        client.plans["new-key"] = .success(2)
        let viewModel = OpenRouterAccountViewModel(
            client: client,
            cacheStore: cache
        )

        viewModel.refresh(baseURL: baseURL, apiKey: "old-key")
        await Task.yield()
        viewModel.refresh(baseURL: baseURL, apiKey: "new-key")
        try await waitUntil {
            viewModel.state.balance?.availableAmount == 2
        }
        try await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(viewModel.state.balance?.availableAmount, 2)
        XCTAssertEqual(
            viewModel.state.balance?.scope,
            BalanceCacheStore.scope(
                baseURL: baseURL,
                apiKey: "new-key"
            )
        )
    }

    func testEmptyKeyShowsConfigurationStateWithoutRequest() {
        let (cache, defaults, suiteName) = makeCache()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let client = AccountClientStub()
        let viewModel = OpenRouterAccountViewModel(
            client: client,
            cacheStore: cache
        )

        viewModel.refresh(baseURL: baseURL, apiKey: "")

        if case .disconnected(let message) = viewModel.state.connection {
            XCTAssertEqual(message, "请先配置 API Key。")
        } else {
            XCTFail("Expected configuration reminder")
        }
        XCTAssertEqual(client.connectionCalls, 0)
        XCTAssertEqual(client.balanceCalls, 0)
    }

    func testOpenRouterVisibilityRequiresExactHostOrSubdomain() {
        XCTAssertTrue(
            OpenRouterEndpointPolicy.isOpenRouter(baseURL)
        )
        XCTAssertTrue(
            OpenRouterEndpointPolicy.isOpenRouter(
                "https://api.openrouter.ai/v1"
            )
        )
        XCTAssertFalse(
            OpenRouterEndpointPolicy.isOpenRouter(
                "https://api.openai.com/v1"
            )
        )
        XCTAssertFalse(
            OpenRouterEndpointPolicy.isOpenRouter(
                "https://openrouter.ai.example.com/v1"
            )
        )
    }

    private func makeCache() -> (
        BalanceCacheStore,
        UserDefaults,
        String
    ) {
        let suiteName = "Y1YTests.Account.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (
            BalanceCacheStore(defaults: defaults),
            defaults,
            suiteName
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for account state")
                return
            }
            await Task.yield()
        }
    }
}
