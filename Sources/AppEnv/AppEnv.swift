import Foundation
import FileManagerPlus


final class AppEnv: Sendable {

    let appBasePath: FilePath 
    let processLock: ProcessLock

    init(base: FilePath = defaultBasePath) {
        self.appBasePath = base
        self.processLock = .init(path: appBasePath.appending("lock.lock"))
    }

    static let defaultBasePath: FilePath = FileManager.default.homeDirectoryFilePathForCurrentUser
        .appending(".swift-script")

    static let `default` = AppEnv()

}


extension AppEnv {

    func withProcessLock<R>(_ operation: () async throws -> R) async throws -> R {
        try await processLock.withLock(operation)
    }

}


extension AppEnv: Codable {

    enum Keys: CodingKey {
        case appBaseUrl
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(appBasePath, forKey: .appBaseUrl)
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let appBasePath = try container.decode(FilePath.self, forKey: .appBaseUrl)
        self.init(base: appBasePath)
    }

}