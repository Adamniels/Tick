import CoreGraphics
import Foundation
import Testing
@testable import Tick

struct CalendarLayoutTests {
    let day = DateInterval(start: TestCalendar.date(21, 0), end: TestCalendar.date(22, 0))
    func at(_ hour: Int, _ minute: Int = 0) -> Date { TestCalendar.date(21, hour, minute) }
    func item(_ start: Date, _ end: Date) -> CalendarLayout.Item { .init(id: UUID(), start: start, end: end) }

    // MARK: Blocks

    @Test func separateEntriesTakeTheFullWidth() {
        let blocks = CalendarLayout.blocks(for: [item(at(9), at(10)), item(at(10), at(11))], in: day)
        #expect(blocks.map(\.columnCount) == [1, 1])
        #expect(blocks.map(\.column) == [0, 0])
    }

    @Test func overlappingEntriesShareColumns() {
        let a = item(at(9), at(11)), b = item(at(10), at(12)), c = item(at(11), at(13))
        let blocks = CalendarLayout.blocks(for: [c, b, a], in: day)
        let byID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        // a and b overlap; c starts when a ends, so it reuses a's column. One cluster, two columns.
        #expect(byID[a.id]?.column == 0)
        #expect(byID[b.id]?.column == 1)
        #expect(byID[c.id]?.column == 0)
        #expect(blocks.allSatisfy { $0.columnCount == 2 })
    }

    @Test func clustersAreIndependent() {
        let blocks = CalendarLayout.blocks(for: [
            item(at(9), at(10)), item(at(9, 30), at(10, 30)),  // cluster of two
            item(at(14), at(15)),                             // alone
        ], in: day)
        #expect(blocks.map(\.columnCount) == [2, 2, 1])
    }

    @Test func entriesAreClippedToTheDayAndMarked() {
        let overnight = item(TestCalendar.date(20, 23), at(1))
        let block = try! #require(CalendarLayout.blocks(for: [overnight], in: day).first)
        #expect(block.start == at(0))
        #expect(block.end == at(1))
        #expect(block.continuesBefore)
        #expect(!block.continuesAfter)
        #expect(CalendarLayout.blocks(for: [item(TestCalendar.date(20, 9), TestCalendar.date(20, 10))], in: day).isEmpty)
    }

    // MARK: Geometry

    @Test func offsetsAndDatesAreInverse() {
        let offset = CalendarLayout.offset(of: at(9, 30), from: day.start, hourHeight: 60)
        #expect(offset == 570)
        #expect(CalendarLayout.date(atOffset: offset, from: day.start, hourHeight: 60) == at(9, 30))
    }

    @Test func snapsToTheNearestFiveMinutes() {
        #expect(CalendarLayout.snapped(at(9, 2), from: day.start) == at(9, 0))
        #expect(CalendarLayout.snapped(at(9, 3), from: day.start) == at(9, 5))
    }

    // MARK: Drags

    func result(_ drag: CalendarLayout.Drag, delta: TimeInterval = 0, pointer: Date? = nil, latestStart: Date? = nil)
        -> (Date, Date) {
        let r = CalendarLayout.result(of: drag, delta: delta, pointer: pointer ?? day.start, day: day, latestStart: latestStart)
        return (r.start, r.end)
    }

    @Test func createWorksInBothDirectionsAndSnaps() {
        #expect(result(.create(anchor: at(9, 1)), pointer: at(10, 29)) == (at(9), at(10, 30)))
        #expect(result(.create(anchor: at(10, 29)), pointer: at(9, 1)) == (at(9), at(10, 30)))
    }

    @Test func createHasAMinimumLengthAndStaysInTheDay() {
        #expect(result(.create(anchor: at(9)), pointer: at(9, 1)) == (at(9), at(9, 5)))
        #expect(result(.create(anchor: at(23, 59)), pointer: TestCalendar.date(22, 3)) == (at(23, 55), day.end))
    }

    @Test func moveKeepsTheLengthAndStaysInTheDay() {
        #expect(result(.move(start: at(9), end: at(10)), delta: 32 * 60) == (at(9, 30), at(10, 30)))
        #expect(result(.move(start: at(9), end: at(10)), delta: -20 * 3600) == (at(0), at(1)))
        #expect(result(.move(start: at(22), end: at(23)), delta: 5 * 3600) == (at(23), day.end))
    }

    @Test func resizeStartCannotPassTheEndOrNow() {
        #expect(result(.resizeStart(start: at(9), end: at(10)), delta: -30 * 60) == (at(8, 30), at(10)))
        #expect(result(.resizeStart(start: at(9), end: at(10)), delta: 3 * 3600) == (at(9, 55), at(10)))
        #expect(result(.resizeStart(start: at(9), end: at(10)), delta: 50 * 60, latestStart: at(9, 20)) == (at(9, 20), at(10)))
    }

    @Test func resizeEndCannotPassTheStartOrTheDay() {
        #expect(result(.resizeEnd(start: at(9), end: at(10)), delta: 45 * 60) == (at(9), at(10, 45)))
        #expect(result(.resizeEnd(start: at(9), end: at(10)), delta: -3 * 3600) == (at(9), at(9, 5)))
        #expect(result(.resizeEnd(start: at(23), end: at(23, 30)), delta: 3 * 3600) == (at(23), day.end))
    }
}
