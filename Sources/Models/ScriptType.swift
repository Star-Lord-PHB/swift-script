import Foundation
import SwiftSyntax
import SwiftParser
import FileManagerPlus
import FoundationPlusEssential


enum ScriptType {
    case topLevel, mainEntry
}



extension ScriptType: CustomStringConvertible {
    var description: String {
        switch self {
            case .topLevel: return "Top Level"
            case .mainEntry: return "Custom Main Entry"
        }
    }
}



extension ScriptType {

    static func of(fileAt path: FilePath) async throws -> ScriptType {

        guard let scriptContent = try await String(data: .read(contentAt: path), encoding: .utf8)
        else {
            fatalError("Fail to read contents of the script")
        }

        let syntax = Parser.parse(source: scriptContent)

        let hasEntry = syntax.statements.lazy
            .compactMap { codeBlockItem in
                codeBlockItem.item.as(StructDeclSyntax.self)
            }
            .contains { structDecl in
                structDecl.attributes.lazy
                    .compactMap { attribute in
                        attribute
                            .as(AttributeSyntax.self)?
                            .attributeName
                            .as(IdentifierTypeSyntax.self)?
                            .name.trimmed.text
                    }
                    .contains(where: { $0 == "main" })
            }

        return hasEntry ? .mainEntry : .topLevel

    }

}