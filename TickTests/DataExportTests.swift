import Foundation
import SwiftData
import Testing
@testable import Tick

struct DataExportTests {
    let container = Persistence.makeInMemoryContainer()
    var context: ModelContext { container.mainContext }
    let t0 = TestCalendar.date(21, 9) + 0.25  // fractional seconds must survive

    let settings = ExportArchive.SettingsRecord(
        pomodoroEnabled: true, pomodoro: PomodoroSettings(workMinutes: 50),
        reminders: ReminderSettings(), popup: OverlayAppearance()
    )

    private func makeArchive() throws -> (ExportArchive, Project, Tick.Tag, TimeEntry) {
        let project = Project(name: "Operation Rollout", colorHex: "#FF0000")
        let tag = Tick.Tag(name: "deep work")
        context.insert(project)
        context.insert(tag)
        let service = TimerService(context: context)
        let entry = try service.start(description: "Mini games, round 2", project: project, tags: [tag], at: t0)
        try service.stop(at: t0 + 5400)
        try service.start(description: "Running", project: nil, tags: [], at: t0 + 6000)
        context.insert(PomodoroSession(runID: UUID(), phase: .work, start: t0, plannedEnd: t0 + 1500))
        return (try DataExport.archive(context: context, settings: settings, now: t0 + 7000), project, tag, entry)
    }

    @Test func archiveKeepsIdsAndRelationshipsByReference() throws {
        let (archive, project, tag, entry) = try makeArchive()

        #expect(archive.formatVersion == 1)
        #expect(archive.projects.map(\.id) == [project.id])
        #expect(archive.tags.map(\.id) == [tag.id])
        #expect(archive.entries.count == 2)
        let record = try #require(archive.entries.first { $0.id == entry.id })
        #expect(record.projectID == project.id)
        #expect(record.tagIDs == [tag.id])
        #expect(archive.entries.last?.end == nil)
        #expect(archive.pomodoroSessions.count == 1)
        #expect(archive.settings.pomodoro.workMinutes == 50)
    }

    @Test func jsonRoundTripIsStableAndExactToTheMillisecond() throws {
        let (archive, _, _, _) = try makeArchive()
        let json = try DataExport.json(archive)
        let decoded = try DataExport.decode(json)

        // Export → import → export gives the identical file.
        #expect(try DataExport.json(decoded) == json)
        #expect(decoded.entries.map(\.id) == archive.entries.map(\.id))
        #expect(decoded.entries.first?.start == t0)
        #expect(decoded.entries.last?.end == nil)
        for (a, b) in zip(decoded.projects, archive.projects) {
            #expect(abs(a.createdAt.timeIntervalSince(b.createdAt)) < 0.001)
        }
    }

    @Test func csvHasAHeaderAndOneRowPerEntryWithEscaping() throws {
        let (archive, _, _, _) = try makeArchive()
        let lines = DataExport.csv(archive, timeZone: TestCalendar.calendar.timeZone)
            .split(separator: "\r\n", omittingEmptySubsequences: true)

        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("Description,Project,Tags,Start date,Start time,End date,End time,Duration"))
        #expect(lines[1].hasPrefix("\"Mini games, round 2\",Operation Rollout,deep work,2026-09-21,09:00:00,2026-09-21,10:30:00,1:30:00,1.5000,no,"))
        #expect(lines[2].hasPrefix("Running,,,2026-09-21,10:40:00,,,,,no,"))
    }

    @Test(arguments: [
        ("plain", "plain"),
        ("a, b", "\"a, b\""),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
        ("two\nlines", "\"two\nlines\""),
    ])
    func csvFieldsAreQuotedPerRFC4180(_ input: String, _ expected: String) {
        #expect(DataExport.csvField(input) == expected)
    }
}
