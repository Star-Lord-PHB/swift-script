import Testing
@testable import SwiftScript


@Suite("Test Version")
struct VersionTest {

    @Test(
        "Valid Version Parsing",
        arguments: [
            ("1.0.0", .init(major: 1, minor: 0, patch: 0)),
            ("v1.2.3", .init(major: 1, minor: 2, patch: 3)),
            ("1.2.3-alpha", .init(major: 1, minor: 2, patch: 3, prerelease: ["alpha"])),
            ("1.2.3+beta", .init(major: 1, minor: 2, patch: 3, build: ["beta"])),
            ("1.2.3-alpha.beta", .init(major: 1, minor: 2, patch: 3, prerelease: ["alpha", "beta"])),
            ("1.0.0-alpha.1", .init(major: 1, minor: 0, patch: 0, prerelease: ["alpha", "1"])),
            ("V1.0.0-rc.1", .init(major: 1, minor: 0, patch: 0, prerelease: ["rc", "1"])),
        ] as [(String, SemanticVersion)]
    )
    func test1(string: String, expected: SemanticVersion) async throws {
        
        let version = try SemanticVersion.parse(string)
        #expect(version == expected)
        
    }


    @Test(
        "Invalid Version String",
        arguments: [
            "alpha-beta",
            "1.0.0-alpha.beta+",
            "1.0.0-+beta",
            "1.a.0",
        ]
    )
    func test2(string: String) async throws {
        #expect(throws: ParseError.self) {
            try SemanticVersion.parse(string)
        }
    }

}