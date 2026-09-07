//
//  OutsideClickMonitor.swift
//  Y1Y
//

import AppKit

/// Owns the single application-wide monitor for clicks in other applications.
final class OutsideClickMonitor {
    private var monitor: Any?

    func start(onOutsideClick: @escaping () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            onOutsideClick()
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    deinit {
        stop()
    }
}
