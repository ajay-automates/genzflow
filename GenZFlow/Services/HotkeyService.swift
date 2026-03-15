import Foundation
import Carbon

final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x475A464C), id: 1) // "GZFL"
    private let spaceKeyCode: UInt32 = 49

    var onFnKeyDown: (() -> Void)?
    var onFnKeyUp: (() -> Void)?

    func start() -> Bool {
        stop()

        var handler: EventHandlerRef?
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard result == noErr else { return result }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                if hotKeyID.id == service.hotKeyID.id && hotKeyID.signature == service.hotKeyID.signature {
                    DispatchQueue.main.async {
                        service.onFnKeyDown?()
                        service.onFnKeyUp?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        guard status == noErr, let handler else {
            print("[HotkeyService] Failed to install hotkey handler: \(status)")
            return false
        }

        self.eventHandler = handler

        var hotKeyRef: EventHotKeyRef?
        let modifiers = UInt32(controlKey | optionKey)
        let registerStatus = RegisterEventHotKey(
            spaceKeyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr, let hotKeyRef else {
            print("[HotkeyService] Failed to register Control + Option + Space: \(registerStatus)")
            stop()
            return false
        }

        self.hotKeyRef = hotKeyRef
        print("[HotkeyService] Registered global hotkey: Control + Option + Space")
        return true
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    static func hasAccessibilityPermissions() -> Bool {
        true
    }

    deinit {
        stop()
    }
}
