import Foundation
import ConcurrencyPlus


final class ProcessLock: Sendable {

    let path: URL 
    let fileLock: NSDistributedLock

    init(path: URL = AppEnv.default.processLockUrl) {
        guard let lock = NSDistributedLock(path: path.compactPath()) else {
            fatalError("Failed to create lock")
        }
        SignalHandler.registerCleanUp { lock.unlock() }
        self.path = path
        self.fileLock = lock
    }

    func lock() async throws {
        let startTime = Date()
        var warned = false
        while await !fileLock.try() {
            if !warned && Date().timeIntervalSince(startTime) > 30 {
                print("""
                    Warning: waiting for lock for more than 30 seconds
                    
                    It might be caused by one of the following reasons:
                    1. another swift-script process is still running 
                    2. the lock file is not cleaned up properly
                    
                    You can keep waiting or stop the current process by pressing Ctrl+C
                    If you are sure that no other process is running, you can manually remove \ 
                    the lock file at \(path.compactPath(percentEncoded: false))
                    """.yellow
                )
                warned = true
            }
            if #available(macOS 13, *) {
                try await Task.sleep(for: .milliseconds(100))
            } else {
                try await Task.sleep(nanoseconds: 100 * 1_000_000)
            }
        }
    }

    func unlock() async {
        await fileLock.unlock()
    }

    func withLock<T>(_ body: () async throws -> T) async throws -> T {
        try await lock()
        do {
            let result = try await body()
            await unlock()
            return result
        } catch {
            await unlock()
            throw error
        }
    }

    static let shared: ProcessLock = .init()

}


extension NSDistributedLock {

    func `try`() async -> Bool {
        await launchTask(on: .io) { self.try() }
    }

    func unlock() async {
        await launchTask(on: .io) { self.unlock() }
    }

}