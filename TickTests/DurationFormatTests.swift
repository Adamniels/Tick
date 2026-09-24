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

struct CountdownFormatTests {
    @Test(arguments: [
        (1500.0, "25:00"),
        (1499.2, "25:00"),
        (1122, "18:42"),
        (0.4, "0:01"),
        (0, "0:00"),
        (-30, "0:00"),
        (3725, "1:02:05"),
    ])
    func countdown(_ interval: Double, _ expected: String) {
        #expect(DurationFormat.countdown(interval) == expected)
    }
}
