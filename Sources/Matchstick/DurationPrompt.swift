import AppKit

/// A small dialog that asks how long to keep the Mac awake.
@MainActor
enum DurationPrompt {
    private static let lastDurationKey = "customDuration"
    private static let firstSuggestion: TimeInterval = 90 * 60

    /// A date picker edits a time of day. Counted from this moment in UTC,
    /// the time it shows is the duration itself: 01:30 is 90 minutes.
    private static let midnight = Date(timeIntervalSinceReferenceDate: 0)

    /// Returns the chosen duration in seconds, or `nil` if the dialog was
    /// cancelled. The choice is remembered for next time.
    static func run(defaults: UserDefaults = .standard) -> TimeInterval? {
        let remembered = defaults.double(forKey: lastDurationKey)
        let picker = makePicker(showing: remembered > 0 ? remembered : firstSuggestion)

        let alert = NSAlert()
        alert.messageText = "Keep awake for how long?"
        alert.informativeText = "Hours and minutes, up to 23:59."
        alert.accessoryView = picker
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = picker

        // An app without a Dock icon only gets the keyboard if its window is
        // already on screen when it activates itself. The unhide comes first,
        // or the dialog would not get the keyboard the second time.
        NSApp.unhide(nil)
        alert.layout()
        alert.window.center()
        alert.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        // Hiding the app hands the keyboard back to the app the user was in.
        // It would also hide an open About panel, so in that case it stays.
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeKey }) {
            NSApp.hide(nil)
        }

        guard response == .alertFirstButtonReturn else { return nil }
        // A digit typed just before a click on Start is shown in the field
        // but not in its value yet. Giving up the keyboard puts it there.
        alert.window.makeFirstResponder(nil)
        let duration = picker.dateValue.timeIntervalSince(midnight)
        defaults.set(duration, forKey: lastDurationKey)
        return duration
    }

    private static func makePicker(showing duration: TimeInterval) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        // UTC keeps the local time zone out of the value, and a 24 hour
        // locale keeps AM and PM out of the field.
        picker.timeZone = TimeZone(secondsFromGMT: 0)
        picker.locale = Locale(identifier: "en_GB")
        picker.minDate = midnight.addingTimeInterval(60)
        picker.maxDate = midnight.addingTimeInterval(24 * 60 * 60 - 60)
        picker.dateValue = midnight.addingTimeInterval(duration)
        // VoiceOver reads the label from the cell, not from the picker.
        picker.cell?.setAccessibilityLabel("Hours and minutes")
        picker.sizeToFit()
        return picker
    }
}
