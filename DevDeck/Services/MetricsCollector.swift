import Foundation

final class MetricsCollector {
    func collect(pid: Int32) async -> ProcessMetrics? {
        await collect(pids: [pid])[pid]
    }

    func collect(pids: [Int32]) async -> [Int32: ProcessMetrics] {
        let uniquePIDs = Array(Set(pids)).sorted()
        guard !uniquePIDs.isEmpty else {
            return [:]
        }

        let result = await Shell.run(
            "/bin/ps",
            arguments: [
                "-p", uniquePIDs.map(String.init).joined(separator: ","),
                "-o", "pid=",
                "-o", "%cpu=",
                "-o", "rss=",
                "-o", "etime=",
                "-o", "command="
            ],
            timeout: 2
        )

        guard result.succeeded else {
            return [:]
        }

        var metricsByPID: [Int32: ProcessMetrics] = [:]

        for line in result.stdout.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)

            guard fields.count >= 4,
                  let pid = Int32(fields[0]) else {
                continue
            }

            let cpu = Double(fields[1]) ?? 0
            let rssKB = Double(fields[2]) ?? 0
            let uptime = String(fields[3])
            let command = fields.count >= 5 ? String(fields[4]) : ""

            metricsByPID[pid] = ProcessMetrics(
                cpuPercent: cpu,
                memoryMB: rssKB / 1024,
                uptime: uptime,
                command: command
            )
        }

        return metricsByPID
    }
}
