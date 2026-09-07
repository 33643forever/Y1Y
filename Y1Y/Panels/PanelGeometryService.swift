import AppKit
import CoreGraphics

struct PanelGeometryService {
    static let minimumSize = ResponsePanelSize(width: 380, height: 360)
    static let theoreticalMaximumSize = ResponsePanelSize(
        width: 1_900,
        height: 1_800
    )

    func constrainedSize(
        _ requestedSize: ResponsePanelSize,
        visibleFrame: CGRect
    ) -> ResponsePanelSize {
        let availableWidth = max(0, visibleFrame.width)
        let availableHeight = max(0, visibleFrame.height)
        let maximumWidth = min(
            Self.theoreticalMaximumSize.width,
            availableWidth
        )
        let maximumHeight = min(
            Self.theoreticalMaximumSize.height,
            availableHeight
        )
        let minimumWidth = min(Self.minimumSize.width, maximumWidth)
        let minimumHeight = min(Self.minimumSize.height, maximumHeight)

        return ResponsePanelSize(
            width: clamp(
                sanitized(requestedSize.width, fallback: minimumWidth),
                lowerBound: minimumWidth,
                upperBound: maximumWidth
            ),
            height: clamp(
                sanitized(requestedSize.height, fallback: minimumHeight),
                lowerBound: minimumHeight,
                upperBound: maximumHeight
            )
        )
    }

    func constrainedFrame(_ requestedFrame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let size = constrainedSize(
            ResponsePanelSize(
                width: requestedFrame.width,
                height: requestedFrame.height
            ),
            visibleFrame: visibleFrame
        )
        let maximumX = visibleFrame.maxX - size.width
        let maximumY = visibleFrame.maxY - size.height

        return CGRect(
            x: clamp(
                sanitized(requestedFrame.minX, fallback: visibleFrame.minX),
                lowerBound: visibleFrame.minX,
                upperBound: maximumX
            ),
            y: clamp(
                sanitized(requestedFrame.minY, fallback: visibleFrame.minY),
                lowerBound: visibleFrame.minY,
                upperBound: maximumY
            ),
            width: size.width,
            height: size.height
        )
    }

    func constrainedFrame(
        _ requestedFrame: CGRect,
        toBestVisibleFrame visibleFrames: [CGRect]
    ) -> CGRect {
        guard let screenIndex = primaryScreenIndex(
            for: requestedFrame,
            visibleFrames: visibleFrames
        ) else {
            return requestedFrame
        }

        return constrainedFrame(
            requestedFrame,
            to: visibleFrames[screenIndex]
        )
    }

    func primaryScreenIndex(
        for frame: CGRect,
        visibleFrames: [CGRect]
    ) -> Int? {
        guard !visibleFrames.isEmpty else { return nil }

        let intersectionAreas = visibleFrames.map { visibleFrame in
            let intersection = frame.intersection(visibleFrame)
            guard !intersection.isNull else { return CGFloat.zero }
            return max(0, intersection.width) * max(0, intersection.height)
        }

        if let largestArea = intersectionAreas.max(), largestArea > 0 {
            return intersectionAreas.firstIndex(of: largestArea)
        }

        let frameCenter = CGPoint(x: frame.midX, y: frame.midY)
        return visibleFrames.indices.min { leftIndex, rightIndex in
            squaredDistance(
                from: frameCenter,
                to: CGPoint(
                    x: visibleFrames[leftIndex].midX,
                    y: visibleFrames[leftIndex].midY
                )
            ) < squaredDistance(
                from: frameCenter,
                to: CGPoint(
                    x: visibleFrames[rightIndex].midX,
                    y: visibleFrames[rightIndex].midY
                )
            )
        }
    }

    func primaryScreen(
        for frame: CGRect,
        screens: [NSScreen] = NSScreen.screens
    ) -> NSScreen? {
        guard let index = primaryScreenIndex(
            for: frame,
            visibleFrames: screens.map(\.visibleFrame)
        ) else {
            return nil
        }

        return screens[index]
    }

    private func sanitized(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        value.isFinite ? value : fallback
    }

    private func clamp(
        _ value: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        guard upperBound >= lowerBound else { return lowerBound }
        return min(max(value, lowerBound), upperBound)
    }

    private func squaredDistance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let deltaX = first.x - second.x
        let deltaY = first.y - second.y
        return deltaX * deltaX + deltaY * deltaY
    }
}
