import AppKit
import Markdown
import XCTest
@testable import Y1Y

@MainActor
final class MarkdownAndScrollTests: XCTestCase {
    func testCommonBlockSyntaxParses() {
        let source = """
        # Heading

        Paragraph with **bold**, *italic*, ~~strike~~, `code`, and [link](https://example.com).

        - one
        - two

        > quote

        ---

        ```swift
        let value = 1
        ```
        """

        let summary = MarkdownDependencyCheck.parseSummary(for: source)
        XCTAssertTrue(summary.containsHeading)
        XCTAssertTrue(summary.containsParagraph)
        XCTAssertTrue(summary.containsCodeBlock)
    }

    func testUnsupportedHTMLRemainsReadablePlainText() {
        let document = Document(
            parsing: "<custom-tag>visible fallback</custom-tag>"
        )
        let rendered = MarkdownPlainTextRenderer.text(from: document)

        XCTAssertTrue(rendered.contains("custom-tag"))
        XCTAssertTrue(rendered.contains("visible fallback"))
    }

    func testUnsupportedFootnoteDefinitionIsPreserved() {
        let source = """
        Paragraph[^note]

        [^note]: Footnote fallback
        """

        XCTAssertEqual(
            MarkdownPlainTextRenderer.unsupportedFootnoteDefinitions(
                in: source
            ),
            ["[^note]: Footnote fallback"]
        )
    }

    func testIncompleteStreamingMarkdownFallsBackUntilFinal() {
        let incompleteSources = [
            "```swift\nlet value = 1",
            "**unfinished",
            "[unfinished](https://example.com"
        ]

        for source in incompleteSources {
            XCTAssertEqual(
                MarkdownStreamingFallbackPolicy.presentationMode(
                    for: source,
                    isFinal: false
                ),
                .plainText
            )
            XCTAssertEqual(
                MarkdownStreamingFallbackPolicy.presentationMode(
                    for: source,
                    isFinal: true
                ),
                .markdown
            )
        }

        XCTAssertEqual(
            MarkdownStreamingFallbackPolicy.presentationMode(
                for: "**finished**",
                isFinal: false
            ),
            .markdown
        )
    }

    func testCodeBlockCopyUsesOnlyCodeContent() {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name(
                "Y1YTests.CodeBlock.\(UUID().uuidString)"
            )
        )
        let code = "let answer = 42\nprint(answer)"

        XCTAssertTrue(
            MarkdownCodeBlockCopyAction.copy(code, to: pasteboard)
        )
        XCTAssertEqual(pasteboard.string(forType: .string), code)
        XCTAssertFalse(
            pasteboard.string(forType: .string)?.contains("```") == true
        )
    }

    func testUserScrollingHasPriorityOverAutomaticFollowing() {
        let coordinator = ResponseScrollCoordinator(
            pauseThreshold: 24,
            resumeThreshold: 8
        )

        XCTAssertTrue(coordinator.shouldFollowNewContent)
        coordinator.userDidScroll(distanceFromBottom: 30)
        XCTAssertFalse(coordinator.shouldFollowNewContent)

        coordinator.userDidScroll(distanceFromBottom: 12)
        XCTAssertFalse(coordinator.shouldFollowNewContent)

        coordinator.userDidScroll(distanceFromBottom: 6)
        XCTAssertTrue(coordinator.shouldFollowNewContent)
    }

    func testRenderStoreFinishesWithLatestSource() async {
        let store = MarkdownRenderStore(
            throttleInterval: .milliseconds(20)
        )
        store.update(source: "# old")
        store.update(source: "# latest")
        store.finish()
        await store.waitForPendingRender()

        XCTAssertEqual(store.snapshot.source, "# latest")
        XCTAssertTrue(store.snapshot.isFinal)
        XCTAssertEqual(store.snapshot.presentationMode, .markdown)
    }
}
