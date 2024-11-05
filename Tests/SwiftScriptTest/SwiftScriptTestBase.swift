import FoundationPlusEssential
import Testing
@testable import SwiftScript


class SwiftScriptTestBase {

    init() async throws {

        let fakeHomeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        setenv("HOME", fakeHomeDir.compactPath(percentEncoded: false), 1)

        try await appFolderSetup()
    }


    deinit {
        try? FileManager.default.removeItem(at: AppPath.appBaseUrl)
    }


    private func appFolderSetup() async throws {

        try await FileManager.default.createDirectory(
            at: AppPath.appBaseUrl,
            withIntermediateDirectories: true
        )

        

    }

}