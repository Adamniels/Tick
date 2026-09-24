import Foundation
import SwiftData
import Testing
@testable import Tick

struct TimerServiceTests {
    let container = Persistence.makeInMemoryContainer()
    var context: ModelContext { container.mainContext }
    var service: TimerService { TimerService(context: context) }

    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func appRunsOnInMemoryStoreWhenHostingTests() {
        #expect(Persistence.isRunningTests)
    }

    @Test func startCreatesRunningEntryWithProjectAndTags() throws {
        let project = Project(name: "Tick")
        let tag = Tick.Tag(name: "deep work")
        context.insert(project)
        context.insert(tag)

        let entry = try service.start(description: "Models", project: project, tags: [tag], at: t0)

        #expect(entry.isRunning)
        #expect(entry.start == t0)
        #expect(entry.project == project)
        #expect(entry.tags == [tag])
        #expect(try service.runningEntries() == [entry])
    }

    @Test func startingStopsThePreviousTimer() throws {
        let first = try service.start(description: "A", project: nil, tags: [], at: t0)
        let second = try service.start(description: "B", project: nil, tags: [], at: t0 + 60)

        #expect(first.end == t0 + 60)
        #expect(second.isRunning)
        #expect(try service.runningEntries() == [second])
    }

    @Test func stopEndsTheRunningEntry() throws {
        let entry = try service.start(description: "A", project: nil, tags: [], at: t0)
        try service.stop(at: t0 + 90)

        #expect(entry.end == t0 + 90)
        #expect(entry.duration() == 90)
        #expect(try service.runningEntries().isEmpty)
    }

    @Test func stopNeverEndsBeforeStart() throws {
        let entry = try service.start(description: "Clock skew", project: nil, tags: [], at: t0)
        try service.stop(at: t0 - 10)
        #expect(entry.end == t0)
    }

    @Test func deletingTheRunningEntryStopsTracking() throws {
        let entry = try service.start(description: "Oops", project: nil, tags: [], at: t0)
        try service.delete(entry)
        #expect(try service.runningEntries().isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TimeEntry>()) == 0)
    }

    @Test func continueCopiesDescriptionProjectAndTags() throws {
        let project = Project(name: "Tick")
        let tag = Tick.Tag(name: "deep work")
        context.insert(project)
        context.insert(tag)
        let original = try service.start(description: "Models", project: project, tags: [tag], at: t0)
        try service.stop(at: t0 + 60)

        let continued = try service.continueEntry(original, at: t0 + 120)

        #expect(continued != original)
        #expect(continued.entryDescription == "Models")
        #expect(continued.project == project)
        #expect(continued.tags == [tag])
        #expect(continued.start == t0 + 120)
        #expect(original.end == t0 + 60)
    }

    @Test func resolveKeepsNewestAndChainsOlderEnds() {
        let oldest = TimeEntry(start: t0)
        let middle = TimeEntry(start: t0 + 100)
        let newest = TimeEntry(start: t0 + 200)

        let changed = TimerService.resolveDuplicateRunning([newest, oldest, middle])

        #expect(changed)
        #expect(oldest.end == t0 + 100)
        #expect(middle.end == t0 + 200)
        #expect(newest.isRunning)
    }

    @Test func resolveIgnoresStoppedEntriesAndSingleRunning() {
        let stopped = TimeEntry(start: t0, end: t0 + 50)
        let running = TimeEntry(start: t0 + 100)

        #expect(!TimerService.resolveDuplicateRunning([stopped, running]))
        #expect(stopped.end == t0 + 50)
        #expect(running.isRunning)
    }

    @Test func resolveBreaksTiesByIdSoEveryMacAgrees() {
        let a = TimeEntry(start: t0)
        let b = TimeEntry(start: t0)
        let (first, second) = a.id.uuidString < b.id.uuidString ? (a, b) : (b, a)

        #expect(TimerService.resolveDuplicateRunning([second, first]))
        #expect(first.end == t0)
        #expect(second.isRunning)
    }

    @Test func resolvePersistsThroughTheContext() throws {
        let older = TimeEntry(start: t0)
        let newer = TimeEntry(start: t0 + 30)
        context.insert(older)
        context.insert(newer)

        try service.resolveDuplicateRunning()

        #expect(try service.runningEntries() == [newer])
        #expect(older.end == t0 + 30)
    }
}
