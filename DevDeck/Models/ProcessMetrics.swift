import Foundation

struct ProcessMetrics: Equatable {
    let cpuPercent: Double
    let memoryMB: Double
    let uptime: String
    let command: String

    static let empty = ProcessMetrics(
        cpuPercent: 0,
        memoryMB: 0,
        uptime: "Unknown",
        command: ""
    )
}
