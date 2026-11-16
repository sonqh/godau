import ApplicationServices
import Foundation

enum FieldUnavailableReason: String, Equatable {
    case notInspected
    case noFocusedElement
    case unsupportedRole
    case secureField
    case noSelectedRange
    case noCharacterCount
}

enum FieldReading: Equatable {
    case caret(FieldSnapshot)
    case selection
    case unavailable(FieldUnavailableReason)
}

/// Metadata for the diagnostic trace. Contains no document text.
struct FocusInspection {
    let changed: Bool
    let field: FieldReading
    var role: String? = nil
    var elementHash: UInt? = nil
    /// The focused element is a browser address bar (`addressBar` profile, Son 2026-11-15). Its trailing
    /// inline completion is reported as a caret at the completion start, with the completion left out.
    var addressBar = false
    /// An address bar showed an inline completion in this reading.
    var completionShown = false
}

/// Reads identity, selected range, and character count only, never document or typed text.
/// Called on the owning run loop outside the keyboard callback.
@MainActor
final class FocusMonitor {
    private(set) var element: AXUIElement?
    private var application: AXUIElement?
    private var observer: AXObserver?
    private var pid: pid_t = 0
    private var bundleID: String?
    /// Address-bar identity of `element`, resolved once per focused-element change.
    private var elementIsAddressBar = false
    var onNotification: (() -> Void)?

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        application = nil
        element = nil
        pid = 0
    }

    func inspect(pid nextPID: pid_t, bundleID nextBundle: String? = nil, allowed: Bool) -> FocusInspection {
        bundleID = nextBundle
        guard allowed, nextPID > 0 else {
            let changed = element != nil
            stop()
            return FocusInspection(changed: changed, field: .unavailable(.notInspected))
        }
        if pid != nextPID {
            stop()
            pid = nextPID
            application = AXUIElementCreateApplication(pid)
            // Bound blocking AX calls outside the key path.
            AXUIElementSetMessagingTimeout(application!, 0.05)
            var created: AXObserver?
            let result = AXObserverCreate(pid, { _, _, _, pointer in
                guard let pointer else { return }
                MainActor.assumeIsolated {
                    Unmanaged<FocusMonitor>.fromOpaque(pointer).takeUnretainedValue().onNotification?()
                }
            }, &created)
            if result == .success, let created {
                observer = created
                let pointer = Unmanaged.passUnretained(self).toOpaque()
                AXObserverAddNotification(created, application!, kAXFocusedUIElementChangedNotification as CFString, pointer)
                AXObserverAddNotification(created, application!, kAXFocusedWindowChangedNotification as CFString, pointer)
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            }
        }
        guard let application else { return FocusInspection(changed: false, field: .unavailable(.noFocusedElement)) }
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return FocusInspection(changed: true, field: .unavailable(.noFocusedElement))
        }
        let focused = raw as! AXUIElement
        let changed = element.map { !CFEqual($0, focused) } ?? true
        if changed {
            if let observer, let element {
                for name in Self.elementNotifications { AXObserverRemoveNotification(observer, element, name) }
            }
            element = focused
            AXUIElementSetMessagingTimeout(focused, 0.05)
            elementIsAddressBar = Self.isAddressBar(focused, bundleID: bundleID)
            if let observer {
                // Value changes can be external edits that keep the same caret.
                for name in Self.elementNotifications {
                    AXObserverAddNotification(observer, focused, name, Unmanaged.passUnretained(self).toOpaque())
                }
            }
        }
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
        let roleName = role as? String
        let addressBar = elementIsAddressBar
        func result(_ field: FieldReading, completion: Bool = false) -> FocusInspection {
            FocusInspection(changed: changed, field: field, role: roleName, elementHash: CFHash(focused),
                            addressBar: addressBar, completionShown: completion)
        }
        guard let roleName, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(roleName) else {
            return result(.unavailable(.unsupportedRole))
        }
        guard subrole as? String != kAXSecureTextFieldSubrole else { return result(.unavailable(.secureField)) }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return result(.unavailable(.noSelectedRange))
        }
        let value = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetType(value) == .cfRange, AXValueGetValue(value, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return result(.unavailable(.noSelectedRange)) }
        // A count, not content. Without it a same-caret external edit is unobservable.
        var count: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXNumberOfCharactersAttribute as CFString, &count) == .success,
              let length = count as? Int, length >= range.location else {
            return result(range.length == 0 ? .unavailable(.noCharacterCount) : .selection)
        }
        if range.length > 0 {
            // In an address bar a selection that runs to the end is the inline completion: report the caret at
            // its start and leave the completion out of the length.
            guard addressBar, range.location + range.length == length else { return result(.selection) }
            return result(.caret(FieldSnapshot(caret: range.location, length: range.location)), completion: true)
        }
        return result(.caret(FieldSnapshot(caret: range.location, length: length)))
    }

    /// Browsers whose address bar has the `addressBar` profile.
    static let addressBarBrowsers: Set<String> = ["com.google.Chrome", "company.thebrowser.dia", "com.apple.Safari"]

    /// Identifies a browser address bar from role, identifier, description, and ancestor roles. Never text.
    static func isAddressBar(_ element: AXUIElement, bundleID: String?) -> Bool {
        guard let bundleID, addressBarBrowsers.contains(bundleID) else { return false }
        func string(_ target: AXUIElement, _ name: String) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(target, name as CFString, &value) == .success else { return nil }
            return value as? String
        }
        let role = string(element, kAXRoleAttribute)
        guard role == kAXTextFieldRole || role == kAXTextAreaRole else { return false }
        switch string(element, kAXIdentifierAttribute) {
        case "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD", "commandBarTextField": return true
        default: break
        }
        guard bundleID == "com.google.Chrome", role == kAXTextFieldRole else { return false }
        if string(element, kAXDescriptionAttribute) == "Address and search bar" { return true }
        // Other UI languages: the omnibox is the text field inside the window toolbar. Bounded walk.
        var current = element
        for _ in 0..<8 {
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { return false }
            current = parent as! AXUIElement
            let parentRole = string(current, kAXRoleAttribute)
            if parentRole == kAXToolbarRole { return true }
            if parentRole == "AXWebArea" || parentRole == kAXWindowRole { return false }
        }
        return false
    }

    private static let elementNotifications = [kAXSelectedTextChangedNotification as CFString,
                                               kAXValueChangedNotification as CFString]
}
