import Foundation
import Testing
@testable import Tick

struct MenuBarTitleTests {
    @Test func prefersProjectNameOverDescription() {
        #expect(MenuBarTitle.text(projectName: "Operation Rollout", description: "Mini games", elapsed: 2533)
            == "0:42:13 Operation Rollout")
    }

    @Test func fallsBackToDescriptionThenClockOnly() {
        #expect(MenuBarTitle.text(projectName: nil, description: "Reading", elapsed: 5) == "0:00:05 Reading")
        #expect(MenuBarTitle.text(projectName: nil, description: "", elapsed: 5) == "0:00:05")
    }

    @Test func truncatesLongNames() {
        let name = String(repeating: "x", count: 40)
        let title = MenuBarTitle.text(projectName: name, description: "", elapsed: 0)
        #expect(title == "0:00:00 " + String(repeating: "x", count: MenuBarTitle.maxNameLength - 1) + "…")
    }

    @Test func idleTicksEverySecond() {
        #expect(MenuBarTitle.delayUntilNextTick(start: nil, now: .now) == 1)
    }

    @Test func runningTicksJustAfterTheNextWholeSecond() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let delay = MenuBarTitle.delayUntilNextTick(start: start, now: start + 10.75)
        #expect(abs(delay - 0.27) < 0.0001)
    }

    @Test func startInTheFutureStillGivesAPositiveDelay() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let delay = MenuBarTitle.delayUntilNextTick(start: start, now: start - 0.25)
        #expect(delay > 0 && delay <= 1.02)
    }
}
