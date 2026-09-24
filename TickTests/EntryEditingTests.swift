import Foundation
import SwiftData
import Testing
@testable import Tick

struct EntryDraftTests {
    let t0 = TestCalendar.date(21, 10)

    @Test func endMustBeAfterStart() {
        #expect(EntryDraft(start: t0, end: t0 + 60).validationError(now: t0) == nil)
        #expect(EntryDraft(start: t0, end: t0).validationError(now: t0) != nil)
        #expect(EntryDraft(start: t0, end: t0 - 60).validationError(now: t0) != nil)
    }

    @Test func runningEntryCannotStartInTheFuture() {
        #expect(EntryDraft(start: t0, end: nil).validationError(now: t0) == nil)
        #expect(EntryDraft(start: t0 + 60, end: nil).validationError(now: t0) != nil)
    }

    @Test func newManualEntryIsTheLastHourEndingAtTheCurrentMinute() {
        let draft = EntryDraft.newManual(now: TestCalendar.date(21, 10, 30) + 42, calendar: TestCalendar.calendar)
        #expect(draft.end == TestCalendar.date(21, 10, 30))
        #expect(draft.start == TestCalendar.date(21, 9, 30))
    }
}

struct EntryAnalysisTests {
    let t0 = TestCalendar.date(21, 9)

    func entry(_ startMinutes: Double, _ endMinutes: Double?) -> TimeEntry {
        TimeEntry(start: t0 + startMinutes * 60, end: endMinutes.map { t0 + $0 * 60 })
    }

    @Test func separateAndTouchingEntriesDontOverlap() {
        let entries = [entry(0, 30), entry(30, 60), entry(90, 120)]
        #expect(EntryAnalysis.overlappingIDs(in: entries, now: t0 + 7200).isEmpty)
    }

    @Test func overlappingPairsAreBothMarked() {
        let a = entry(0, 60), b = entry(30, 90), c = entry(120, 150)
        #expect(EntryAnalysis.overlappingIDs(in: [c, b, a], now: t0 + 9000) == [a.id, b.id])
    }

    @Test func entryInsideALongOneIsMarkedEvenAfterOthers() {
        let long = entry(0, 240), inner1 = entry(10, 20), inner2 = entry(100, 110)
        #expect(EntryAnalysis.overlappingIDs(in: [long, inner1, inner2], now: t0 + 20_000)
            == [long.id, inner1.id, inner2.id])
    }

    @Test func runningEntryLastsUntilNow() {
        let running = entry(0, nil), later = entry(30, 40)
        #expect(EntryAnalysis.overlappingIDs(in: [running, later], now: t0 + 3600) == [running.id, later.id])
        #expect(EntryAnalysis.overlappingIDs(in: [running, later], now: t0 + 20 * 60).isEmpty)
    }

    @Test func groupsByStartDayNewestFirstWithTotals() {
        let monday1 = TimeEntry(start: TestCalendar.date(21, 9), end: TestCalendar.date(21, 10))
        let monday2 = TimeEntry(start: TestCalendar.date(21, 13), end: TestCalendar.date(21, 13, 30))
        let tuesday = TimeEntry(start: TestCalendar.date(22, 9), end: TestCalendar.date(22, 9, 15))

        let days = EntryAnalysis.days(of: [monday1, tuesday, monday2], now: TestCalendar.date(23, 0), calendar: TestCalendar.calendar)

        #expect(days.map(\.start) == [TestCalendar.date(22, 0), TestCalendar.date(21, 0)])
        #expect(days[1].entries == [monday2, monday1])
        #expect(days[1].total == 5400)
        #expect(days[0].total == 900)
    }
}

struct SaveDraftTests {
    let container = Persistence.makeInMemoryContainer()
    var context: ModelContext { container.mainContext }
    var service: TimerService { TimerService(context: context) }
    let t0 = TestCalendar.date(21, 9)

    @Test func createsAManualEntry() throws {
        let project = Project(name: "Tick")
        let tag = Tick.Tag(name: "planning")
        context.insert(project)
        context.insert(tag)

        let draft = EntryDraft(description: "  Plan M5 ", project: project, tags: [tag], start: t0, end: t0 + 1800)
        let entry = try service.save(draft, to: nil)

        #expect(entry.entryDescription == "Plan M5")
        #expect(entry.project == project)
        #expect(entry.tags == [tag])
        #expect(entry.duration() == 1800)
        #expect(!entry.isPomodoro)
        #expect(try context.fetchCount(FetchDescriptor<TimeEntry>()) == 1)
    }

    @Test func updatesAnExistingEntry() throws {
        let entry = try service.start(description: "Old", project: nil, tags: [], at: t0)
        try service.stop(at: t0 + 600)

        var draft = EntryDraft(entry: entry)
        draft.description = "New"
        draft.start = t0 - 600
        draft.end = t0 + 1200
        try service.save(draft, to: entry)

        #expect(entry.entryDescription == "New")
        #expect(entry.start == t0 - 600)
        #expect(entry.end == t0 + 1200)
        #expect(try context.fetchCount(FetchDescriptor<TimeEntry>()) == 1)
    }

    @Test func editingTheRunningEntryKeepsItRunning() throws {
        let entry = try service.start(description: "Running", project: nil, tags: [], at: t0)
        var draft = EntryDraft(entry: entry)
        draft.start = t0 - 300
        try service.save(draft, to: entry)

        #expect(entry.isRunning)
        #expect(entry.start == t0 - 300)
    }
}
