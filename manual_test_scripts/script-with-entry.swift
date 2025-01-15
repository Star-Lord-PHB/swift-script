import Foundation 


@main
struct Runner {

    static func main() async throws {

        let cwd = FileManager.default.currentDirectoryPath
        print(
            """
            script with main entry point executed 
            cwd: \(cwd)
            os: \(ProcessInfo.processInfo.operatingSystemVersionString)
            """
        )

    }

}
