//
//  FloatingPanelController.swift
//  Y1Y
//

import AppKit
import Combine
import SwiftUI

/// Custom NSPanel that can become key window to receive keyboard events
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class FloatingPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    let session: PanelSession
    private let preferencesStore: PanelPreferencesStore
    private let geometryService: PanelGeometryService
    private let sizePersistence: PanelSizePersistenceCoordinator
    private let onClose: (UUID) -> Void
    private var currentPhase: PanelPhase = .promptList
    private var moveCorrectionTask: Task<Void, Never>?
    private var isCorrectingGeometry = false
    private var hasClosed = false
    private var pinStateObservation: AnyCancellable?
    private var phaseObservation: AnyCancellable?

    init(
        session: PanelSession,
        preferencesStore: PanelPreferencesStore = PanelPreferencesStore(),
        geometryService: PanelGeometryService = PanelGeometryService(),
        onClose: @escaping (UUID) -> Void = { _ in }
    ) {
        self.session = session
        self.preferencesStore = preferencesStore
        self.geometryService = geometryService
        self.onClose = onClose
        sizePersistence = PanelSizePersistenceCoordinator(
            preferencesStore: preferencesStore
        )
        super.init()
        pinStateObservation = session.$pinState
            .removeDuplicates()
            .sink { [weak self] pinState in
                self?.applyPinState(pinState)
            }
        phaseObservation = session.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                self?.applyPhase(phase)
            }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show(at point: NSPoint, preferredOrigin: NSPoint? = nil) {
        let listSize = promptListSize()

        let view = PanelSessionRootView(
            session: session,
            onClose: { [weak self] in self?.close() },
            onPhaseChange: { [session] phase in
                session.transition(to: phase)
            }
        )

        let hostingView = NSHostingView(rootView: view)

        let panel = KeyablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: listSize.width,
                height: listSize.height
            ),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        configure(panel, for: .promptList)

        // Position near mouse cursor
        let panelOrigin = preferredOrigin ?? NSPoint(
            x: point.x - listSize.width / 2,
            y: point.y - listSize.height - 10
        )
        panel.setFrameOrigin(panelOrigin)
        self.panel = panel
        session.window = panel
        applyPhase(session.phase)
        applyPinState(session.pinState)
        constrainPanelToVisibleScreen()

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        guard !hasClosed else { return }
        hasClosed = true
        moveCorrectionTask?.cancel()
        moveCorrectionTask = nil
        panel?.delegate = nil
        session.close()
        panel = nil
        onClose(session.id)
    }

    func promptListSize() -> NSSize {
        let promptCount = SettingsManager.shared.customPrompts.count
        let listHeight = CGFloat(32 + promptCount * 30 + 8 + 54)
        return NSSize(width: 210, height: min(listHeight, 300))
    }

    func configure(_ panel: NSPanel, for phase: PanelPhase) {
        switch phase {
        case .promptList:
            let listSize = promptListSize()
            PanelResizeCapability.apply(
                isResizable: false,
                minimumSize: listSize,
                maximumSize: listSize,
                to: panel
            )
        case .response:
            guard let visibleFrame = targetVisibleFrame(for: panel) else {
                return
            }
            let savedSize = preferencesStore.loadResponsePanelSize()
            let constrainedSize = geometryService.constrainedSize(
                savedSize,
                visibleFrame: visibleFrame
            )
            let maximumSize = geometryService.constrainedSize(
                PanelGeometryService.theoreticalMaximumSize,
                visibleFrame: visibleFrame
            )
            let minimumSize = geometryService.constrainedSize(
                PanelGeometryService.minimumSize,
                visibleFrame: visibleFrame
            )

            PanelResizeCapability.apply(
                isResizable: true,
                minimumSize: NSSize(
                    width: minimumSize.width,
                    height: minimumSize.height
                ),
                maximumSize: NSSize(
                    width: maximumSize.width,
                    height: maximumSize.height
                ),
                to: panel
            )
            resizePanel(
                panel,
                to: NSSize(
                    width: constrainedSize.width,
                    height: constrainedSize.height
                )
            )
        }
    }

    private func applyPhase(_ phase: PanelPhase) {
        guard let panel else { return }
        currentPhase = phase
        configure(panel, for: phase)

        if phase == .promptList {
            let listSize = promptListSize()
            let sizeAlreadyMatches =
                abs(panel.frame.width - listSize.width) < 0.5
                && abs(panel.frame.height - listSize.height) < 0.5
            if !sizeAlreadyMatches {
                resizePanel(panel, to: listSize)
            }
        }
    }

    private func applyPinState(_ pinState: PinState) {
        guard let panel else { return }
        PanelWindowLevelPolicy.apply(pinState, to: panel)
    }

    private func resizePanel(_ panel: NSPanel, to size: NSSize) {
        let frame = panel.frame
        let requestedFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y + frame.height - size.height,
            width: size.width,
            height: size.height
        )
        let visibleFrame = targetVisibleFrame(for: panel) ?? requestedFrame
        let newFrame = geometryService.constrainedFrame(
            requestedFrame,
            to: visibleFrame
        )
        panel.setFrame(newFrame, display: true, animate: true)
    }

    private func targetVisibleFrame(for panel: NSPanel) -> NSRect? {
        geometryService.primaryScreen(for: panel.frame)?.visibleFrame
            ?? panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let resizedPanel = notification.object as? NSPanel,
              resizedPanel === panel
        else {
            return
        }

        constrainPanelToVisibleScreen()
        sizePersistence.recordUserResize(
            resizedPanel.frame.size,
            phase: currentPhase
        )
    }

    func windowDidMove(_ notification: Notification) {
        guard !isCorrectingGeometry,
              let movedPanel = notification.object as? NSPanel,
              movedPanel === panel
        else {
            return
        }

        moveCorrectionTask?.cancel()
        moveCorrectionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.constrainPanelToVisibleScreen()
        }
    }

    @objc
    private func screenParametersDidChange() {
        constrainPanelToVisibleScreen()
    }

    private func constrainPanelToVisibleScreen() {
        guard let panel, !isCorrectingGeometry else { return }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard !visibleFrames.isEmpty else { return }

        let correctedFrame = geometryService.constrainedFrame(
            panel.frame,
            toBestVisibleFrame: visibleFrames
        )
        guard correctedFrame != panel.frame else { return }

        isCorrectingGeometry = true
        panel.setFrame(correctedFrame, display: true)
        isCorrectingGeometry = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        moveCorrectionTask?.cancel()
    }
}

private struct PanelSessionRootView: View {
    @ObservedObject var session: PanelSession
    let onClose: () -> Void
    let onPhaseChange: (PanelPhase) -> Void

    var body: some View {
        PresetPromptView(
            selectedText: session.selectedText,
            aiService: session.aiService,
            pinState: $session.pinState,
            onClose: onClose,
            onPhaseChange: onPhaseChange
        )
    }
}
