import Foundation
import FileManagerPlus


final class AppEnv: @unchecked Sendable {

    let appBasePath: FilePath 
    let processLock: ProcessLock
    private var _appConfig: AppConfig? = nil 
    private let lock: NSLock = .init()

    private(set) var appConfig: AppConfig {
        get { 
            guard let config = _appConfig else {
                fatalError("AppEnv is not initialized")
            }
            return config
        }
        set { _appConfig = newValue }
    }


    init(base: FilePath = defaultBasePath) {
        self.appBasePath = base
        self.processLock = .init(path: appBasePath.appending("lock.lock"))
    }


    @discardableResult
    func initialize() async throws -> Self {
        guard _appConfig == nil else { return self }
        let appConfig = try await JSONDecoder()
            .decode(AppConfig.self, from: .read(contentAt: configFilePath))
        lock.withLock {
            guard _appConfig == nil else { return }
            _appConfig = appConfig
        }
        return self
    }


    static let defaultBasePath: FilePath = FileManager.default.homeDirectoryFilePathForCurrentUser
        .appending(".swift-script")

    static let basePathEnvKey: String = "SWIFT_SCRIPT_HOME"

    static let `default`: AppEnv = .init()
    static func fromEnv(default: AppEnv = .default) -> AppEnv {
        guard let path = ProcessInfo.processInfo.environment[basePathEnvKey] else {
            return `default`
        }
        return .init(base: FilePath(path))
    }

}


extension AppEnv {

    func withProcessLock<R>(_ operation: () async throws -> R) async throws -> R {
        try await processLock.withLock(operation)
    }


    func saveAppConfig(_ config: AppConfig) async throws {

        try Task.checkCancellation()

        try await JSONEncoder().encode(config).write(to: configFilePath)
        self.appConfig = config

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