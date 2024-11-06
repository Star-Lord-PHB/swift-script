import Foundation


final class AppEnv: Sendable {

    let appBaseUrl: URL 
    let processLock: ProcessLock

    init(base: URL = defaultBaseUrl) {
        self.appBaseUrl = base
        self.processLock = .init(path: appBaseUrl.appendingCompat(path: "lock.lock"))
    }

    static let defaultBaseUrl: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingCompat(path: ".swift-script")

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
        try container.encode(appBaseUrl, forKey: .appBaseUrl)
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let appBaseUrl = try container.decode(URL.self, forKey: .appBaseUrl)
        self.init(base: appBaseUrl)
    }

}