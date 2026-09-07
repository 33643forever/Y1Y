//
//  SelectionReader.swift
//  Y1Y
//

import AppKit
import Carbon

enum SelectionReader {
    private static let pollInterval: TimeInterval = 0.02
    private static let maxPollAttempts = 6

    /// Gets the currently selected text by simulating Cmd+C and reading the pasteboard.
    static func getSelectedText(completion: @escaping (String?) -> Void) {
        // Save current pasteboard content
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        simulateCopy()

        pollPasteboard(
            pasteboard: pasteboard,
            previousContents: previousContents,
            previousChangeCount: previousChangeCount,
            attemptsRemaining: maxPollAttempts,
            completion: completion
        )
    }

    private static func pollPasteboard(
        pasteboard: NSPasteboard,
        previousContents: String?,
        previousChangeCount: Int,
        attemptsRemaining: Int,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            let newChangeCount = pasteboard.changeCount
            if newChangeCount != previousChangeCount,
               let text = pasteboard.string(forType: .string) {
                // Restore previous pasteboard content
                pasteboard.clearContents()
                if let prev = previousContents {
                    pasteboard.setString(prev, forType: .string)
                }
                completion(text)
            } else if attemptsRemaining > 1 {
                pollPasteboard(
                    pasteboard: pasteboard,
                    previousContents: previousContents,
                    previousChangeCount: previousChangeCount,
                    attemptsRemaining: attemptsRemaining - 1,
                    completion: completion
                )
            } else {
                completion(nil)
            }
        }
    }

    private static func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+C
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up: Cmd+C
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
