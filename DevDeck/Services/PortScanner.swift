import Foundation

final class PortScanner {
    func scan() async -> [ListeningPort] {
        let result = await Shell.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"],
            timeout: 4
        )

        guard !result.stdout.isEmpty else {
            return []
        }

        return parseLsofOutput(result.stdout)
    }

    private func parseLsofOutput(_ output: String) -> [ListeningPort] {
        var ports: [ListeningPort] = []
        var seen: Set<String> = []

        for line in output.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("COMMAND") {
                continue
            }

            let fields = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
            guard fields.count >= 9,
                  let pid = Int32(fields[1]),
                  let port = parsePort(from: String(fields[8])) else {
                continue
            }

            let processName = String(fields[0])
            let protocolName = String(fields[7])
            let rawName = String(fields[8])
            let address = parseAddress(from: rawName)
            let dedupeKey = "\(pid)-\(port)-\(protocolName)-\(address)"

            guard !seen.contains(dedupeKey) else {
                continue
            }

            seen.insert(dedupeKey)

            ports.append(
                ListeningPort(
                    port: port,
                    pid: pid,
                    processName: processName,
                    command: processName,
                    user: String(fields[2]),
                    protocolName: protocolName,
                    address: address,
                    rawName: rawName
                )
            )
        }

        return ports
    }

    private func parsePort(from name: String) -> Int? {
        let cleaned = name
            .replacingOccurrences(of: " (LISTEN)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let colon = cleaned.lastIndex(of: ":") else {
            return nil
        }

        let portText = cleaned[cleaned.index(after: colon)...]
            .split(separator: " ")
            .first

        guard let portText else {
            return nil
        }

        return Int(portText)
    }

    private func parseAddress(from name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "TCP ", with: "")
            .replacingOccurrences(of: " (LISTEN)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let colon = cleaned.lastIndex(of: ":") else {
            return cleaned
        }

        let address = cleaned[..<colon]
        return address.isEmpty ? "*" : String(address)
    }
}
