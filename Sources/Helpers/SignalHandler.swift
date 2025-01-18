import Foundation
import ConcurrencyPlus


private let signalStream = {
#if os(Windows)
    let signals = [SIGINT, SIGTERM]
#else
    let signals = [SIGINT, SIGTERM, SIGHUP, SIGQUIT]
#endif
    for sig in signals {
        signal(sig, notifySignal(_:))
    }
    return AsyncStream<Int32>.makeStream()
}()


private func notifySignal(_ signal: Int32) {
    signalStream.continuation.yield(signal)
}


enum SignalHandler {

    static let signal: Mutex<Int32> = .init(-1)
    
    static func startSignalListening() {
        Task {
            let sig = await signalStream.stream.first(where: { _ in true })
            signal.withLock { $0 = sig ?? -1 }
            tasks.withLock {
                $0.forEach { $0.cancel() }
            }
        }
    }
    
    
    static private let tasks: Mutex<[Task<Void, Error>]> = .init([])
    
    
    static func registerTask(_ task: Task<Void, Error>) {
        tasks.withLock {
            $0.append(task)
        }
    }
    
}

