import Foundation

final class DevProjectDetector {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func detect(
        cwd: String?,
        processName: String,
        command: String,
        ignoredSupportPaths: [String]
    ) -> ProjectMetadata {
        guard let cwd, !cwd.isEmpty else {
            if isIgnoredSupportPathText(command, ignoredSupportPaths: ignoredSupportPaths) {
                return .unknown
            }

            let runtime = detectRuntime(processName: processName, command: command, manifestName: nil, dependencies: [])
            return ProjectMetadata(
                name: processName,
                projectFolder: nil,
                manifestPath: nil,
                scripts: [:],
                dependencies: [],
                runtime: runtime,
                framework: detectFramework(runtime: runtime, command: command, dependencies: [], manifestName: nil),
                packageManager: inferPackageManager(projectFolder: nil, manifestName: nil, command: command)
            )
        }

        let cwdURL = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
        guard !isIgnoredSupportPath(cwdURL.path, ignoredSupportPaths: ignoredSupportPaths) else {
            return .unknown
        }

        let manifestURL = nearestManifest(from: cwdURL, ignoredSupportPaths: ignoredSupportPaths)
        let manifestName = manifestURL?.lastPathComponent
        let parsedPackage = manifestName == "package.json" ? manifestURL.flatMap(PackageJsonParser.parse) : nil
        let dependencies = parsedPackage?.allDependencyNames ?? manifestDependencies(from: manifestURL)
        let runtime = detectRuntime(
            processName: processName,
            command: command,
            manifestName: manifestName,
            dependencies: dependencies
        )
        let projectFolder = manifestURL?.deletingLastPathComponent() ?? cwdURL

        return ProjectMetadata(
            name: parsedPackage?.name ?? projectFolder.lastPathComponent,
            projectFolder: projectFolder.path,
            manifestPath: manifestURL?.path,
            scripts: parsedPackage?.scripts ?? [:],
            dependencies: dependencies,
            runtime: runtime,
            framework: detectFramework(
                runtime: runtime,
                command: command,
                dependencies: dependencies,
                manifestName: manifestName
            ),
            packageManager: inferPackageManager(
                projectFolder: projectFolder,
                manifestName: manifestName,
                command: command
            )
        )
    }

    func isDevApp(
        processName: String,
        command: String,
        project: ProjectMetadata,
        ignoredSupportPaths: [String]
    ) -> Bool {
        if let projectFolder = project.projectFolder,
           isIgnoredSupportPath(projectFolder, ignoredSupportPaths: ignoredSupportPaths) {
            return false
        }

        if isIgnoredSupportPathText(command, ignoredSupportPaths: ignoredSupportPaths) {
            return false
        }

        if project.runtime != .other || project.framework != .other {
            return true
        }

        let lowerProcess = processName.lowercased()
        let lowerCommand = command.lowercased()
        return runtimeTerms.contains { term in
            lowerProcess.contains(term) || lowerCommand.contains(term)
        }
    }

    private func nearestManifest(from start: URL, ignoredSupportPaths: [String]) -> URL? {
        guard !isIgnoredSupportPath(start.path, ignoredSupportPaths: ignoredSupportPaths) else {
            return nil
        }

        var current = start

        for _ in 0..<32 {
            if isIgnoredSupportPath(current.path, ignoredSupportPaths: ignoredSupportPaths) {
                return nil
            }

            for name in manifestNames {
                let candidate = current.appendingPathComponent(name)
                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }

            if let csproj = firstFile(in: current, extension: "csproj") {
                return csproj
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }

            current = parent
        }

        return nil
    }

    private func firstFile(in folder: URL, extension fileExtension: String) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return contents.first { $0.pathExtension == fileExtension }
    }

    private func detectRuntime(
        processName: String,
        command: String,
        manifestName: String?,
        dependencies: Set<String>
    ) -> RuntimeKind {
        let lowerProcess = processName.lowercased()
        let lowerCommand = command.lowercased()
        let lowerManifest = manifestName?.lowercased()

        if lowerProcess.contains("bun") || lowerCommand.contains("bun ") || lowerManifest == "bun.lock" || lowerManifest == "bun.lockb" {
            return .bun
        }

        if lowerProcess.contains("deno") || lowerCommand.contains("deno ") || lowerManifest == "deno.json" || lowerManifest == "deno.jsonc" {
            return .deno
        }

        if lowerProcess.contains("node") ||
            lowerCommand.contains("node") ||
            lowerManifest == "package.json" ||
            dependencies.contains("next") ||
            dependencies.contains("vite") {
            return .node
        }

        if lowerProcess.contains("python") ||
            lowerCommand.contains("python") ||
            lowerCommand.contains("uvicorn") ||
            lowerCommand.contains("gunicorn") ||
            lowerManifest == "pyproject.toml" ||
            lowerManifest == "requirements.txt" ||
            lowerManifest == "pipfile" {
            return .python
        }

        if lowerProcess.contains("ruby") ||
            lowerProcess.contains("puma") ||
            lowerCommand.contains("rails") ||
            lowerCommand.contains("bundle") ||
            lowerManifest == "gemfile" {
            return .ruby
        }

        if lowerProcess.contains("java") ||
            lowerCommand.contains("java") ||
            lowerCommand.contains("spring") ||
            lowerManifest == "pom.xml" ||
            lowerManifest == "build.gradle" ||
            lowerManifest == "build.gradle.kts" {
            return .java
        }

        if lowerProcess == "go" ||
            lowerCommand.contains("go run") ||
            lowerManifest == "go.mod" {
            return .go
        }

        if lowerProcess.contains("cargo") ||
            lowerCommand.contains("cargo run") ||
            lowerManifest == "cargo.toml" {
            return .rust
        }

        if lowerProcess.contains("php") ||
            lowerCommand.contains("artisan") ||
            lowerManifest == "composer.json" {
            return .php
        }

        if lowerProcess.contains("dotnet") ||
            lowerCommand.contains("dotnet") ||
            manifestName?.hasSuffix(".csproj") == true {
            return .dotnet
        }

        if lowerProcess.contains("beam.smp") ||
            lowerCommand.contains("mix phx.server") ||
            lowerManifest == "mix.exs" {
            return .elixir
        }

        return .other
    }

    private func detectFramework(
        runtime: RuntimeKind,
        command: String,
        dependencies: Set<String>,
        manifestName: String?
    ) -> FrameworkKind {
        let lowerCommand = command.lowercased()

        if lowerCommand.contains("storybook") || dependencies.contains(where: { $0.hasPrefix("@storybook/") }) {
            return .storybook
        }

        if lowerCommand.contains("next") || dependencies.contains("next") {
            return .next
        }

        if lowerCommand.contains("vite") || dependencies.contains("vite") {
            return .vite
        }

        if lowerCommand.contains("nest") || dependencies.contains("@nestjs/core") {
            return .nest
        }

        if lowerCommand.contains("remix") || dependencies.contains("@remix-run/react") || dependencies.contains("@remix-run/node") {
            return .remix
        }

        if lowerCommand.contains("astro") || dependencies.contains("astro") {
            return .astro
        }

        if lowerCommand.contains("nuxt") || dependencies.contains("nuxt") {
            return .nuxt
        }

        if dependencies.contains("fastify") {
            return .fastify
        }

        if dependencies.contains("express") {
            return .express
        }

        if runtime == .python {
            if lowerCommand.contains("streamlit") || dependencies.contains("streamlit") {
                return .streamlit
            }

            if lowerCommand.contains("jupyter") || dependencies.contains("jupyter") {
                return .jupyter
            }

            if lowerCommand.contains("gradio") || dependencies.contains("gradio") {
                return .gradio
            }

            if lowerCommand.contains("uvicorn") || dependencies.contains("uvicorn") {
                return dependencies.contains("fastapi") ? .fastAPI : .uvicorn
            }

            if lowerCommand.contains("gunicorn") || dependencies.contains("gunicorn") {
                return .gunicorn
            }

            if lowerCommand.contains("django") || dependencies.contains("django") {
                return .django
            }

            if lowerCommand.contains("flask") || dependencies.contains("flask") {
                return .flask
            }

            if dependencies.contains("fastapi") {
                return .fastAPI
            }
        }

        if runtime == .ruby {
            if lowerCommand.contains("rails") {
                return .rails
            }

            if lowerCommand.contains("puma") {
                return .puma
            }

            if manifestName?.lowercased() == "gemfile" {
                return .rack
            }
        }

        if runtime == .java {
            if lowerCommand.contains("spring") {
                return .springBoot
            }

            if lowerCommand.contains("quarkus") {
                return .quarkus
            }

            if lowerCommand.contains("micronaut") {
                return .micronaut
            }

            if lowerCommand.contains("tomcat") {
                return .tomcat
            }
        }

        if runtime == .rust {
            if lowerCommand.contains("axum") || dependencies.contains("axum") {
                return .axum
            }

            if lowerCommand.contains("actix") || dependencies.contains("actix-web") {
                return .actix
            }

            if lowerCommand.contains("rocket") || dependencies.contains("rocket") {
                return .rocket
            }
        }

        if runtime == .php {
            if lowerCommand.contains("artisan") || dependencies.contains("laravel/framework") {
                return .laravel
            }

            if dependencies.contains("symfony/framework-bundle") || lowerCommand.contains("symfony") {
                return .symfony
            }
        }

        if runtime == .dotnet {
            return .aspNetCore
        }

        if runtime == .elixir {
            return .phoenix
        }

        return .other
    }

    private func inferPackageManager(projectFolder: URL?, manifestName: String?, command: String) -> PackageManager {
        let lowerCommand = command.lowercased()
        let lowerManifest = manifestName?.lowercased()

        if lowerCommand.contains("pnpm") { return .pnpm }
        if lowerCommand.contains("yarn") { return .yarn }
        if lowerCommand.contains("bun") { return .bun }
        if lowerCommand.contains("deno") { return .deno }
        if lowerCommand.contains("npm") { return .npm }
        if lowerCommand.contains("uv ") { return .uv }
        if lowerCommand.contains("poetry") { return .poetry }
        if lowerCommand.contains("pipenv") { return .pipenv }
        if lowerCommand.contains("bundle") { return .bundler }
        if lowerCommand.contains("mvn") { return .maven }
        if lowerCommand.contains("gradle") { return .gradle }
        if lowerCommand.contains("cargo") { return .cargo }
        if lowerCommand.contains("go run") { return .go }
        if lowerCommand.contains("composer") { return .composer }
        if lowerCommand.contains("dotnet") { return .dotnet }
        if lowerCommand.contains("mix ") { return .mix }

        if let projectFolder {
            if exists("pnpm-lock.yaml", in: projectFolder) { return .pnpm }
            if exists("yarn.lock", in: projectFolder) { return .yarn }
            if exists("bun.lockb", in: projectFolder) || exists("bun.lock", in: projectFolder) { return .bun }
            if exists("package-lock.json", in: projectFolder) { return .npm }
            if exists("uv.lock", in: projectFolder) { return .uv }
            if exists("poetry.lock", in: projectFolder) { return .poetry }
            if exists("Pipfile.lock", in: projectFolder) { return .pipenv }
            if exists("Gemfile.lock", in: projectFolder) { return .bundler }
            if exists("gradlew", in: projectFolder) { return .gradle }
        }

        switch lowerManifest {
        case "package.json": return .npm
        case "deno.json", "deno.jsonc": return .deno
        case "pyproject.toml", "requirements.txt": return .pip
        case "pipfile": return .pipenv
        case "gemfile": return .bundler
        case "pom.xml": return .maven
        case "build.gradle", "build.gradle.kts": return .gradle
        case "cargo.toml": return .cargo
        case "go.mod": return .go
        case "composer.json": return .composer
        case "mix.exs": return .mix
        default:
            if manifestName?.hasSuffix(".csproj") == true {
                return .dotnet
            }

            return .unknown
        }
    }

    private func manifestDependencies(from manifestURL: URL?) -> Set<String> {
        guard let manifestURL,
              let text = try? String(contentsOf: manifestURL, encoding: .utf8).lowercased() else {
            return []
        }

        let dependencyTerms = [
            "django", "flask", "fastapi", "uvicorn", "gunicorn", "streamlit", "gradio", "jupyter",
            "axum", "actix-web", "rocket",
            "laravel/framework", "symfony/framework-bundle"
        ]

        return Set(dependencyTerms.filter { text.contains($0) })
    }

    private func exists(_ name: String, in folder: URL) -> Bool {
        fileManager.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    private func isIgnoredSupportPath(_ path: String, ignoredSupportPaths: [String]) -> Bool {
        let standardizedPath = NSString(string: path).standardizingPath
        let ignoredPrefixes = ignoredSupportPaths.map(standardizePath)

        return ignoredPrefixes.contains { prefix in
            standardizedPath == prefix || standardizedPath.hasPrefix(prefix + "/")
        }
    }

    private func isIgnoredSupportPathText(_ text: String, ignoredSupportPaths: [String]) -> Bool {
        let lowerText = text.lowercased()
        let ignoredPrefixes = ignoredSupportPaths.map(standardizePath)

        return ignoredPrefixes.contains { prefix in
            let lowerPrefix = prefix.lowercased()
            return commandText(lowerText, containsPathPrefix: lowerPrefix)
        }
    }

    private func standardizePath(_ path: String) -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return NSString(string: expandedPath).standardizingPath
    }

    private func commandText(_ lowerText: String, containsPathPrefix lowerPrefix: String) -> Bool {
        lowerText == lowerPrefix ||
            lowerText.hasPrefix(lowerPrefix + "/") ||
            lowerText.hasPrefix(lowerPrefix + " ") ||
            lowerText.hasSuffix(" " + lowerPrefix) ||
            lowerText.contains(" " + lowerPrefix + "/") ||
            lowerText.contains("\"" + lowerPrefix + "/") ||
            lowerText.contains("'" + lowerPrefix + "/") ||
            lowerText.contains("=" + lowerPrefix + "/")
    }

    private let manifestNames = [
        "package.json",
        "deno.json",
        "deno.jsonc",
        "pyproject.toml",
        "requirements.txt",
        "Pipfile",
        "Gemfile",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "Cargo.toml",
        "go.mod",
        "composer.json",
        "mix.exs"
    ]

    private let runtimeTerms = [
        "node", "next", "vite", "tsx", "ts-node", "nodemon", "bun", "deno",
        "python", "uvicorn", "gunicorn", "django", "flask", "fastapi", "streamlit", "jupyter", "gradio",
        "ruby", "rails", "puma", "bundle",
        "java", "spring", "quarkus", "micronaut", "tomcat",
        "go run", "cargo", "rust", "php", "artisan", "dotnet", "beam.smp", "mix phx"
    ]
}
