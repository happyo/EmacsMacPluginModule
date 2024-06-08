// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EmacsMacPluginModule",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EmacsMacPluginModule",
            type: .dynamic,
            targets: ["EmacsMacPluginModule"]),
    ],
    dependencies: [
    .package(
      url: "https://github.com/SavchenkoValeriy/emacs-swift-module.git",
      revision: "c776706c9338b8ba72a76a2128fd89bd4ac4269e")
  ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EmacsMacPluginModule",
            dependencies: [
                .product(
                    name: "EmacsSwiftModule",
                    package: "emacs-swift-module")
            ],
            plugins: [
                .plugin(
                    name: "ModuleFactoryPlugin",
                    package: "emacs-swift-module")
            ]
        ),
        .testTarget(
            name: "EmacsMacPluginModuleTests",
            dependencies: ["EmacsMacPluginModule"]),
    ]
)
