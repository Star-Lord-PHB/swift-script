import Foundation
import ConcurrencyPlus


private let signalStream = {
    let signals = [SIGINT, SIGTERM, SIGHUP, SIGQUIT]
    for sig in signals {
        signal(sig, notifySignal(_:))
    }
    return AsyncStream<Int32>.makeStream()
}()


private func notifySignal(_ signal: Int32) {
    signalStream.continuation.yield(signal)
}


enum SignalHandler {
    
    static func startSignalListening() {
        Task {
            let _ = await signalStream.stream.first(where: { _ in true })
            for task in tasks {
                await task.cancelAndWait()
            }
            for operation in cleanUpOperations {
                await operation()
            }
            exit(0)
        }
    }
    
    
    nonisolated(unsafe) static private var cleanUpOperations: [@MainActor () async -> Void] = []
    nonisolated(unsafe) static private var tasks: [Task<Void, Error>] = []
    
    
    static func registerCleanUp(operation: @MainActor @escaping () async -> Void) {
        cleanUpOperations.append(operation)
    }
    
    
    static func registerTask(_ task: Task<Void, Error>) {
        tasks.append(task)
    }
    
}

