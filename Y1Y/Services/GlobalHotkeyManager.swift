//
//  GlobalHotkeyManager.swift
//  Y1Y
//

import Carbon
import AppKit

class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let callback: () -> Void

    private static var activeInstance: GlobalHotkeyManager?

    init(callback: @escaping () -> Void) {
        self.callback = callback
        GlobalHotkeyManager.activeInstance = self
    }

    deinit {
        stop()
        if GlobalHotkeyManager.activeInstance === self {
            GlobalHotkeyManager.activeInstance = nil
        }
    }

    func start() {
        stop()

        // 1. Install Carbon event handler first
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerCallback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let instance = GlobalHotkeyManager.activeInstance else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async {
                instance.callback()
            }
            return noErr
        }

        var status = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else {
            print("[Y1Y] InstallEventHandler failed: \(status)")
            return
        }
        print("[Y1Y] Event handler installed successfully")

        // 2. Register the hotkey: Command + E
        let hotkeyID = EventHotKeyID(signature: OSType(0x48595831), id: 1)

        status = RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            UInt32(cmdKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            print("[Y1Y] Hotkey ⌘E registered successfully")
        } else {
            print("[Y1Y] RegisterEventHotKey failed: \(status)")
        }
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
