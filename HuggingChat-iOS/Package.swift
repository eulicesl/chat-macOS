// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HuggingChat-iOS",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "HuggingChat-iOS",
            targets: ["HuggingChat-iOS"]
        ),
        .library(
            name: "HuggingChatKeyboard",
            targets: ["HuggingChatKeyboard"]
        ),
        .library(
            name: "HuggingChatWidget",
            targets: ["HuggingChatWidget"]
        ),
        .library(
            name: "ShareExtension",
            targets: ["ShareExtension"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", branch: "main"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
        .package(url: "https://github.com/Romain-Guillot/GzipSwift", from: "6.0.1"),
        .package(url: "https://github.com/mxcl/Path.swift", from: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.0"),
        .package(url: "https://github.com/EmergeTools/Pow", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "HuggingChat-iOS",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Gzip", package: "GzipSwift"),
                .product(name: "Path", package: "Path.swift"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "Pow", package: "Pow")
            ],
            path: "HuggingChat-iOS"
        ),
        .target(
            name: "HuggingChatKeyboard",
            dependencies: [
                "HuggingChat-iOS"
            ],
            path: "HuggingChatKeyboard"
        ),
        .target(
            name: "HuggingChatWidget",
            dependencies: [
                "HuggingChat-iOS"
            ],
            path: "HuggingChatWidget"
        ),
        .target(
            name: "ShareExtension",
            dependencies: [
                "HuggingChat-iOS"
            ],
            path: "ShareExtension"
        )
    ]
)
