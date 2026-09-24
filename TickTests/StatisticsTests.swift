import Foundation
import Testing
@testable import Tick

struct StatsPeriodTests {
    let calendar: Calendar = {
        var calendar = TestCalendar.calendar
        calendar.firstWeekday = 2  // Monday, as in Sweden.
        return calendar
    }()
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(day, hour, minute) }

    func make(_ kind: StatsPeriodKind, now: Date, from: Date? = nil, to: Date? = nil) -> StatsPeriod {
        StatsPeriod.make(kind, customStart: from ?? now, customEnd: to ?? now, now: now, calendar: calendar)
    }

    @Test func todayComparesWithYesterdayAtTheSameTime() {
        let period = make(.today, now: date(24, 15))
        #expect(period.current == DateInterval(start: date(24, 0), end: date(24, 15)))
        #expect(period.previous == DateInterval(start: date(23, 0), end: date(23, 15)))
        #expect(period.days == [date(24, 0)])
    }

    @Test func weekStartsMondayAndComparesToTheSamePointLastWeek() {
        let period = make(.week, now: date(24, 15))  // Thursday
        #expect(period.full == DateInterval(start: date(21, 0), end: date(28, 0)))
        #expect(period.current.end == date(24, 15))
        #expect(period.previous == DateInterval(start: date(14, 0), end: date(17, 15)))
        #expect(period.days.count == 7)
    }

    @Test func monthComparesToTheSamePointLastMonth() {
        let period = make(.month, now: date(24, 15))
        #expect(period.full.start == date(1, 0))
        #expect(period.previous.start == TestCalendar.date(1, 0, month: 8))
        #expect(period.previous.end == TestCalendar.date(24, 15, month: 8))
        #expect(period.days.count == 30)
    }

    @Test func customRangeComparesWithTheSameLengthBefore() {
        let period = make(.custom, now: date(30, 12), from: date(14, 10), to: date(20, 18))
        #expect(period.full == DateInterval(start: date(14, 0), end: date(21, 0)))
        #expect(period.current == period.full)
        #expect(period.previous == DateInterval(start: date(7, 0), end: date(14, 0)))
    }

    @Test func customRangeAcceptsReversedDates() {
        let period = make(.custom, now: date(30, 12), from: date(20, 0), to: date(14, 0))
        #expect(period.full.start == date(14, 0))
    }
}

struct StatisticsComputeTests {
    let calendar = TestCalendar.calendar
    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(day, hour, minute) }

    /// Monday 21 September, measured up to 18:00.
    var monday: StatsPeriod {
        StatsPeriod.make(.today, customStart: .now, customEnd: .now, now: date(21, 18), calendar: calendar)
    }

    func entry(_ start: Date, _ end: Date?, project: Project? = nil, tags: [Tick.Tag] = []) -> TimeEntry {
        let entry = TimeEntry(start: start, end: end)
        entry.project = project
        entry.tags = tags
        return entry
    }

    func compute(_ entries: [TimeEntry], pomodoros: [Date] = [], period: StatsPeriod? = nil, now: Date? = nil) -> Statistics {
        Statistics.compute(
            entries: entries, completedWorkBlockStarts: pomodoros, period: period ?? monday,
            now: now ?? date(21, 18), calendar: calendar
        )
    }

    @Test func totalsPerProjectIncludingNoProject() {
        let tick = Project(name: "Tick", colorHex: "#FF0000")
        let stats = compute([
            entry(date(21, 9), date(21, 11), project: tick),
            entry(date(21, 13), date(21, 14)),
        ])
        #expect(stats.total == 3 * 3600)
        #expect(stats.projects.map(\.name) == ["Tick", "No project"])
        #expect(stats.projects.map(\.seconds) == [7200, 3600])
        #expect(stats.projects.first?.colorHex == "#FF0000")
    }

    @Test func entriesAreClippedToThePeriodAndRunningCountsToNow() {
        let stats = compute([
            entry(date(20, 23), date(21, 1)),  // started yesterday: 1 h today
            entry(date(21, 17), nil),          // running: 1 h up to 18:00
        ])
        #expect(stats.total == 2 * 3600)
    }

    @Test func archivedProjectsStillCount() {
        let old = Project(name: "Old")
        old.isArchived = true
        #expect(compute([entry(date(21, 9), date(21, 10), project: old)]).projects.first?.name == "Old")
    }

    @Test func eachTagGetsTheFullTimeAndUntaggedIsBucketed() {
        let deep = Tick.Tag(name: "deep"), code = Tick.Tag(name: "code")
        let stats = compute([
            entry(date(21, 9), date(21, 11), tags: [deep, code]),
            entry(date(21, 13), date(21, 14)),
        ])
        #expect(Dictionary(uniqueKeysWithValues: stats.tags.map { ($0.name, $0.seconds) })
            == ["deep": 7200, "code": 7200, "No tag": 3600])
    }

    @Test func perDaySplitsAtMidnight() {
        let week = StatsPeriod.make(.week, customStart: .now, customEnd: .now, now: date(23, 12), calendar: {
            var c = calendar; c.firstWeekday = 2; return c
        }())
        let stats = compute([entry(date(21, 22), date(22, 2))], period: week, now: date(23, 12))
        let byDay = Dictionary(uniqueKeysWithValues: stats.days.map { ($0.day, $0.seconds) })
        let twoHours: TimeInterval = 2 * 3600
        #expect(byDay[date(21, 0)] == twoHours)
        #expect(byDay[date(22, 0)] == twoHours)
    }

    @Test func overlapIsSummedMinusCoveredTime() {
        let stats = compute([
            entry(date(21, 9), date(21, 10)),
            entry(date(21, 9, 30), date(21, 10, 30)),
            entry(date(21, 12), date(21, 13)),
        ])
        #expect(stats.total == 3 * 3600)
        #expect(stats.overlapSeconds == 30 * 60)
        #expect(stats.overlappingEntryCount == 2)
    }

    @Test func noOverlapReportsZero() {
        let stats = compute([entry(date(21, 9), date(21, 10)), entry(date(21, 10), date(21, 11))])
        #expect(stats.overlapSeconds == 0)
        #expect(stats.overlappingEntryCount == 0)
    }

    @Test func previousTotalUsesThePreviousPeriod() {
        let stats = compute([
            entry(date(20, 9), date(20, 11)),   // yesterday, before 18:00
            entry(date(20, 19), date(20, 20)),  // yesterday, after the comparison point
            entry(date(21, 9), date(21, 10)),
        ])
        #expect(stats.previousTotal == 2 * 3600)
        #expect(stats.total == 3600)
    }

    @Test func pomodorosAreCountedPerDay() {
        let stats = compute([], pomodoros: [date(21, 9), date(21, 10), date(20, 9)])
        #expect(stats.pomodorosPerDay == [Statistics.DayCount(day: date(21, 0), count: 2)])
    }

    @Test func coveredDurationMergesIntervals() {
        let t = date(21, 9)
        let intervals = [
            DateInterval(start: t, duration: 3600),
            DateInterval(start: t + 1800, duration: 3600),
            DateInterval(start: t + 7200, duration: 600),
        ]
        #expect(Statistics.coveredDuration(of: intervals) == 5400 + 600)
    }
}
