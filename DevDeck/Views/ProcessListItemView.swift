import SwiftUI

struct ProcessListItemView: View {
    let process: DevProcess
    var compactMetrics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(process.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if process.isDevApp {
                    RuntimeBadgeView(runtime: process.project.runtime)
                }
            }

            Text("\(process.project.framework.displayName) · \(process.project.runtime.displayName) · :\(process.port) · \(process.branchText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(metricsLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private var metricsLine: String {
        let metrics = process.metrics ?? .empty

        if compactMetrics {
            return "\(metrics.cpuPercent.formatted(.number.precision(.fractionLength(1))))% CPU · \(metrics.memoryMB.formatted(.number.precision(.fractionLength(0)))) MB · PID \(process.pid)"
        }

        return "CPU \(metrics.cpuPercent.formatted(.number.precision(.fractionLength(1))))% · RAM \(metrics.memoryMB.formatted(.number.precision(.fractionLength(0)))) MB · PID \(process.pid)"
    }
}
