import AppKit
import IOKit.pwr_mgt

/// Keeps the Mac awake with IOKit power assertions and tracks the session.
///
/// The assertions belong to this process, so macOS drops them when the app
/// quits or crashes. The Mac can't be left stuck awake.
@MainActor
final class AwakeController: NSObject {
    struct Session {
        let start: Date
        /// `nil` when the session runs until it is turned off.
        let end: Date?

        func timeLeft(at now: Date = Date()) -> TimeInterval? {
            end.map { max(0, $0.timeIntervalSince(now)) }
        }

        /// 1 at the start of a timed session, 0 at the end.
        func fractionLeft(at now: Date = Date()) -> Double? {
            guard let end, let left = timeLeft(at: now) else { return nil }
            let length = end.timeIntervalSince(start)
            return length > 0 ? left / length : 0
        }
    }

    private static let assertionName = "Matchstick is keeping your Mac awake"
    private static let displaySleepKey = "allowsDisplaySleep"
    private static let tickInterval: TimeInterval = 30

    private(set) var session: Session?
    var isOn: Bool { session != nil }

    /// Called whenever the session starts, stops or moves forward.
    var onChange: (() -> Void)?

    private let stats: Stats
    private let defaults: UserDefaults
    private var assertions: [IOPMAssertionID] = []
    private var timer: Timer?
    /// Start of the stretch that hasn't been added to the stats yet.
    /// `nil` while off and while the Mac sleeps.
    private var countedSince: Date?

    init(stats: Stats, defaults: UserDefaults = .standard) {
        self.stats = stats
        self.defaults = defaults
        super.init()

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake),
                              name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// When set, only system sleep is prevented and the screen may turn off.
    var allowsDisplaySleep: Bool {
        get { defaults.bool(forKey: Self.displaySleepKey) }
        set {
            defaults.set(newValue, forKey: Self.displaySleepKey)
            if isOn { holdAssertions() }
        }
    }

    func toggle() {
        if isOn { stop() } else { start() }
    }

    /// Starts a session, or restarts the current one from now.
    /// Without a duration it runs until `stop()`.
    func start(for duration: TimeInterval? = nil) {
        recordElapsed()

        let now = Date()
        let session = Session(start: now, end: duration.map(now.addingTimeInterval))
        self.session = session
        countedSince = now

        holdAssertions()
        startTimer(for: session)
        onChange?()
    }

    func stop() {
        guard isOn else { return }
        recordElapsed()

        session = nil
        countedSince = nil
        timer?.invalidate()
        timer = nil

        releaseAssertions()
        onChange?()
    }

    /// Brings the stats up to date and ends the session if its time is up.
    /// Runs on every timer tick, on wake and before the menu opens.
    @objc func refresh() {
        guard let session else { return }
        recordElapsed()

        if let end = session.end, end <= Date() {
            stop()
        } else {
            onChange?()
        }
    }

    // MARK: - Assertions

    private func holdAssertions() {
        releaseAssertions()

        var types = [kIOPMAssertionTypePreventUserIdleSystemSleep]
        if !allowsDisplaySleep {
            types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep)
        }

        for type in types {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                Self.assertionName as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                assertions.append(id)
            }
        }
    }

    private func releaseAssertions() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions.removeAll()
    }

    // MARK: - Timer

    private func startTimer(for session: Session) {
        timer?.invalidate()

        // The session length is a multiple of the interval, so the last tick
        // lands on the end time. Short sessions tick faster to keep the icon
        // burning down in visible steps.
        var interval = Self.tickInterval
        if let end = session.end {
            interval = min(interval, end.timeIntervalSince(session.start) / 30)
        }

        let timer = Timer(timeInterval: interval, target: self, selector: #selector(refresh),
                          userInfo: nil, repeats: true)
        timer.tolerance = interval / 10
        // Common modes keep the timer firing while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Sleep and stats

    /// Time asleep doesn't count, so the clock stops here and restarts on wake.
    @objc private func willSleep() {
        recordElapsed()
        countedSince = nil
    }

    /// A timer can run out while the Mac sleeps. `refresh()` compares the end
    /// time with the clock, so a session that is past its end stops right away.
    @objc private func didWake() {
        guard isOn else { return }
        countedSince = Date()
        refresh()
    }

    private func recordElapsed() {
        guard let since = countedSince else { return }
        let now = Date()
        stats.add(from: since, to: min(now, session?.end ?? now))
        countedSince = now
    }
}
