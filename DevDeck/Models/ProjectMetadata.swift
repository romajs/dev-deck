import Foundation

enum PackageManager: String, Codable, CaseIterable {
    case pnpm
    case npm
    case yarn
    case bun
    case deno
    case uv
    case poetry
    case pipenv
    case pip
    case bundler
    case maven
    case gradle
    case cargo
    case go
    case composer
    case dotnet
    case mix
    case unknown

    var displayName: String {
        switch self {
        case .pnpm: "pnpm"
        case .npm: "npm"
        case .yarn: "Yarn"
        case .bun: "Bun"
        case .deno: "Deno"
        case .uv: "uv"
        case .poetry: "Poetry"
        case .pipenv: "Pipenv"
        case .pip: "pip"
        case .bundler: "Bundler"
        case .maven: "Maven"
        case .gradle: "Gradle"
        case .cargo: "Cargo"
        case .go: "Go"
        case .composer: "Composer"
        case .dotnet: ".NET"
        case .mix: "Mix"
        case .unknown: "Unknown"
        }
    }

    func runScriptCommand(scriptName: String, port: Int) -> String {
        switch self {
        case .pnpm:
            "PORT=\(port) pnpm \(scriptName)"
        case .npm:
            "PORT=\(port) npm run \(scriptName)"
        case .yarn:
            "PORT=\(port) yarn \(scriptName)"
        case .bun:
            "PORT=\(port) bun run \(scriptName)"
        case .deno:
            "PORT=\(port) deno task \(scriptName)"
        case .uv:
            "PORT=\(port) uv run \(scriptName)"
        case .poetry:
            "PORT=\(port) poetry run \(scriptName)"
        case .pipenv:
            "PORT=\(port) pipenv run \(scriptName)"
        case .pip:
            "PORT=\(port) python -m \(scriptName)"
        case .bundler:
            "PORT=\(port) bundle exec \(scriptName)"
        case .maven:
            "SERVER_PORT=\(port) mvn spring-boot:run"
        case .gradle:
            "SERVER_PORT=\(port) ./gradlew bootRun"
        case .cargo:
            "PORT=\(port) cargo run"
        case .go:
            "PORT=\(port) go run ."
        case .composer:
            "PORT=\(port) composer run \(scriptName)"
        case .dotnet:
            "ASPNETCORE_URLS=http://localhost:\(port) dotnet run"
        case .mix:
            "PORT=\(port) mix phx.server"
        case .unknown:
            "PORT=\(port) \(scriptName)"
        }
    }
}

enum RuntimeKind: String, Codable, CaseIterable {
    case node = "Node.js"
    case deno = "Deno"
    case bun = "Bun"
    case python = "Python"
    case ruby = "Ruby"
    case java = "Java/JVM"
    case go = "Go"
    case rust = "Rust"
    case php = "PHP"
    case dotnet = ".NET"
    case elixir = "Elixir"
    case other = "Other"

    var displayName: String {
        rawValue
    }

    var commonPorts: Set<Int> {
        switch self {
        case .node, .deno, .bun:
            [3000, 3001, 3002, 4000, 4173, 5173, 6006, 9229]
        case .python:
            [5000, 8000, 8001, 8501, 8888, 7860]
        case .ruby:
            [3000, 9292]
        case .java:
            [8080, 8081, 9000, 5005]
        case .go:
            [3000, 8000, 8080]
        case .rust:
            [3000, 8000, 8080]
        case .php:
            [8000, 8080, 9003]
        case .dotnet:
            [5000, 5001, 7000, 7001]
        case .elixir:
            [4000]
        case .other:
            []
        }
    }

    static var allCommonPorts: Set<Int> {
        RuntimeKind.allCases.reduce(into: Set<Int>()) { ports, runtime in
            ports.formUnion(runtime.commonPorts)
        }
    }

    var versionCommand: [String]? {
        switch self {
        case .node: ["node", "-v"]
        case .deno: ["deno", "--version"]
        case .bun: ["bun", "--version"]
        case .python: ["python3", "--version"]
        case .ruby: ["ruby", "--version"]
        case .java: ["java", "-version"]
        case .go: ["go", "version"]
        case .rust: ["rustc", "--version"]
        case .php: ["php", "-v"]
        case .dotnet: ["dotnet", "--version"]
        case .elixir: ["elixir", "--version"]
        case .other: nil
        }
    }
}

enum FrameworkKind: String, Codable, CaseIterable {
    case next = "Next.js"
    case vite = "Vite"
    case nest = "NestJS"
    case express = "Express"
    case fastify = "Fastify"
    case remix = "Remix"
    case astro = "Astro"
    case storybook = "Storybook"
    case nuxt = "Nuxt"
    case django = "Django"
    case flask = "Flask"
    case fastAPI = "FastAPI"
    case uvicorn = "Uvicorn"
    case gunicorn = "Gunicorn"
    case jupyter = "Jupyter"
    case streamlit = "Streamlit"
    case gradio = "Gradio"
    case rails = "Rails"
    case puma = "Puma"
    case rack = "Rack"
    case springBoot = "Spring Boot"
    case quarkus = "Quarkus"
    case micronaut = "Micronaut"
    case tomcat = "Tomcat"
    case axum = "Axum"
    case actix = "Actix"
    case rocket = "Rocket"
    case laravel = "Laravel"
    case symfony = "Symfony"
    case aspNetCore = "ASP.NET Core"
    case phoenix = "Phoenix"
    case other = "Other"

    var displayName: String {
        rawValue
    }
}

struct ProjectMetadata: Equatable {
    let name: String
    let projectFolder: String?
    let manifestPath: String?
    let scripts: [String: String]
    let dependencies: Set<String>
    let runtime: RuntimeKind
    let framework: FrameworkKind
    let packageManager: PackageManager

    var packageJsonPath: String? {
        guard manifestPath?.hasSuffix("package.json") == true else {
            return nil
        }

        return manifestPath
    }

    var detectedStartScript: String? {
        if scripts.keys.contains("dev") {
            return "dev"
        }

        if scripts.keys.contains("start") {
            return "start"
        }

        if scripts.keys.contains("server") {
            return "server"
        }

        return scripts.keys.sorted().first
    }

    static let unknown = ProjectMetadata(
        name: "Unknown project",
        projectFolder: nil,
        manifestPath: nil,
        scripts: [:],
        dependencies: [],
        runtime: .other,
        framework: .other,
        packageManager: .unknown
    )
}
