//
//  PanelSession.swift
//  Y1Y
//

import AppKit
import Combine

/// Owns the mutable state and request lifecycle for one floating panel.
final class PanelSession: ObservableObject, Identifiable {
    let id: UUID
    let selectedText: String
    let aiService: AIService

    @Published var phase: PanelPhase
    @Published var pinState: PinState

    weak var window: NSWindow?

    private var isClosed = false

    init(
        id: UUID = UUID(),
        selectedText: String,
        aiService: AIService = AIService(),
        phase: PanelPhase = .promptList,
        pinState: PinState = .unpinned
    ) {
        self.id = id
        self.selectedText = selectedText
        self.aiService = aiService
        self.phase = phase
        self.pinState = pinState
    }

    func transition(to phase: PanelPhase) {
        self.phase = phase
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        aiService.cancel()
        window?.orderOut(nil)
        window = nil
    }

    deinit {
        aiService.cancel()
    }
}
