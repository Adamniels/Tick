import OSLog

enum Log {
    static let app = Logger(subsystem: "com.adamniels.Tick", category: "app")
    static let storage = Logger(subsystem: "com.adamniels.Tick", category: "storage")
}
