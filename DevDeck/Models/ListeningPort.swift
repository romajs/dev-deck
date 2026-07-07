import Foundation

struct ListeningPort: Identifiable, Hashable {
    let port: Int
    let pid: Int32
    let processName: String
    let command: String
    let user: String
    let protocolName: String
    let address: String
    let rawName: String

    var id: String {
        "\(pid)-\(port)-\(protocolName)-\(address)"
    }

    var isCommonDevPort: Bool {
        Self.commonDevPorts.contains(port)
    }

    static let commonDevPorts = RuntimeKind.allCommonPorts
}
