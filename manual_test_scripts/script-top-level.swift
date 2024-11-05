import Foundation 

let cwd = FileManager.default.currentDirectoryPath
print(
    """
    script with top level entry point executed 
    cwd: \(cwd)
    os: \(ProcessInfo.processInfo.operatingSystemVersionString)
    """
)
