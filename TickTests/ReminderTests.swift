import Foundation
import SwiftData
import Testing
@testable import Tick

/// Fixed calendar and dates. 2026-09-21 is a Monday.
enum TestCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()

    static func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}

struct WorkHoursTests {
    let calendar = TestCalendar.calendar
    let weekdays = ReminderSettings().workHours  // Mon–Fri 9–17
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(day, hour, minute) }

    @Test func insideAWeekdayWindow() {
        #expect(weekdays.windowStart(containing: date(21, 10), calendar: calendar) == date(21, 9))
        #expect(weekdays.windowStart(containing: date(21, 16, 59), calendar: calendar) == date(21, 9))
    }

    @Test func startIsInclusiveAndEndExclusive() {
        #expect(weekdays.windowStart(containing: date(21, 9), calendar: calendar) == date(21, 9))
        #expect(weekdays.windowStart(containing: date(21, 8, 59), calendar: calendar) == nil)
        #expect(weekdays.windowStart(containing: date(21, 17), calendar: calendar) == nil)
    }

    @Test func weekendIsOutside() {
        #expect(weekdays.windowStart(containing: date(26, 10), calendar: calendar) == nil)
    }

    @Test func overnightWindowBelongsToTheDayItStarts() {
        let fridayOnly = WorkHours(weekdayMask: 1 << 5, startMinute: 22 * 60, endMinute: 2 * 60)
        #expect(fridayOnly.windowStart(containing: date(25, 23), calendar: calendar) == date(25, 22))
        #expect(fridayOnly.windowStart(containing: date(26, 1), calendar: calendar) == date(25, 22))
        #expect(fridayOnly.windowStart(containing: date(26, 3), calendar: calendar) == nil)
        #expect(fridayOnly.windowStart(containing: date(26, 23), calendar: calendar) == nil)
    }

    @Test func keepsWallClockTimeAcrossDaylightSaving() {
        // 2026-03-29 is a Sunday when Europe switches to summer time.
        let everyDay = WorkHours(weekdayMask: 0b111_1111, startMinute: 9 * 60, endMinute: 17 * 60)
        let start = everyDay.windowStart(containing: TestCalendar.date(29, 12, month: 3), calendar: calendar)
        #expect(start.map { calendar.component(.hour, from: $0) } == 9)
    }
}

struct AwayTrackerTests {
    let t0 = TestCalendar.date(21, 10)

    @Test func lockThenUnlockReportsTheAwayPeriod() {
        var tracker = AwayTracker()
        #expect(tracker.handle(.lock, at: t0) == nil)
        #expect(tracker.isAway)
        #expect(tracker.handle(.unlock, at: t0 + 3600) == DateInterval(start: t0, end: t0 + 3600))
        #expect(!tracker.isAway)
    }

    @Test func wakingToALockScreenIsStillAway() {
        var tracker = AwayTracker()
        _ = tracker.handle(.lock, at: t0)
        _ = tracker.handle(.sleep, at: t0 + 10)
        #expect(tracker.handle(.wake, at: t0 + 3600) == nil)
        #expect(tracker.handle(.unlock, at: t0 + 3700) == DateInterval(start: t0, end: t0 + 3700))
    }

    @Test func displaySleepCountsAsAway() {
        var tracker = AwayTracker()
        _ = tracker.handle(.displaysSleep, at: t0)
        #expect(tracker.handle(.displaysWake, at: t0 + 600) == DateInterval(start: t0, end: t0 + 600))
    }

    @Test func returnEventsWithoutLeavingReportNothing() {
        var tracker = AwayTracker()
        #expect(tracker.handle(.wake, at: t0) == nil)
        #expect(tracker.handle(.unlock, at: t0) == nil)
    }
}

struct ReminderEvaluatorTests {
    let calendar = TestCalendar.calendar
    let settings = ReminderSettings()  // idle 15 min, forgotten 3 h, Mon–Fri 9–17
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(day, hour, minute) }

    func idleState(at now: Date, lastEnd: Date?, present: Bool = true) -> ReminderEvaluator.State {
        ReminderEvaluator.State(now: now, lastEntryEnd: lastEnd, baseline: date(21, 7), isPresent: present)
    }

    func evaluate(_ state: ReminderEvaluator.State, _ settings: ReminderSettings? = nil) -> Reminder? {
        ReminderEvaluator.evaluate(state, settings: settings ?? self.settings, calendar: calendar)
    }

    @Test func idleAfterThresholdDuringWorkHours() {
        #expect(evaluate(idleState(at: date(21, 10), lastEnd: date(21, 9, 44))) == .idle)
        #expect(evaluate(idleState(at: date(21, 10), lastEnd: date(21, 9, 46))) == nil)
    }

    @Test func idleCountsFromWorkStartAndBaseline() {
        let yesterday = date(20, 18)
        #expect(evaluate(idleState(at: date(21, 9, 10), lastEnd: yesterday)) == nil)
        #expect(evaluate(idleState(at: date(21, 9, 15), lastEnd: yesterday)) == .idle)

        var state = idleState(at: date(21, 10), lastEnd: yesterday)
        state.baseline = date(21, 9, 50)  // just came back
        #expect(evaluate(state) == nil)
    }

    @Test func noIdleWhenAbsentOnBreakSnoozedOrOffHours() {
        #expect(evaluate(idleState(at: date(21, 10), lastEnd: nil, present: false)) == nil)

        var onBreak = idleState(at: date(21, 10), lastEnd: nil)
        onBreak.pomodoroActive = true
        #expect(evaluate(onBreak) == nil)

        var snoozed = idleState(at: date(21, 10), lastEnd: nil)
        snoozed.idleSnoozedUntil = date(21, 10, 5)
        #expect(evaluate(snoozed) == nil)

        #expect(evaluate(idleState(at: date(26, 10), lastEnd: nil)) == nil)
        #expect(evaluate(idleState(at: date(21, 18), lastEnd: nil)) == nil)

        var disabled = settings
        disabled.idleEnabled = false
        #expect(evaluate(idleState(at: date(21, 10), lastEnd: nil), disabled) == nil)
    }

    @Test func forgottenAfterThresholdUnlessSnoozed() {
        let id = UUID()
        var state = ReminderEvaluator.State(
            now: date(21, 11, 59), runningEntryID: id, runningEntryStart: date(21, 9), baseline: date(21, 7), isPresent: true
        )
        #expect(evaluate(state) == nil)
        state.now = date(21, 12)
        #expect(evaluate(state) == .forgotten(entryID: id))
        state.forgottenSnoozedUntil = date(21, 15)
        #expect(evaluate(state) == nil)
    }

    @Test func aRunningTimerIsNeverIdle() {
        let state = ReminderEvaluator.State(
            now: date(21, 10), runningEntryID: UUID(), runningEntryStart: date(21, 9, 55), baseline: date(21, 7), isPresent: true
        )
        #expect(evaluate(state) == nil)
    }
}

struct SpokenDurationTests {
    @Test(arguments: [(0.0, "0 min"), (59, "0 min"), (2700, "45 min"), (3600, "1 h"), (11_520, "3 h 12 min")])
    func spoken(_ interval: Double, _ expected: String) {
        #expect(DurationFormat.spoken(interval) == expected)
    }
}

final class ReminderServiceTests {
    let container = Persistence.makeInMemoryContainer()
    let overlay = SpyOverlay()
    var now = TestCalendar.date(21, 8)  // Monday, before work hours
    var secondsSinceInput: TimeInterval = 0
    let errors = ErrorReporter()
    lazy var pomodoro = PomodoroService(context: context, overlay: overlay, errors: errors, clock: { [unowned self] in self.now })
    lazy var tracking = TrackingService(context: context, pomodoro: pomodoro)
    lazy var service = ReminderService(
        context: context, overlay: overlay, errors: errors, tracking: tracking,
        settings: { ReminderSettings() },
        clock: { [unowned self] in self.now },
        secondsSinceInput: { [unowned self] in self.secondsSinceInput },
        calendar: TestCalendar.calendar,
        observeSystem: false
    )

    var context: ModelContext { container.mainContext }
    var timer: TimerService { TimerService(context: context) }
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(day, hour, minute) }

    private func tick(at date: Date) throws {
        now = date
        try service.update(at: date, runningEntry: try timer.runningEntries().last, pomodoroActive: false)
    }

    init() {
        _ = service  // Launch time is 08:00.
    }

    @Test func idlePopupAppearsOnceAndSnoozes() throws {
        try tick(at: date(21, 9, 14))
        #expect(overlay.shown.isEmpty)
        try tick(at: date(21, 9, 15))
        try tick(at: date(21, 9, 16))
        #expect(overlay.shown.map(\.id) == [ReminderService.idleOverlayID])

        try overlay.press("Remind me in 15 min")
        try tick(at: date(21, 9, 30))
        #expect(overlay.shown.count == 1)
        try tick(at: date(21, 9, 31))
        #expect(overlay.shown.count == 2)
    }

    @Test func idlePopupClosesWhenATimerStartsElsewhere() throws {
        try tick(at: date(21, 9, 15))
        try timer.start(description: "Started on the other Mac", project: nil, tags: [], at: date(21, 9, 16))
        try tick(at: date(21, 9, 16))
        #expect(overlay.dismissed == [ReminderService.idleOverlayID])
    }

    @Test func quickStartContinuesARecentEntry() throws {
        let project = Project(name: "Operation Rollout")
        context.insert(project)
        try timer.start(description: "Mini games", project: project, tags: [], at: date(20, 10))
        try timer.stop(at: date(20, 11))

        try tick(at: date(21, 9, 15))
        try overlay.press("▶ Operation Rollout · Mini games")

        let running = try #require(try timer.runningEntries().last)
        #expect(running.project == project)
        #expect(running.start == date(21, 9, 15))
    }

    @Test func noIdlePopupWhenNotAtTheMac() throws {
        secondsSinceInput = 10 * 60
        try tick(at: date(21, 10))
        #expect(overlay.shown.isEmpty)
    }

    @Test func forgottenTimerCanBeStoppedAtAChosenTime() throws {
        try timer.start(description: "Refactor", project: nil, tags: [], at: date(21, 9))
        try tick(at: date(21, 12))

        let request = try #require(overlay.shown.last)
        #expect(request.id.hasPrefix("reminder.forgotten."))
        let input = try #require(request.dateInput)
        input.date = date(21, 10, 30)
        try overlay.press("Stop at selected time")

        #expect(try timer.runningEntries().isEmpty)
        #expect(try timer.latestEntry()?.end == date(21, 10, 30))
    }

    @Test func stillWorkingSnoozesForAnotherThreshold() throws {
        try timer.start(description: "Refactor", project: nil, tags: [], at: date(21, 9))
        try tick(at: date(21, 12))
        try overlay.press("Still working")

        try tick(at: date(21, 14, 59))
        #expect(overlay.shown.count == 1)
        try tick(at: date(21, 15))
        #expect(overlay.shown.count == 2)
    }

    @Test func forgottenPopupClosesWhenStoppedElsewhere() throws {
        let entry = try timer.start(description: "Refactor", project: nil, tags: [], at: date(21, 9))
        try tick(at: date(21, 12))
        try timer.stop(at: date(21, 12, 1))
        try tick(at: date(21, 12, 1))
        #expect(overlay.dismissed == [ReminderService.forgottenOverlayID(entry.id)])
    }

    @Test func removingAwayTimeSplitsTheEntryAroundTheGap() throws {
        let entry = try timer.start(description: "Mini games", project: nil, tags: [], at: date(21, 9))
        service.handle(.lock, at: date(21, 10))
        now = date(21, 11)
        service.handle(.unlock, at: now)

        #expect(overlay.shown.last?.id == ReminderService.awayOverlayID(entry.id))
        try overlay.press("Remove away time")

        #expect(entry.end == date(21, 10))
        let continued = try #require(try timer.runningEntries().last)
        #expect(continued.start == date(21, 11))
        #expect(continued.entryDescription == "Mini games")
    }

    @Test func shortAbsencesAreIgnored() throws {
        try timer.start(description: "Mini games", project: nil, tags: [], at: date(21, 9))
        service.handle(.lock, at: date(21, 10))
        service.handle(.unlock, at: date(21, 10, 4))
        #expect(overlay.shown.isEmpty)
    }

    @Test func nothingIsShownWhileAwayAndIdleCountsFromReturn() throws {
        service.handle(.lock, at: date(21, 9))
        try tick(at: date(21, 10))
        #expect(overlay.shown.isEmpty)

        service.handle(.unlock, at: date(21, 10))
        try tick(at: date(21, 10, 14))
        #expect(overlay.shown.isEmpty)
        try tick(at: date(21, 10, 15))
        #expect(overlay.shown.map(\.id) == [ReminderService.idleOverlayID])
    }
}
