// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "storekitfacade-ios",
    products: [
        .library(
            name: "storekitfacade-ios",
            targets: ["storekitfacade-ios"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "storekitfacade-ios",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
               .linkedFramework("StoreKit")
           ]
        ),
        .testTarget(
            name: "storekitfacade-iosTests",
            dependencies: ["storekitfacade-ios"],
            path: "Tests"
        ),
    ]
)
