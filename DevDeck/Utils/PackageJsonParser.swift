import Foundation

struct ParsedPackageJson {
    let name: String?
    let scripts: [String: String]
    let dependencies: [String: String]
    let devDependencies: [String: String]

    var allDependencyNames: Set<String> {
        Set(dependencies.keys.map { $0.lowercased() } + devDependencies.keys.map { $0.lowercased() })
    }
}

enum PackageJsonParser {
    static func parse(at url: URL) -> ParsedPackageJson? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return ParsedPackageJson(
            name: root["name"] as? String,
            scripts: root["scripts"] as? [String: String] ?? [:],
            dependencies: root["dependencies"] as? [String: String] ?? [:],
            devDependencies: root["devDependencies"] as? [String: String] ?? [:]
        )
    }
}
