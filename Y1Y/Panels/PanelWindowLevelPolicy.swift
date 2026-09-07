//
//  PanelWindowLevelPolicy.swift
//  Y1Y
//

import AppKit

enum PanelWindowLevelPolicy {
    static func apply(_ pinState: PinState, to window: NSWindow) {
        switch pinState {
        case .unpinned:
            window.level = .normal
            window.hidesOnDeactivate = true
        case .pinned:
            window.level = .floating
            window.hidesOnDeactivate = false
        }
    }
}
