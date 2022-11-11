// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "storekitfacade-ios",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "StoreKitFacade",
            type: .dynamic,
            targets: ["StoreKitFacade"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "StoreKitFacade",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
           ]
        ),
        .testTarget(
            name: "storekitfacade-iosTests",
            dependencies: ["StoreKitFacade"],
            path: "Tests"
        ),
    ]
)
