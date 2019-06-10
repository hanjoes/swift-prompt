// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPrompt",
    products: [
        .executable(name: "swift_prompt", targets: ["SwiftPrompt"]),
        .executable(name: "swift_prompt_nanny", targets: ["SwiftPromptNanny"])
    ],
    dependencies: [
         .package(url: "https://github.com/hanjoes/Termbo", from: "0.1.0"),
         .package(url: "https://github.com/hanjoes/swift-git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "SwiftPrompt",
            dependencies: ["Termbo", "SwiftGitLib"]),
        .target(
            name: "SwiftPromptNanny",
            dependencies: ["SwiftGitLib"]),
        .testTarget(
            name: "SwiftPromptTests",
            dependencies: ["SwiftPrompt"]),
    ]
)
