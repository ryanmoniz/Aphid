import PackageDescription

let package = Package(
    name: "Sunapsis",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/BlueSSLService.git", majorVersion: 0, minor: 12),
    ],
    exclude: ["Sunapsis.xcodeproj", "README.md", "Sources/Info.plist"]
)
