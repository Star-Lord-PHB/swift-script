# Swift Script

A command line tools for executing single swift file as a script that support 3rd party swift packages.

### 🚧 UNDER CONSTRUCTION !!! 🚧

The project is still under construction and only support very basic features. 

Currently known limitations: 
- [ ] [Swift Package Index](https://swiftpackageindex.com) still does not have APIs available, currently using their [package list repository](https://github.com/SwiftPackageIndex/PackageList/blob/main/packages.json) 
- [x] ~~Does not support complex semetic version format other than the basic `major.minor.patch` format yet. In other word, formats such as `v1.0.0`, `1.0.0-alpha` are not currently supported~~
- [x] ~~No formal installation script yet~~
- [x] ~~Not tested on Linux yet~~
- [ ] Not tested on Windows yet (swift-testing for executable target on Windows is kind of broken?)
- [x] ~~Does not support customized swift location yet~~
- [ ] Does not support module alias yet 
- [x] ~~No idea how to support code completion yet~~
- [x] ~~The `--help` output and docs are not completed yet~~
- [ ] May be more ......

## Build and Run

#### Setup Working Folder

First, setup the working folder for the executable by running the script provided in `setup-script` folder. 

```sh
# first-time setup 
./setup-script/dev-setup.sh
# first-time setup (Windows)
./setup-script/dev-setup.cmd
```

This will create a working folder at `~/.swift-script`

To fully remove this working folder, use the `dev-clean.sh` script:

```sh
# fully remove the working folder
./setup-script/dev-clean.sh
# fully remove the working folder (Windows)
./setup-script/dev-clean.cmd
```

To reset the working folder (fully remove and then setup again), use the `dev-reset.sh` script:

```sh
# reset the working folder
./setup-script/dev-reset.sh
# reset the working folder (Windows)
./setup-script/dev-reset.cmd
```

#### Build and Run

Build with standard swift build command:

```sh
# debug mode
swift build
# release mode (Not working on Windows Yet)
swift build -c release 
```

The binary can be found at `.build/debug/SwiftScript` (debug mode) or `.build/release/SwiftScript` (release mode)

Alternatively, you can use `swift run` command to execute it immediately:
```sh
# debug mode
swift run SwiftScript [args]
#release mode (Not working on Windows Yet)
swift run -c release SwiftScript [args]
```

To make things easier, there is a script provided in the `manual_test_scripts` folder, so you can run it with: 

```sh
./manual_test_scripts/run [args]
```

**_Note that currently this script run the DEBUG executable directly without building, so remember to build in DEBUG mode first before running it._**

## Usage

`SwiftScript` support the following subcommands:
* run (default)
* install 
* uninstall
* list
* search
* info 
* update
* config
* init

When run with no subcommands specified, the `run` subcommand will be automatically used. 

#### Run Command

```sh
swiftscript run <path_to_script> [arguments]
```

Run and script written in swift specified by the path. The additional `arguments` will also be fed into the script. 

Examples:
```sh
swiftscript run script.swift
swiftscript ~/scripts/hello Serika
```

#### Install Command

```sh
swiftscript install <package_url | package_identity> [version_option]
```

* `package_url`: the remote url of the package git repository
* `package_identity`: the identity of the package in [Swift Package Index](https://swiftpackageindex.com)
* `version_option`: specify the version requirement for the package, which is basically the same as that in the dependency in Swift Package Manager
    * `--from <semantic_version>` (default)
    * `--up-to-next-minor-from <semantic_version>`
    * `--exact <semantic_version>`
    * `--branch <branch_name>`
    * `--to <semantic_version>`

If the specified package is already installed, `SwiftScript` will ask whether to replace with the new version requirement. You can also provide the `--force-replace` flag to directly allow the replacement. 

Examples:
```sh
swiftscript install https://github.com/apple/swift-collections.git
swiftscript install swift-system --from 1.2.0 --to 1.2.5
swiftscript install swift-system --branch main --force-replace
```

#### Uninstall Command

```sh
swiftscript uninstall <package_identities>
```

Uninstall the specified list of packages. All these packages must be installed.
Alias: `remove`, `rm`

Examples:
```sh
swiftscript uninstall swif-system
swiftscript remove swift-system swift-collections
```

#### List Command

```sh
swiftscript list
```

Print out all the installed packages as a dependency tree, which may look something like this: 

```
.
├── swift-async-algorithms<https://github.com/apple/swift-async-algorithms.git@1.0.2>
│   └── swift-collections<https://github.com/apple/swift-collections@1.1.4>
├── swift-system<https://github.com/apple/swift-system.git@unspecified>
└── swift-collections<https://github.com/apple/swift-collections@1.1.4>
```

#### Search Command

```sh
swiftscript search <package_identity>
```

Search the provided package identity using [Swift Package Index](https://swiftpackageindex.com) and print out information related to that package.

By default the command will not print the dependency tree of the package. If you want that, add `--show-dependencies` flag.

Examples
```sh
swiftscript search swift-system
swiftscript search swift-collections --show-dependencies
```

#### Info Command

```sh
swiftscript info <package_identity>
```

Print out information of the specified package identity, which must already be installed.

In addition to the output of the `Search` Command, it also includes the specified version requirement and the current version of the installed package. 

Like the `Search` Command, the command will not print the dependency tree of the package by default. If you want that, add `--show-dependencies` flag.

Examples
```sh
swiftscript info swift-system
swiftscript info swift-collections --show-dependencies
```

#### Update Command

```sh
swiftscript update <package_identity> [version_option]
```

Update the specified package with the specified version requirements. This command is basically the same as calling `install` command with the `--force-replace` option. 

```sh
swiftscript update --all
```

Another way of using this command. In this case, all the installed packages will be replaced with their latest sementic version. 

Examples:
```sh
swiftscript update swift-system --branch main
swiftscript update swift-collection --exact 1.3.0
swiftscript update --all
```

#### Edit Command

```sh
swiftscript edit <path_to_script>
```

Edit a swift script file by creating a temp workspace SPM project, which already has all the installed packages available as dependencies. 

It is not required to edit script with this command, but it's currently the only way to have auto-completion available. 

Examples:
```sh
swiftscript edit main.swift
```

#### Config Command

```sh
swiftscript config <config_name>
swiftscript config set <config_options>
swiftscript config set editor <editor_path> <args>
```

Read / Modify configuration of `SwiftSwift`. 

To show current config, use: 

```sh
swiftscript config 
```

To modify config, use the format
```sh
swiftscript config set --config_name1=value1 --config_name2=value2 --clear_config_name1 --clear_config_name2 ...
```

Currently `SwiftScript` supports the following configs: 
* `swift_version`: the version of swift for executing the script
* `macos_version`: the max macOS sdk for executing the script (this option is only valid on macOS)
* `swift_path`: The path to the `swift` executable

Examples: 
```sh
swiftscript config swift_version
swiftscript config set --swift_version=6.0.0
swiftscript config set --swift_version=6.0.2 --macos_version=15.1 --swift_path="/usr/bin/swift"
swiftscript config set --swift_version=6.0.2 --clear_macos_version --swift_path="/usr/bin/swift"
```

To set the editor for editing scripts, use the `editor` subcommand. It requires the path to the executable of the editor and additional arguments to pass to the editor. 

When the editor is not specified, `SwiftScript` will try to find VSCode in the environment.

`SwiftScript` support any editors with the following 2 requirements:
* The editor is able to open a folder 
* The editor can be configured to not return before the editing window is closed by the user. The `-n --wait` flags is an example for VSCode. If this requirement is not met, `SwiftScript` will immediately delete the temp workspace project. 

Examples: 

```sh
swiftscript config set editor "/usr/local/bin/code" -n --wait
```

#### Init Command

```sh
swiftscript init
```

Command that will automatically install itself and prepare the environment. 

If run directly without any other options, it will prompt for several settings for custom installation. Those customization settings can also be provided with the following options directly, then the command will not prompt for input for that setting.
* `--install-path`: Path to install SwiftScript
* `--swift-path`: Path to swift executable
* `--swift-version`: The Swift version to use for building and running script

To install without any interactive prompt, provide values for all the necessary customization options or simply use `--quiet` (`-q`) flag, which will fill all un-specified settings with default values. 

By default, the installation will setup the environment by modifying `.profile` or `.zprofile`. If that is not intended, pass in `--no-env` flag. 

This command is also capable of re-installing SwiftScript. When it detects that SwiftScript is already installed, it prompt for re-installation options, which can be: 
* **re-install binary only:** only replace the binary, everything else will stay the same
* **fully re-install:** fully remove everything and re-install

Choosing between these 2 re-installation type can also be done by passing flags: 
* `--reinstall-binary`: re-install binary only
* `--fully-reinstall`: fully re-install

Note that if `--quiet` is set and SwiftScript is already install and `--reinstall-binary` is not set, it will do a full re-install without any prompt. 

Uninstall is also done with this command, by passing the `--uninstall` flag. It will remove every files and folders used by SwiftScript, but will not remove the environment configuration in `.profile` or `.zprofile`, which need to be done manually. 