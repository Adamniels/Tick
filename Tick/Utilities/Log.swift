import OSLog

enum Log {
    static let storage = Logger(subsystem: "com.adamniels.Tick", category: "storage")
    static let timer = Logger(subsystem: "com.adamniels.Tick", category: "timer")
    static let pomodoro = Logger(subsystem: "com.adamniels.Tick", category: "pomodoro")
}
