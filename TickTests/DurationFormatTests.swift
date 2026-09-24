import Testing
@testable import Tick

struct DurationFormatTests {
    @Test(arguments: [
        (0.0, "0:00:00"),
        (59.9, "0:00:59"),
        (2533, "0:42:13"),
        (36000, "10:00:00"),
        (-5, "0:00:00"),
    ])
    func clock(_ interval: Double, _ expected: String) {
        #expect(DurationFormat.clock(interval) == expected)
    }
}
