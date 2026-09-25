import Foundation
import Testing
@testable import Tick

struct ErrorReporterTests {
    struct Failure: LocalizedError {
        var errorDescription: String? { "the disk is full" }
    }

    @Test func successLeavesNoMessage() {
        let errors = ErrorReporter()
        var ran = false
        errors.run("Saving") { ran = true }
        #expect(ran)
        #expect(errors.message == nil)
    }

    @Test func failureIsShownUntilDismissed() {
        let errors = ErrorReporter()
        errors.run("Stopping the timer") { throw Failure() }
        #expect(errors.message == "Stopping the timer failed: the disk is full")
        errors.dismiss()
        #expect(errors.message == nil)
    }
}
