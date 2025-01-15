import Foundation
import CodableMacro


@Codable
final class Logger: @unchecked Sendable {

    private(set) var verbose: Bool = false 
    private(set) var initialized: Bool = false
    @CodingIgnore
    private let lock: NSLock = .init()


    func initialize(verbose: Bool) {
        guard !initialized else { return }
        lock.withLock {
            guard !initialized else { return }
            self.initialized = true
            self.verbose = verbose
        }
    }


    func printInfo(_ message: String) {
        print(message)
    }


    func printDebug(_ message: String) {
        if verbose {
            print(message.skyBlue)
        }
    }


    func printWarning(_ message: String) {
        printStdErr(message.yellow)
    }

}