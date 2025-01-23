import FoundationPlusEssential
import FileManagerPlus
import ArgumentParser
import SwiftCommand


struct SwiftScriptInit: SwiftScriptWrappedCommand {

    static let configuration: CommandConfiguration = .init(commandName: "init")

    @Flag(name: .long, help: "Uninstall SwiftScript")
    var uninstall: Bool = false

    @Flag(name: .long, help: "Do not add SwiftScript to environment")
    var noEnv: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    @Flag(
        name: [.customLong("quiet"), .customShort("q")], 
        help: .init(
            "No interactive prompt", 
            discussion: """
                If set, will not ask for any input. If values are not provided through other options, default values will be used.
                If SwiftScript is installed and --reinstall-binary is not set, will do fully reinstall without prompt.
                """
        )
    )
    var noPrompt: Bool = false

    @Option(
        name: .long, 
        help: "Path to install SwiftScript, default to \(AppEnv.defaultBasePath)", 
        transform: FilePath.init(_:)
    )
    var installPath: FilePath?

    @Option(
        name: .long, 
        help: "Path to swift executable, default to use the environment", 
        transform: FilePath.init(_:)
    )
    var swiftPath: FilePath?

    @Option(
        name: .long, 
        help: "The Swift version to use for building and running script, default to use the current compiler version",
        transform: Version.parse(_:)
    )
    var swiftVersion: Version?

    @Flag(
        name: .customLong("reinstall-binary"), 
        help: .init(
            "Only try to reinstall the binary", 
            discussion: "Only take effect when SwiftScript is already installed."
        )
    )
    var reinstallBinaryOnly: Bool = false

    @Flag(
        name: .long, 
        help: .init(
            "Fully Reinstall", 
            discussion: "Only take effect when SwiftScript is already installed."
        )
    )
    var fullyReinstall: Bool = false

    var appEnv: AppEnv = .fromEnv()
    var logger: Logger = .init()
    var noInitAppEnv: Bool = true


    mutating func wrappedRun() async throws {

        let isInstalled = await isInstalled()

        if uninstall {
            guard isInstalled else {
                logger.printWarning("SwiftScript is not installed yet.")
                throw ExitCode.success 
            }
            try await selfUninstall()
            throw ExitCode.success
        }

        if isInstalled {

            guard let currentBinaryPath = try Bundle.main.executableURL?.assertAsFilePath() else {
                throw CLIError(reason: "Cannot determine binary path.")
            }
            guard currentBinaryPath != appEnv.swiftScriptBinaryPath else {
                logger.printWarning("This running binary is already the installed one.")
                throw ExitCode.success
            }

            if reinstallBinaryOnly {
                print("Reinstalling the binary.")
                try await reInstallBinary()
                throw ExitCode.success
            } else if fullyReinstall || noPrompt {
                print("Fully reinstalling everything.")
                try await fullReinstall()
                throw ExitCode.success
            } 

            print("""
                SwiftScript is already installed. What would you like to do?
                1. Reinstall binary only (b)
                2. Full Reinstall (f)
                3. Exit (x) (default)
                """
            )
            print("> ", terminator: "")

            let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()

            switch response {
                case "b", "1":
                    try await reInstallBinary()
                case "f", "2":
                    try await fullReinstall()
                default: break
            }

            throw ExitCode.success

        }

        try? await FileManager.default.removeItem(at: appEnv.appBasePath)
        try await install()
        
    }


    private func reInstallBinary() async throws {

        let manager = FileManager.default

        guard let currentBinaryPath = try Bundle.main.executableURL?.assertAsFilePath() else {
            throw CLIError(reason: "Cannot determine binary path.")
        }

        try await manager.moveItem(at: appEnv.swiftScriptBinaryPath, to: cachePath)

        registerCleanUp(when: .interrupt) {
            do {
                try await FileManager.default.moveItem(at: cachePath, to: appEnv.swiftScriptBinaryPath)
            } catch {
                logger.printWarning("Failed to restore the original binary at \(appEnv.swiftScriptBinaryPath): \(error)")
                logger.printWarning("Please restore it manually.")
            }
        }

        try await manager.moveItem(at: currentBinaryPath, to: appEnv.swiftScriptBinaryPath)

        print("Binary reinstallation complete.")

    }


    private mutating func install() async throws {

        let (installPath, swiftPath, swiftVersion) = try await askInstallInfo()

        appEnv = .init(base: installPath)
        let config = AppConfig(swiftVersion: swiftVersion, swiftPath: swiftPath)

        let manager = FileManager.default

        registerCleanUp(when: .interrupt) { [appEnv, logger] in 
            do {
                try await FileManager.default.removeItem(at: appEnv.appBasePath)
            } catch {
                logger.printWarning("Failed to remove the partial installation at \(appEnv.appBasePath): \(error)")
                logger.printWarning("Please remove it manually.")
            }
        }

        try await makeNecessaryFilesAndFolders(config: config)
        try await appEnv.initialize()
        try await createRunnerPackage(swiftPath: swiftPath.map { .init($0) })

        guard let currentBinaryPath = try Bundle.main.executableURL?.assertAsFilePath() else {
            throw CLIError(reason: "Cannot determine binary path.")
        }
        try await manager.moveItem(at: currentBinaryPath, to: appEnv.swiftScriptBinaryPath)

        if !noEnv {
            try await addToEnv()
            print("Installation complete. Please re-login to have the environment available.")
#if canImport(Glibc) || canImport(Darwin)
            print("Alternatively, you can run the following command to activate the environment immediately for current shell:")
            print(". \(appEnv.envScriptPath)")
#endif

        } else {
            print("Installation complete.")
            print("Because --no-env is set, the environment is not currently available.")
            print("The env setup script is located at \(appEnv.envScriptPath), please do the setup manually.")
        }

    }


    private mutating func fullReinstall() async throws {

        let manager = FileManager.default

        let originalAppBasePath = appEnv.appBasePath
        // let cachePath = appEnv.appBasePath.removingLastComponent()
        //     .appending((appEnv.appBasePath.lastComponent?.string ?? "") + "-\(ISO8601DateFormatter().string(from: Date()))")

        try await manager.moveItem(at: appEnv.appBasePath, to: cachePath)

        registerCleanUp(when: .normalExit) { [logger, cachePath] in
            do {
                try await FileManager.default.removeItem(at: cachePath)
            } catch {
                logger.printWarning("Failed to remove the temporary cache directory at \(cachePath): \(error)")
                logger.printWarning("Please remove it manually.")
            }
        }
        registerCleanUp(when: .interrupt) { [logger, cachePath] in
            do {
                try await FileManager.default.moveItem(at: cachePath, to: originalAppBasePath)
            } catch {
                logger.printWarning("Failed to restore the original installation at \(originalAppBasePath): \(error)")
                logger.printWarning("Please restore it manually.")
            }
        }

        try await install()

    }


    private func selfUninstall() async throws {

        print("Are you sure to uninstall SwiftScript? Everything in \(appEnv.appBasePath) will be removed (y/n): ", terminator: "")
        let response = readLine()?.trimmingCharacters(in: .whitespaces).lowercased()
        guard response == "y" || response == "yes" else { return }

        try await removeFromEnv()

#if canImport(Glibc) || canImport(Darwin)
        try await FileManager.default.removeItem(at: appEnv.appBasePath)
        print("Uninstallation complete.")
        if let shellConfigPath = try? currentShellConfigPath() {
            print("The environment settings in your shell configuration file is not removed, which should be located at \(shellConfigPath)")
        } else {
            print("The environment settings in your shell configuration file is not removed.")
        }
        print("Please remove it manually.")
#elseif os(Windows)
        let uninstallScriptPath = appEnv.appBasePath.removingLastComponent().appending("uninstall.bat")
        try await FileManager.default.createFile(
            at: uninstallScriptPath, 
            with: .init(windowsUninstallScriptContents.utf8)
        )
        registerCleanUp(when: .interrupt) {
            try? FileManager.default.removeItem(at: uninstallScriptPath)
        }
        _ = try Command.requireInPath("cmd")
            .addArguments("/c", uninstallScriptPath.string, "2>nul")
            .spawn()
#endif

    }


    private func isInstalled() async -> Bool {

        let manager = FileManager.default

        let envHome = ProcessInfo.processInfo.environment[AppEnv.basePathEnvKey]

        guard envHome != nil else { return false }
        guard envHome == appEnv.appBasePath.string else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.appBasePath).isDirectory) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.configFilePath).isRegularFile) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.runnerPackagePath).isDirectory) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.tempDirPath).isDirectory) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.execPath).isDirectory) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.envScriptPath).isRegularFile) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.binFolderPath).isDirectory) == true else { return false }
        guard (try? await manager.infoOfItem(at: appEnv.swiftScriptBinaryPath).isRegularFile) == true else { return false }

        return true

    }


    private func askInstallInfo() async throws -> (installPath: FilePath, swiftPath: String?, swiftVersion: Version?) {

        let installPath = try {
            if let installPath = self.installPath { return installPath }
            guard !noPrompt else { return AppEnv.defaultBasePath }
            print("Path to install (leave empty to use default \(AppEnv.defaultBasePath)): ", terminator: "")
            guard let path = readLine()?.trimmingCharacters(in: .whitespaces) else { 
                throw CancellationError()
            }
            guard path.isNotEmpty else { return AppEnv.defaultBasePath }
            return FilePath(path)
        }()

        try Task.checkCancellation()

        let swiftPath = try {
            if let swiftPath = self.swiftPath { return swiftPath.string as String? }
            guard !noPrompt else { return nil as String? }
            print("Path to swift executable (leave empty to use the environment): ", terminator: "")
            guard let path = readLine()?.trimmingCharacters(in: .whitespaces) else {
                throw CancellationError()
            }
            return path.isEmpty ? nil : path
        }()

        try Task.checkCancellation()

        let swiftVersion = try {
            if let swiftVersion = self.swiftVersion { return swiftVersion as Version? }
            guard !noPrompt else { return nil as Version? }
            while true {
                print("Swift version (x.y.z) for building and running script (leave empty to use compiler version): ", terminator: "")
                guard let versionStr = readLine()?.trimmingCharacters(in: .whitespaces) else { 
                    throw CancellationError()
                }
                guard versionStr.isNotEmpty else { return nil }
                guard let version = Version(string: versionStr) else {
                    logger.printWarning("Invalid version format. Please try again.")
                    continue
                }
                return version
            }
        }()

        return (installPath, swiftPath, swiftVersion)

    }


    private func makeNecessaryFilesAndFolders(config: AppConfig) async throws {

        let manager = FileManager.default
        
        try await manager.createDirectory(at: appEnv.appBasePath)
        try await manager.createDirectory(at: appEnv.tempDirPath)
        try await manager.createDirectory(at: appEnv.runnerPackagePath)
        try await manager.createDirectory(at: appEnv.execPath)
        try await manager.createDirectory(at: appEnv.binFolderPath)
        try await JSONEncoder().encode(config).write(to: appEnv.configFilePath)
        try await manager.createFile(at: appEnv.installedPackagesPath, with: .init("[]".utf8))
        try await manager.createFile(at: appEnv.envScriptPath, with: .init(envScriptContent.utf8))

    }


    private func createRunnerPackage(swiftPath: FilePath?) async throws {

        let swiftCommand = if let swiftPath {
            Command(executablePath: swiftPath)
        } else {
            Command.findInPath(withName: "swift")
        }
        guard let swiftCommand else { throw CLIError(reason: "Swift executable not found.") }

        try await swiftCommand
            .setCWD(appEnv.runnerPackagePath)
            .addArguments("package", "init", "--type", "executable", "--name", "swift-script-runner")
            .wait(hidingOutput: true)

        try await appEnv.updatePackageManifest(installedPackages: [])
        try await appEnv.cleanScriptsWithPlaceholderScript()

    }


    func addToEnv() async throws {

        let manager = FileManager.default

#if canImport(Glibc) || canImport(Darwin)

        let shellSettingScriptPath = try currentShellConfigPath()

        if ProcessInfo.processInfo.environment[AppEnv.basePathEnvKey] != appEnv.appBasePath.string {
            if await !manager.fileExists(at: shellSettingScriptPath) {
                logger.printDebug("Shell environment configuration file not found. Creating one at \(shellSettingScriptPath)")
                try await manager.createFile(at: shellSettingScriptPath, with: .init(loadEnvScriptCommands.utf8))
            } else {
                try await manager.append(.init(loadEnvScriptCommands.utf8), to: shellSettingScriptPath)
            }
        }

#elseif os(Windows)

        let envBasePath = try await Command.requireInPath("powershell")
            .addArguments("-Command", "[Environment]::GetEnvironmentVariable('\(AppEnv.basePathEnvKey)', 'User')")
            .output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if envBasePath != appEnv.appBasePath.string {

            var envPath = try await Command.requireInPath("powershell")
                .addArguments("-Command", "[Environment]::GetEnvironmentVariable('PATH', 'User')")
                .output.stdout.trimmingSuffix(in: .whitespacesAndNewlines)

            envPath.append(#";"\#(appEnv.binFolderPath)""#)

            try await Command.requireInPath("powershell")
                .addArguments("-Command", "[Environment]::SetEnvironmentVariable('PATH', '\(envPath)', 'User')")
                .wait()

            try await Command.requireInPath("powershell")
                .addArguments("-Command", "[Environment]::SetEnvironmentVariable('\(AppEnv.basePathEnvKey)', '\(appEnv.appBasePath)', 'User')")
                .wait()

        }

#else
        #error("Unsupported platform")
#endif

    }


    func removeFromEnv() async throws {

#if os(Windows)

        var envPath = try await Command.requireInPath("powershell")
            .addArguments("-Command", "[Environment]::GetEnvironmentVariable('PATH', 'User')")
            .output.stdout

        let escapedPath = NSRegularExpression.escapedPattern(for: appEnv.binFolderPath.string)

        if let range = try envPath.firstRange(of: Regex(#";{0,1}\s*"{0,1}\s*\#(escapedPath)\s*"{0,1}\s*;{0,1}"#)) {
            let matchSubStr = envPath[range]
            if matchSubStr.last == ";" && matchSubStr.first == ";" {
                envPath.replaceSubrange(range, with: ";")
            } else {
                envPath.removeSubrange(range)   
            }
            try await Command.requireInPath("powershell")
                .addArguments("-Command", "[Environment]::SetEnvironmentVariable('PATH', '\(envPath)', 'User')")
                .wait()
        }

        try await Command.requireInPath("powershell")
            .addArguments("-Command", "[Environment]::SetEnvironmentVariable('\(AppEnv.basePathEnvKey)', $null, 'User')")
            .wait()

#endif

    }

}


extension SwiftScriptInit {

    var cachePath: FilePath {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = formatter.string(from: Date())
        return appEnv.appBasePath.removingLastComponent()
            .appending((appEnv.appBasePath.lastComponent?.string ?? "") + "-\(dateString)")
    }

    var envScriptContent: String {
#if canImport(Glibc) || canImport(Darwin)
        """
        export \(AppEnv.basePathEnvKey)="\(appEnv.appBasePath)"
        SWIFT_SCRIPT_BIN="\(appEnv.binFolderPath)"
        if [[ ":$PATH:" != *":$SWIFT_SCRIPT_BIN:"* ]]; then
            export PATH="$SWIFT_SCRIPT_BIN:$PATH"
        fi
        """
#elseif os(Windows)
        """
        @echo off
        if not "%\(AppEnv.basePathEnvKey)%"=="\(appEnv.appBasePath)" (
            powershell -Command [Environment]::SetEnvironmentVariable('PATH', "$([Environment]::GetEnvironmentVariable('Path', 'User'));\(appEnv.binFolderPath)", 'User')
            powershell -Command [Environment]::SetEnvironmentVariable('\(AppEnv.basePathEnvKey)', '\(appEnv.appBasePath)', 'User')
        )
        
        """
#else
        #error("Unsupported platform")
#endif
    }

    var loadEnvScriptCommands: String {
        """

        # Swift Script
        . "\(appEnv.envScriptPath)"
        """
    }


    var windowsUninstallScriptContents: String {
        """
        @echo off
        :check
        tasklist | find "\(appEnv.swiftScriptBinaryPath)" > nul
        if %errorlevel% equ 0 (
            timeout /t 1 /nobreak > nul
            goto check
        )
        rmdir /S /Q "\(appEnv.appBasePath)"
        del /F /Q "%~f0"
        """
    }


    func currentShellConfigPath() throws -> FilePath {
        let manager = FileManager.default
        guard let shell = ProcessInfo.processInfo.environment["SHELL"] else {
            throw CLIError(reason: "Cannot determine current shell environment.")
        }
        return switch FilePath(shell).lastComponent {
            case "zsh": manager.homeDirectoryFilePathForCurrentUser.appending(".zprofile")
            case "bash": manager.homeDirectoryFilePathForCurrentUser.appending(".profile")
            default: throw CLIError(reason: "Unsupported shell: \(shell)")
        }
    }

}