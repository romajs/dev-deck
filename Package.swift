// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DevDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevDeck", targets: ["DevDeck"])
    ],
    targets: [
        .executableTarget(
            name: "DevDeck",
            path: "DevDeck"
        )
    ]
)
