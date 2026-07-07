import SwiftUI

struct ProcessDetailView: View {
    let process: DevProcess
    @ObservedObject var store: DevDeckStore
    let compact: Bool
    let onBack: (() -> Void)?
    let onKill: () -> Void

    init(
        process: DevProcess,
        store: DevDeckStore,
        compact: Bool = false,
        onBack: (() -> Void)? = nil,
        onKill: @escaping () -> Void
    ) {
        self.process = process
        self.store = store
        self.compact = compact
        self.onBack = onBack
        self.onKill = onKill
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 12 : 18) {
                    metricsStrip
                    detailGrid
                }
                .padding(compact ? 10 : 14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Back")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if process.isDevApp {
                        RuntimeBadgeView(runtime: process.project.runtime)
                    }

                    Text(process.displayName)
                        .font(compact ? .headline.weight(.semibold) : .title2.weight(.semibold))
                        .lineLimit(2)
                }

                Text("\(process.project.framework.displayName) · \(process.project.runtime.displayName) · :\(process.port) · PID \(process.pid)")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: compact ? 6 : 8) {
                Button(role: .destructive, action: onKill) {
                    Label("Kill", systemImage: "xmark.circle")
                }

                Button {
                    store.openInBrowser(process)
                } label: {
                    Label("Open", systemImage: "safari")
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 10 : 14)
    }

    private var metricsStrip: some View {
        HStack(spacing: compact ? 8 : 14) {
            MetricPill(label: "CPU", value: "\(metrics.cpuPercent.formatted(.number.precision(.fractionLength(1))))%", compact: compact)
            MetricPill(label: "RAM", value: "\(metrics.memoryMB.formatted(.number.precision(.fractionLength(0)))) MB", compact: compact)
            MetricPill(label: "Uptime", value: metrics.uptime, compact: compact)
        }
    }

    private var detailGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            DetailRow(label: "App", value: process.displayName)
            DetailRow(label: "Framework", value: process.project.framework.displayName)
            DetailRow(label: "Port", value: ":\(process.port)")
            DetailRow(label: "PID", value: "\(process.pid)")
            DetailRow(label: "Command", value: process.command)
            DetailRow(label: "CWD", value: process.cwd ?? "Unknown project")
            DetailRow(label: "Runtime", value: process.project.runtime.displayName)
            DetailRow(label: "Toolchain", value: process.project.packageManager.displayName)
            DetailRow(label: "Runtime version", value: process.runtimeVersion ?? "Unknown")
            DetailRow(label: "Git branch", value: process.git?.branch ?? "No Git")
            DetailRow(label: "Git status", value: process.git?.statusText ?? "Unknown")

            if !compact {
                DetailRow(label: "CPU", value: "\(metrics.cpuPercent.formatted(.number.precision(.fractionLength(1))))%")
                DetailRow(label: "Memory", value: "\(metrics.memoryMB.formatted(.number.precision(.fractionLength(0)))) MB")
                DetailRow(label: "Uptime", value: metrics.uptime)
            }

            DetailRow(label: "Manifest", value: process.project.manifestPath ?? "Missing")
            DetailRow(label: "Start script", value: process.project.detectedStartScript ?? "Unknown")
            DetailRow(label: "Remote", value: process.git?.remoteOriginURL ?? "None")
        }
    }

    private var metrics: ProcessMetrics {
        process.metrics ?? .empty
    }
}

private struct MetricPill: View {
    let label: String
    let value: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font((compact ? Font.caption2 : Font.caption).weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 7 : 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(4)
        }
    }
}
