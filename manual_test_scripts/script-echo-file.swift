import Foundation 

guard CommandLine.arguments.count == 2 else {
    print("no file provided")
    exit(1)
}

let filePath = CommandLine.arguments[1]
print("path: \(filePath)")


let url = URL(fileURLWithPath: filePath)
let content = try String(contentsOf: url, encoding: .utf8)

print("contents:")
print(content)
