import Combine
import Foundation
import Markdown

struct MarkdownRenderSnapshot: Equatable, Sendable {
    let source: String
    let topLevelBlockCount: Int
    let isFinal: Bool
    let presentationMode: MarkdownPresentationMode
}

@MainActor
final class MarkdownRenderStore: ObservableObject {
    typealias Parser = @Sendable (String, Bool) -> MarkdownRenderSnapshot

    @Published private(set) var snapshot = MarkdownRenderSnapshot(
        source: "",
        topLevelBlockCount: 0,
        isFinal: false,
        presentationMode: .markdown
    )

    private let throttleInterval: Duration
    private let parser: Parser
    private var parseTask: Task<Void, Never>?
    private var revision = 0
    private var latestSource = ""

    init(throttleInterval: Duration = .milliseconds(75)) {
        self.throttleInterval = throttleInterval
        self.parser = { source, isFinal in
            MarkdownRenderStore.defaultParser(
                source: source,
                isFinal: isFinal
            )
        }
    }

    init(throttleInterval: Duration, parser: @escaping Parser) {
        self.throttleInterval = throttleInterval
        self.parser = parser
    }

    func update(source: String) {
        latestSource = source
        schedule(source: source, isFinal: false, delay: throttleInterval)
    }

    func finish(source: String? = nil) {
        if let source {
            latestSource = source
        }
        schedule(source: latestSource, isFinal: true, delay: .zero)
    }

    func reset() {
        parseTask?.cancel()
        revision += 1
        latestSource = ""
        snapshot = MarkdownRenderSnapshot(
            source: "",
            topLevelBlockCount: 0,
            isFinal: false,
            presentationMode: .markdown
        )
    }

    func waitForPendingRender() async {
        await parseTask?.value
    }

    private func schedule(source: String, isFinal: Bool, delay: Duration) {
        revision += 1
        let scheduledRevision = revision
        let parser = parser

        parseTask?.cancel()
        parseTask = Task.detached { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }

            let parsedSnapshot = parser(source, isFinal)
            guard !Task.isCancelled else { return }

            await self?.accept(
                parsedSnapshot,
                scheduledRevision: scheduledRevision
            )
        }
    }

    private func accept(
        _ parsedSnapshot: MarkdownRenderSnapshot,
        scheduledRevision: Int
    ) {
        guard scheduledRevision == revision else { return }
        snapshot = parsedSnapshot
    }

    nonisolated private static func defaultParser(
        source: String,
        isFinal: Bool
    ) -> MarkdownRenderSnapshot {
        let document = Document(parsing: source)
        return MarkdownRenderSnapshot(
            source: source,
            topLevelBlockCount: document.childCount,
            isFinal: isFinal,
            presentationMode:
                MarkdownStreamingFallbackPolicy.presentationMode(
                    for: source,
                    isFinal: isFinal
                )
        )
    }

    deinit {
        parseTask?.cancel()
    }
}
