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

            if self.performPasteMenuAction(in: target.app) {
                print("[PasteService] Triggered Paste menu action")
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
                return resolveEditableElement(from: focusedElement)
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
            return resolveEditableElement(from: focusedElement)
        }
        return nil
    }

    private func resolveEditableElement(from element: AXUIElement) -> AXUIElement {
        if let highestEditableAncestor = copyElementAttribute(
            kAXHighestEditableAncestorAttribute as CFString,
            from: element
        ) {
            return highestEditableAncestor
        }

        if let editableAncestor = copyElementAttribute(
            kAXEditableAncestorAttribute as CFString,
            from: element
        ) {
            return editableAncestor
        }

        return element
    }

    private func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success, let valueRef else { return nil }
        return unsafeBitCast(valueRef, to: AXUIElement.self)
    }

    private func copyChildren(of element: AXUIElement) -> [AXUIElement] {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &valueRef)
        guard result == .success, let values = valueRef as? [Any] else { return [] }
        return values.map { unsafeBitCast($0 as AnyObject, to: AXUIElement.self) }
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        guard result == .success else { return nil }
        return valueRef as? String
    }

    private func copyMenuItemModifiers(from element: AXUIElement) -> Int? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXMenuItemCmdModifiersAttribute as CFString,
            &valueRef
        )
        guard result == .success, let number = valueRef as? NSNumber else { return nil }
        return number.intValue
    }

    private func performPasteMenuAction(in targetApp: NSRunningApplication?) -> Bool {
        guard let targetApp else { return false }

        let applicationElement = AXUIElementCreateApplication(targetApp.processIdentifier)
        var menuBarRef: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXMenuBarAttribute as CFString,
            &menuBarRef
        )

        guard menuBarResult == .success, let menuBarRef else { return false }
        let menuBar = unsafeBitCast(menuBarRef, to: AXUIElement.self)
        guard let pasteMenuItem = findPasteMenuItem(in: menuBar) else { return false }
        return AXUIElementPerformAction(pasteMenuItem, kAXPressAction as CFString) == .success
    }

    private func findPasteMenuItem(in root: AXUIElement) -> AXUIElement? {
        var queue = [root]

        while let element = queue.first {
            queue.removeFirst()

            let title = copyStringAttribute(kAXTitleAttribute as CFString, from: element)?.lowercased()
            let commandChar = copyStringAttribute(kAXMenuItemCmdCharAttribute as CFString, from: element)?.lowercased()
            let modifiers = copyMenuItemModifiers(from: element)

            let isPasteTitle = title == "paste"
            let isPasteShortcut = commandChar == "v" && (modifiers == nil || modifiers == 0)

            if isPasteTitle || isPasteShortcut {
                return element
            }

            queue.append(contentsOf: copyChildren(of: element))
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

        guard let range = copySelectionRange(from: element) else {
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

    private func copySelectionRange(from element: AXUIElement) -> CFRange? {
        var selectionRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectionRef
        )
        if rangeResult == .success,
           let selectionRef,
           let range = cfRange(from: selectionRef) {
            return range
        }

        var rangesRef: CFTypeRef?
        let rangesResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangesAttribute as CFString,
            &rangesRef
        )
        if rangesResult == .success,
           let ranges = rangesRef as? [Any],
           let firstRange = ranges.first {
            return cfRange(from: firstRange as CFTypeRef)
        }

        return nil
    }

    private func cfRange(from value: CFTypeRef) -> CFRange? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }

        var range = CFRange()
        return AXValueGetValue(axValue, .cfRange, &range) ? range : nil
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
