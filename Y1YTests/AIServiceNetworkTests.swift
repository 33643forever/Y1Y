//
//  AIServiceNetworkTests.swift
//  Y1YTests
//

import XCTest
@testable import Y1Y

// MARK: - Mock URLProtocol for controllable network responses

final class MockStreamURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseStatusCode: Int = 200
    nonisolated(unsafe) static var responseHeaders: [String: String] = ["Content-Type": "text/event-stream"]
    nonisolated(unsafe) static var responseBody: Data?
    nonisolated(unsafe) static var responseError: Error?
    /// When true, the protocol never delivers a response (simulates a hang).
    nonisolated(unsafe) static var shouldHang: Bool = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard !Self.shouldHang else {
            // Never respond — the URLSession timeout should fire.
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.responseStatusCode,
            httpVersion: "1.1",
            headerFields: Self.responseHeaders
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        if let body = Self.responseBody {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // No cleanup needed for mock.
    }
}

// MARK: - Test helpers

private func makeTimeoutSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockStreamURLProtocol.self]
    config.timeoutIntervalForRequest = 0.5  // 500 ms
    config.timeoutIntervalForResource = 1.0
    return URLSession(configuration: config)
}

private func makeImmediateSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockStreamURLProtocol.self]
    // Keep default timeouts but use mock responses.
    return URLSession(configuration: config)
}

/// An SSE‑like data line that `streamChat` would accept.
private func sseDataLine(_ content: String) -> String {
    let escaped = content
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "data: {\"choices\":[{\"delta\":{\"content\":\"\(escaped)\"}}]}\n"
}

private let testBaseURL = "https://api.openrouter.ai/api/v1"
private let testKey = "sk-test-mock-key-not-real"

// MARK: - Tests

@MainActor
final class AIServiceNetworkTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockStreamURLProtocol.responseStatusCode = 200
        MockStreamURLProtocol.responseHeaders = ["Content-Type": "text/event-stream"]
        MockStreamURLProtocol.responseBody = nil
        MockStreamURLProtocol.responseError = nil
        MockStreamURLProtocol.shouldHang = false
    }

    // MARK: - Timeout on first byte

    func testHangOnFirstByteTimesOutAndEndsLoading() async throws {
        let expectation = XCTestExpectation(description: "timeout observed")
        MockStreamURLProtocol.shouldHang = true
        let service = AIService(urlSession: makeTimeoutSession())

        // Monkey‑patch settings for this request scope.
        let settings = SettingsManager.shared
        let savedKey = settings.apiKey
        let savedURL = settings.apiBaseURL
        settings.apiKey = testKey
        settings.apiBaseURL = testBaseURL
        defer {
            settings.apiKey = savedKey
            settings.apiBaseURL = savedURL
        }

        service.sendRequest(systemPrompt: "", userContent: "hello")

        // Wait for the timeout to fire and isLoading to become false.
        let deadline = CFAbsoluteTimeGetCurrent() + 5.0
        while service.isLoading && CFAbsoluteTimeGetCurrent() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(service.isLoading, "isLoading should be false after timeout")
        XCTAssertNotNil(service.errorMessage, "errorMessage should be set after timeout")
        expectation.fulfill()

        await fulfillment(of: [expectation], timeout: 0)
    }

    // MARK: - HTTP error status

    func testHTTPErrorSetsErrorMessageAndEndsLoading() async throws {
        MockStreamURLProtocol.responseStatusCode = 401
        MockStreamURLProtocol.responseBody = """
        {"error":{"message":"Invalid API key"}}
        """.data(using: .utf8)

        let service = AIService(urlSession: makeImmediateSession())
        let settings = SettingsManager.shared
        let savedKey = settings.apiKey
        let savedURL = settings.apiBaseURL
        settings.apiKey = testKey
        settings.apiBaseURL = testBaseURL
        defer {
            settings.apiKey = savedKey
            settings.apiBaseURL = savedURL
        }

        service.sendRequest(systemPrompt: "", userContent: "hello")

        let deadline = CFAbsoluteTimeGetCurrent() + 2.0
        while service.isLoading && CFAbsoluteTimeGetCurrent() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(service.isLoading)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.errorMessage?.contains("401") == true, "should mention HTTP 401")
    }

    // MARK: - Empty stream (HTTP 200, no data lines)

    func testEmptyStreamEndsLoadingWithoutContent() async throws {
        MockStreamURLProtocol.responseBody = "data: [DONE]\n".data(using: .utf8)

        let service = AIService(urlSession: makeImmediateSession())
        let settings = SettingsManager.shared
        let savedKey = settings.apiKey
        let savedURL = settings.apiBaseURL
        settings.apiKey = testKey
        settings.apiBaseURL = testBaseURL
        defer {
            settings.apiKey = savedKey
            settings.apiBaseURL = savedURL
        }

        service.sendRequest(systemPrompt: "", userContent: "hello")

        let deadline = CFAbsoluteTimeGetCurrent() + 2.0
        while service.isLoading && CFAbsoluteTimeGetCurrent() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(service.isLoading, "isLoading should be false")
        XCTAssertEqual(service.responseText, "", "no content should have been produced")
        XCTAssertNil(service.errorMessage)
    }

    // MARK: - Normal streaming completes successfully

    func testNormalStreamCompletesWithContent() async throws {
        let body = sseDataLine("Hello ") + sseDataLine("world!") + "data: [DONE]\n"
        MockStreamURLProtocol.responseBody = body.data(using: .utf8)

        let service = AIService(urlSession: makeImmediateSession())
        let settings = SettingsManager.shared
        let savedKey = settings.apiKey
        let savedURL = settings.apiBaseURL
        settings.apiKey = testKey
        settings.apiBaseURL = testBaseURL
        defer {
            settings.apiKey = savedKey
            settings.apiBaseURL = savedURL
        }

        service.sendRequest(systemPrompt: "", userContent: "hello")

        let deadline = CFAbsoluteTimeGetCurrent() + 2.0
        while service.isLoading && CFAbsoluteTimeGetCurrent() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(service.isLoading)
        XCTAssertEqual(service.responseText, "Hello world!")
        XCTAssertNil(service.errorMessage)
    }

    // MARK: - User cancellation

    func testCancellationEndsLoadingAndAllowsNewRequest() async throws {
        MockStreamURLProtocol.shouldHang = true

        let service = AIService(urlSession: makeTimeoutSession())
        let settings = SettingsManager.shared
        let savedKey = settings.apiKey
        let savedURL = settings.apiBaseURL
        settings.apiKey = testKey
        settings.apiBaseURL = testBaseURL
        defer {
            settings.apiKey = savedKey
            settings.apiBaseURL = savedURL
        }

        // Start first request
        service.sendRequest(systemPrompt: "", userContent: "first")
        XCTAssertTrue(service.isLoading)

        // Cancel immediately
        service.cancel()
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)

        // Start a second request — should reset state cleanly
        service.sendRequest(systemPrompt: "", userContent: "second")
        XCTAssertTrue(service.isLoading)
        XCTAssertNil(service.errorMessage)

        // Cancel again
        service.cancel()
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)
    }
}
