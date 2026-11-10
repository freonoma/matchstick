import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let durations: [(title: String, seconds: TimeInterval)] = {
        var durations: [(String, TimeInterval)] = [
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60),
            ("2 hours", 2 * 60 * 60),
        ]
        #if DEBUG
        durations.insert(("1 minute", 60), at: 0)
        #endif
        return durations
    }()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let stats = Stats()
    private lazy var awake = AwakeController(stats: stats)
    private var shownIcon: MatchIcon?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        awake.onChange = { [weak self] in self?.updateStatusItem() }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        awake.stop()
    }

    // MARK: - Status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if wantsMenu {
            showMenu()
        } else {
            awake.toggle()
        }
    }

    /// A status item with a menu opens it on every click, and a left click
    /// should only toggle. So the menu is attached just for this one click
    /// and removed again in `menuDidClose`.
    private func showMenu() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    private func updateStatusItem() {
        let icon = MatchIcon(isLit: awake.isOn, fractionLeft: awake.session?.fractionLeft())
        guard icon != shownIcon, let button = statusItem.button else { return }
        shownIcon = icon

        let label = awake.isOn ? "Matchstick: on" : "Matchstick: off"
        button.image = icon.image
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        awake.refresh()
        rebuildMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addItem(statusLine)
        if awake.isOn {
            addItem("Turn off", action: #selector(turnOff))
        }

        menu.addItem(.separator())
        for duration in Self.durations {
            addItem("Keep awake for \(duration.title)", action: #selector(keepAwake))
                .representedObject = duration.seconds
        }
        addItem("Keep awake for…", action: #selector(keepAwakeForCustomDuration))
        addItem("Keep awake until I turn it off", action: #selector(keepAwake))

        menu.addItem(.separator())
        addItem("Let the screen turn off", action: #selector(toggleDisplaySleep))
            .state = awake.allowsDisplaySleep ? .on : .off

        menu.addItem(.separator())
        addItem(statsLine)

        menu.addItem(.separator())
        addItem("Launch at login", action: #selector(toggleLaunchAtLogin))
            .state = SMAppService.mainApp.status == .enabled ? .on : .off
        addItem("About Matchstick", action: #selector(showAbout))
        addItem("Quit Matchstick", action: #selector(quit), key: "q")
    }

    /// Items without an action are shown disabled, as plain text lines.
    @discardableResult
    private func addItem(_ title: String, action: Selector? = nil, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    private var statusLine: String {
        guard let session = awake.session else { return "Off" }
        guard let timeLeft = session.timeLeft() else { return "On until you turn it off" }
        let minutes = Int((timeLeft / 60).rounded(.up))
        return "On, \(Stats.format(minutes: minutes)) left"
    }

    private var statsLine: String {
        let today = Stats.format(minutes: Int(stats.today() / 60))
        let week = Stats.format(minutes: Int(stats.thisWeek() / 60))
        return "Today \(today) · This week \(week)"
    }

    // MARK: - Actions

    @objc private func turnOff() {
        awake.stop()
    }

    /// The duration is the item's represented object. Without one, the
    /// session has no time limit.
    @objc private func keepAwake(_ sender: NSMenuItem) {
        awake.start(for: sender.representedObject as? TimeInterval)
    }

    /// The dialog opens on the next pass of the run loop. By then the menu
    /// has closed and the match is no longer highlighted.
    @objc private func keepAwakeForCustomDuration() {
        perform(#selector(askForCustomDuration), with: nil, afterDelay: 0)
    }

    @objc private func askForCustomDuration() {
        if let duration = DurationPrompt.run() {
            awake.start(for: duration)
        }
    }

    @objc private func toggleDisplaySleep() {
        awake.allowsDisplaySleep.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Matchstick: could not change the login item: \(error.localizedDescription)")
        }

        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc private func showAbout() {
        AboutPanel.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
