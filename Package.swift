// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftPrompt",
    products: [
        .executable(name: "swift_prompt", targets: ["SwiftPrompt"]),
        .executable(name: "swift_prompt_nanny", targets: ["SwiftPromptNanny"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hanjoes/swift-termina", from: "1.0.0"),
        .package(url: "https://github.com/hanjoes/swift-git", from: "2.0.0"),
        .package(url: "https://github.com/hanjoes/swift-daemon", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftPrompt",
            dependencies: ["TerminaLib", "SwiftPromptLib"]
        ),
        .target(
            name: "SwiftPromptNanny",
            dependencies: ["SwiftPromptLib", "SwiftDaemonLib"]
        ),
        .target(
            name: "SwiftPromptLib",
            dependencies: ["SwiftGitLib"]
        ),
    ]
)
