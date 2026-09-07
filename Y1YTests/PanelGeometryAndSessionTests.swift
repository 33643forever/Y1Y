import AppKit
import XCTest
@testable import Y1Y

@MainActor
final class PanelGeometryAndSessionTests: XCTestCase {
    func testSizeUsesMinimumAndFiveTimesMaximum() {
        let service = PanelGeometryService()
        let largeScreen = CGRect(x: 0, y: 0, width: 4_000, height: 3_000)

        XCTAssertEqual(
            service.constrainedSize(
                ResponsePanelSize(width: 10, height: 20),
                visibleFrame: largeScreen
            ),
            .defaultSize
        )
        XCTAssertEqual(
            service.constrainedSize(
                ResponsePanelSize(width: 9_000, height: 9_000),
                visibleFrame: largeScreen
            ),
            PanelGeometryService.theoreticalMaximumSize
        )
        XCTAssertEqual(
            PanelGeometryService.theoreticalMaximumSize.width,
            PanelGeometryService.minimumSize.width * 5
        )
        XCTAssertEqual(
            PanelGeometryService.theoreticalMaximumSize.height,
            PanelGeometryService.minimumSize.height * 5
        )
    }

    func testSizeAndPositionStayInsideVisibleFrame() {
        let service = PanelGeometryService()
        let visibleFrame = CGRect(x: 100, y: 80, width: 900, height: 650)
        let requests = [
            CGRect(x: -900, y: -900, width: 100, height: 100),
            CGRect(x: 2_000, y: 2_000, width: 2_000, height: 2_000),
            CGRect(
                x: CGFloat.infinity,
                y: CGFloat.nan,
                width: CGFloat.infinity,
                height: CGFloat.nan
            )
        ]

        for request in requests {
            let result = service.constrainedFrame(
                request,
                to: visibleFrame
            )
            XCTAssertTrue(visibleFrame.contains(result))
            XCTAssertTrue(result.width.isFinite)
            XCTAssertTrue(result.height.isFinite)
        }
    }

    func testBestScreenUsesLargestIntersection() {
        let service = PanelGeometryService()
        let screens = [
            CGRect(x: 0, y: 0, width: 1_000, height: 800),
            CGRect(x: 1_000, y: 0, width: 1_200, height: 900)
        ]
        let mostlySecondScreen = CGRect(
            x: 900,
            y: 100,
            width: 700,
            height: 500
        )

        XCTAssertEqual(
            service.primaryScreenIndex(
                for: mostlySecondScreen,
                visibleFrames: screens
            ),
            1
        )
        XCTAssertTrue(
            screens[1].contains(
                service.constrainedFrame(
                    mostlySecondScreen,
                    toBestVisibleFrame: screens
                )
            )
        )
    }

    func testCascadeProducesDistinctVisibleOriginsAndTerminatesWhenDense() {
        let service = PanelCascadePlacementService()
        let visibleFrame = CGRect(x: 0, y: 0, width: 900, height: 700)
        let requestedFrame = CGRect(x: 300, y: 300, width: 280, height: 220)
        var frames: [CGRect] = []

        for _ in 0..<12 {
            let next = service.nextFrame(
                requestedFrame: requestedFrame,
                existingFrames: frames,
                visibleFrame: visibleFrame
            )
            XCTAssertTrue(visibleFrame.contains(next))
            XCTAssertFalse(frames.contains { $0.origin == next.origin })
            frames.append(next)
        }

        let onlyFrame = CGRect(x: 0, y: 0, width: 280, height: 220)
        XCTAssertEqual(
            service.nextFrame(
                requestedFrame: onlyFrame,
                existingFrames: Array(repeating: onlyFrame, count: 100),
                visibleFrame: onlyFrame
            ),
            onlyFrame
        )
    }

    func testSessionsKeepStateAndCancellationIndependent() {
        let firstService = AIService()
        let secondService = AIService()
        let first = PanelSession(
            selectedText: "first",
            aiService: firstService
        )
        let second = PanelSession(
            selectedText: "second",
            aiService: secondService
        )

        firstService.responseText = "first response"
        firstService.errorMessage = "first error"
        firstService.isLoading = true
        secondService.responseText = "second response"
        secondService.isLoading = true
        first.pinState = .pinned
        first.transition(to: .response)

        first.close()

        XCTAssertFalse(firstService.isLoading)
        XCTAssertTrue(secondService.isLoading)
        XCTAssertEqual(secondService.responseText, "second response")
        XCTAssertNil(secondService.errorMessage)
        XCTAssertEqual(second.pinState, .unpinned)
        XCTAssertEqual(second.phase, .promptList)
    }

    func testManagerRemovesOnlyClosedSession() {
        let manager = FloatingPanelManager()
        let point = NSEvent.mouseLocation
        let firstID = manager.show(at: point, with: "first")
        let secondID = manager.show(at: point, with: "second")
        defer { manager.closeAll() }

        XCTAssertEqual(manager.activeSessionCount, 2)
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertNotNil(manager.session(id: firstID)?.window)
        XCTAssertNotNil(manager.session(id: secondID)?.window)

        manager.close(id: firstID)

        XCTAssertEqual(manager.activeSessionCount, 1)
        XCTAssertNil(manager.session(id: firstID))
        XCTAssertNotNil(manager.session(id: secondID))
        XCTAssertTrue(manager.session(id: secondID)?.window?.isVisible == true)
    }
}
