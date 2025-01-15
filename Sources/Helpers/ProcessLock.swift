import Foundation
import ConcurrencyPlus
import FileManagerPlus


final class ProcessLock: Sendable {

    let path: String

    init(path: String) {
        self.path = path
    }

    convenience init(path: FilePath = AppEnv.default.processLockPath) {
        self.init(path: path.string)
    }


    func withLock<T>(_ operation: () async throws -> T) async throws -> T {
        
        let fd = try await Task.launch(on: .io) {
            let fd = open(self.path, O_CREAT | O_RDWR, 0o666)
            guard fd >= 0 else {
                throw Error(code: errno, message: "Failed to open lock file")
            }
            return fd
        }

        var warned = false
        let startTime = Date()

        while true {

            if !warned && Date().timeIntervalSince(startTime) > 30 {
                printFromStart("""
                    Warning: waiting for lock for more than 30 seconds
                    
                    It might be caused by one of the following reasons:
                    1. another swift-script process is still running 
                    2. the lock file is not cleaned up properly
                    
                    You can keep waiting or stop the current process by pressing Ctrl+C
                    If you are sure that no other process is running, you can manually remove \ 
                    the lock file at \(self.path)
                    """.yellow
                )
                warned = true
            }

            let (result, localErrno) = await Task.launch(on: .io) { 
                let result = flock(fd, LOCK_EX | LOCK_NB) 
                return (result, errno)
            }

            if result == 0 { break }

            guard localErrno == EWOULDBLOCK else {
                close(fd)
                throw Error(code: errno, message: "Failed to acquire lock")
            }

            if #available(macOS 13, *) {
                try await Task.sleep(for: .milliseconds(100))
            } else {
                try await Task.sleep(nanoseconds: 100 * 1_000_000)
            }

        }

        return try await execute {
            try await operation()
        } finally: {
            await Task.launch(on: .io) { 
                flock(fd, LOCK_UN)
                close(fd) 
            }
        }

    }

}


extension ProcessLock {

    struct Error: LocalizedError {
        let code: Int32
        let message: String
        var errorDescription: String? { "File Lock Error (\(code)) - \(message)" }
    }

}