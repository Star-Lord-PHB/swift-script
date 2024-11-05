import Foundation 


@main
struct Runner {

    static func main() async throws {

        let cwd = FileManager.default.currentDirectoryPath
        print("script with custom entry executed at \(cwd)")

    }

}
