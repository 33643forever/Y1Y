import AppKit

enum PanelResizeCapability {
    static func apply(
        isResizable: Bool,
        minimumSize: NSSize,
        maximumSize: NSSize,
        to panel: NSPanel
    ) {
        if isResizable {
            panel.styleMask.insert(.resizable)
        } else {
            panel.styleMask.remove(.resizable)
        }

        panel.minSize = minimumSize
        panel.maxSize = maximumSize
    }
}
