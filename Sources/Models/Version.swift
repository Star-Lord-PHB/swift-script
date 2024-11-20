import FoundationPlusEssential


struct Version {
    let major: Int
    let minor: Int
    let patch: Int
}


extension Version {
    
    init?(string: String) {
        let components = string.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard components.count <= 3 else { return nil }
        let intComponents = components.map { Int($0) } + [Int](repeating: 0, count: max(0, 3 - components.count))
        guard intComponents.allSatisfy({ $0 != nil }) else { return nil }
        self.major = intComponents[0]!
        self.minor = intComponents[1]!
        self.patch = intComponents[2]!
    }
    
}


extension Version: CustomStringConvertible {
    var description: String {
        "\(major).\(minor).\(patch)"
    }
}


extension Version: Comparable, Hashable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.major == rhs.major else { return lhs.major < rhs.major }
        guard lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
}


extension Version {

    static func parse(_ string: String) throws -> Self {
        guard let version = Self(string: string) else {
            throw ParseError("invalid sematic version string: \(string)")
        }
        return version
    }

}


extension Version: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let version = try Self.parse(string)
        self = version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

}



struct SemanticVersion {

    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: [String]
    let build: [String]

    init(major: Int, minor: Int, patch: Int, prerelease: [String] = [], build: [String] = []) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

}


extension SemanticVersion: CustomStringConvertible {

    var description: String {
        var result = "\(major).\(minor).\(patch)"
        if !prerelease.isEmpty {
            result.append("-" + prerelease.joined(separator: "."))
        }
        if !build.isEmpty {
            result.append("+" + build.joined(separator: "."))
        }
        return result
    }

}


extension SemanticVersion: Comparable, Hashable {

    static func < (lhs: Self, rhs: Self) -> Bool {

        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        for (l, r) in zip(lhs.prerelease, rhs.prerelease) {
            if l != r {
                return switch (Int(l), Int(r)) {
                    case (.some(let lInt), .some(let rInt)): lInt < rInt
                    case (.some, .none): true
                    case (.none, .some): false
                    case (.none, .none): l < r
                }
            }
        }

        return lhs.prerelease.count < rhs.prerelease.count

    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major 
        && lhs.minor == rhs.minor 
        && lhs.patch == rhs.patch 
        && lhs.prerelease == rhs.prerelease
    }

    static func === (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs && lhs.build == rhs.build
    }

}


extension SemanticVersion {
    
    init?(string: String) {
        guard let version = try? Self.parse(string) else { return nil }
        self = version
    }


    static func parse(_ string: String) throws -> Self {

        let string = execute {
            let strTemp = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstChar = strTemp.first
            return firstChar == "v" || firstChar == "V" ? String(strTemp.dropFirst()) : strTemp
        }
        guard string.isNotEmpty else { throw ParseError("Blank version string") }

        var components = string.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let build = components.dropFirst().first?
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { String($0) } ?? []

        guard build.allSatisfy({ $0.isNotEmpty }) else { 
            throw ParseError("Build components must not be empty: \(build)") 
        }

        components = components.first?.split(separator: "-", omittingEmptySubsequences: false) ?? []
        guard components.count <= 2 else { 
            throw ParseError("Unexpected extra components \(components.dropFirst(2))") 
        }
        guard let core = components.first else { 
            throw ParseError("Missing core version components") 
        }
        let prerelease = components.dropFirst().first?
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { String($0) } ?? []

        guard prerelease.allSatisfy({ $0.isNotEmpty }) else { 
            throw ParseError("Prerelease components must not be empty: \(prerelease)") 
        }

        let coreComponents = core.split(separator: ".", omittingEmptySubsequences: false)
        guard coreComponents.count <= 3 else { 
            throw ParseError("Unexpected extra core version components: \(coreComponents.dropFirst(3))")
        }
        let coreIntComponents = coreComponents.map { Int($0) } + [Int](repeating: 0, count: max(0, 3 - coreComponents.count))
        guard coreIntComponents.allSatisfy({ $0 != nil }) else { 
            throw ParseError("Core version components must be integers: \(core)")
        }

        return .init(
            major: coreIntComponents[0]!, 
            minor: coreIntComponents[1]!, 
            patch: coreIntComponents[2]!, 
            prerelease: prerelease, 
            build: build
        )

    }
    
}


extension SemanticVersion: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let version = try Self.parse(string)
        self = version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

}