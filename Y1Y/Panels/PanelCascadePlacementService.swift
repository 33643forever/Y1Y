//
//  PanelCascadePlacementService.swift
//  Y1Y
//

import CoreGraphics

struct PanelCascadePlacementService {
    static let offset: CGFloat = 24

    private let geometryService: PanelGeometryService

    init(geometryService: PanelGeometryService = PanelGeometryService()) {
        self.geometryService = geometryService
    }

    func nextFrame(
        requestedFrame: CGRect,
        existingFrames: [CGRect],
        visibleFrame: CGRect
    ) -> CGRect {
        let baseFrame = geometryService.constrainedFrame(
            requestedFrame,
            to: visibleFrame
        )
        guard existingFrames.contains(where: { sameOrigin($0, baseFrame) })
        else {
            return baseFrame
        }

        for step in 1...max(existingFrames.count + 1, 1) {
            let diagonalCandidate = CGRect(
                x: baseFrame.minX + CGFloat(step) * Self.offset,
                y: baseFrame.minY - CGFloat(step) * Self.offset,
                width: baseFrame.width,
                height: baseFrame.height
            )
            let constrainedCandidate = geometryService.constrainedFrame(
                diagonalCandidate,
                to: visibleFrame
            )
            if !existingFrames.contains(where: {
                sameOrigin($0, constrainedCandidate)
            }) {
                return constrainedCandidate
            }
        }

        let availableWidth = max(0, visibleFrame.width - baseFrame.width)
        let availableHeight = max(0, visibleFrame.height - baseFrame.height)
        let columnCount = max(
            1,
            Int(availableWidth / Self.offset) + 1
        )
        let rowCount = max(
            1,
            Int(availableHeight / Self.offset) + 1
        )
        let maximumAttempts = min(
            max(existingFrames.count + 1, 1),
            columnCount * rowCount
        )

        for step in 1...maximumAttempts {
            let column = step % columnCount
            let row = (step / columnCount) % rowCount
            let candidate = CGRect(
                x: visibleFrame.minX + CGFloat(column) * Self.offset,
                y: visibleFrame.maxY
                    - baseFrame.height
                    - CGFloat(row) * Self.offset,
                width: baseFrame.width,
                height: baseFrame.height
            )
            let constrainedCandidate = geometryService.constrainedFrame(
                candidate,
                to: visibleFrame
            )
            if !existingFrames.contains(where: {
                sameOrigin($0, constrainedCandidate)
            }) {
                return constrainedCandidate
            }
        }

        return baseFrame
    }

    private func sameOrigin(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 0.5
            && abs(lhs.minY - rhs.minY) < 0.5
    }
}
