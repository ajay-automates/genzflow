import Foundation
import AppKit
import Carbon

struct PasteTarget {
    let app: NSRunningApplication?
    let focusedElement: AXUIElement?
}

class PasteService {
    func captureTarget(for app: NSRunningApplication?) -> PasteTarget {
        PasteTarget(app: app, focusedElement: captureFocusedElement(for: app))
    }

    func paste(_ text: String, into target: PasteTarget) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if insertViaAccessibility(text, into: target.focusedElement) {
            print("[PasteService] Inserted \(text.count) characters via accessibility")
            return
        }

        target.app?.activate()

        // Give the previously focused app a moment to become active again before inserting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let refreshedElement = self.captureFocusedElement(for: target.app)
            if self.insertViaAccessibility(text, into: refreshedElement) {
                print("[PasteService] Inserted \(text.count) characters via refreshed accessibility target")
                return
            }

            self.simulateCmdV(targetPID: target.app?.processIdentifier)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.pasteViaAppleScript(into: target.app)
            }
        }
        print("[PasteService] Pasted \(text.count) characters")
    }

    private func captureFocusedElement(for app: NSRunningApplication?) -> AXUIElement? {
        if let app {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var focusedElementRef: CFTypeRef?
            let focusedResult = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElementRef
            )
            if focusedResult == .success, let focusedElementRef {
                let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)
                return focusedElement
            }
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        if focusedResult == .success, let focusedElementRef {
            let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)
            return focusedElement
        }
        return nil
    }
    
    private func simulateCmdV(targetPID: pid_t?) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        if let targetPID {
            keyDown?.postToPid(targetPID)
            keyUp?.postToPid(targetPID)
        } else {
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private func insertViaAccessibility(_ text: String, into element: AXUIElement?) -> Bool {
        guard let element else { return false }

        var isSelectedTextSettable = DarwinBoolean(false)
        let selectedTextSettableResult = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &isSelectedTextSettable
        )

        if selectedTextSettableResult == .success && isSelectedTextSettable.boolValue {
            let setResult = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFTypeRef
            )
            if setResult == .success {
                return true
            }
        }

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let currentValue = valueRef as? String else {
            return false
        }

        var selectionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectionRef) == .success,
              let selectionValue = selectionRef,
              CFGetTypeID(selectionValue) == AXValueGetTypeID() else {
            return false
        }

        var range = CFRange()
        guard AXValueGetType(selectionValue as! AXValue) == .cfRange,
              AXValueGetValue(selectionValue as! AXValue, .cfRange, &range) else {
            return false
        }

        let safeLocation = max(0, min(range.location, currentValue.count))
        let safeLength = max(0, min(range.length, currentValue.count - safeLocation))
        let startIndex = currentValue.index(currentValue.startIndex, offsetBy: safeLocation)
        let endIndex = currentValue.index(startIndex, offsetBy: safeLength)
        let updatedValue = currentValue.replacingCharacters(in: startIndex..<endIndex, with: text)

        let setValueResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        )
        guard setValueResult == .success else { return false }

        var newRange = CFRange(location: safeLocation + text.count, length: 0)
        guard let newSelection = AXValueCreate(.cfRange, &newRange) else { return true }
        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            newSelection
        )
        return true
    }

    private func pasteViaAppleScript(into targetApp: NSRunningApplication?) {
        let activationScript: String
        if let bundleIdentifier = targetApp?.bundleIdentifier {
            activationScript = """
            tell application id "\(bundleIdentifier)"
                activate
            end tell
            """
        } else {
            activationScript = ""
        }

        let script = """
        \(activationScript)
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            print("[PasteService] AppleScript paste failed: \(error)")
        }
    }
}
