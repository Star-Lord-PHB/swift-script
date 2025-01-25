import SystemPackage
import Foundation 


print("script with swift-system package executed!")
print("cwd:", FilePath(FileManager.default.currentDirectoryPath))

#if DEBUG 
print("Debug mode")
#elseif RELEASE 
print("Release mode")
#else 
#error("unknown mode")
#endif
