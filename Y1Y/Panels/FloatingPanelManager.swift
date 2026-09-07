//
//  FloatingPanelManager.swift
//  Y1Y
//

import AppKit

/// Creates and retains independent floating-panel controllers.
final class FloatingPanelManager {
    private var controllers: [UUID: FloatingPanelController] = [:]
    private let outsideClickMonitor = OutsideClickMonitor()
    private let cascadePlacement: PanelCascadePlacementService

    init(
        cascadePlacement: PanelCascadePlacementService =
            PanelCascadePlacementService()
    ) {
        self.cascadePlacement = cascadePlacement
    }

    var activeSessionCount: Int {
        controllers.count
    }

    @discardableResult
    func show(at point: NSPoint, with selectedText: String) -> UUID {
        startOutsideClickMonitoring()
        let session = PanelSession(selectedText: selectedText)
        let controller = FloatingPanelController(
            session: session,
            onClose: { [weak self] id in
                self?.removeClosedSession(id: id)
            }
        )

        controllers[session.id] = controller
        let listSize = controller.promptListSize()
        let requestedFrame = NSRect(
            x: point.x - listSize.width / 2,
            y: point.y - listSize.height - 10,
            width: listSize.width,
            height: listSize.height
        )
        let visibleFrame = screen(containing: point)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? requestedFrame
        let existingFrames = controllers.values.compactMap {
            $0.session.window?.frame
        }
        let placement = cascadePlacement.nextFrame(
            requestedFrame: requestedFrame,
            existingFrames: existingFrames,
            visibleFrame: visibleFrame
        )
        controller.show(at: point, preferredOrigin: placement.origin)
        return session.id
    }

    func session(id: UUID) -> PanelSession? {
        controllers[id]?.session
    }

    func close(id: UUID) {
        controllers[id]?.close()
    }

    func closeAll() {
        let activeControllers = Array(controllers.values)
        activeControllers.forEach { $0.close() }
    }

    func processOutsideClick() {
        let unpinnedControllers = controllers.values.filter {
            $0.session.pinState == .unpinned
        }
        unpinnedControllers.forEach { $0.close() }
    }

    private func startOutsideClickMonitoring() {
        outsideClickMonitor.start { [weak self] in
            self?.processOutsideClick()
        }
    }

    private func removeClosedSession(id: UUID) {
        controllers[id] = nil
        if controllers.isEmpty {
            outsideClickMonitor.stop()
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}
