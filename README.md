# Swift Script

A command line tools for executing single swift file as a script that support 3rd party swift packages.

### 🚧 UNDER CONSTRUCTION !!! 🚧

The project is still under construction and only support very basic features. 

Currently known limitations: 
- [ ] [Swift Package Index](https://swiftpackageindex.com) still does not have APIs available, currently using their [package list repository](https://github.com/SwiftPackageIndex/PackageList/blob/main/packages.json) 
- [ ] Does not support complex semetic version format other than the basic `major.minor.patch` format yet. In other word, formats such as `v1.0.0`, `1.0.0-alpha` are not currently supported
- [ ] No formal installation script yet
- [ ] Not tested on Linux or Windows yet
- [ ] Does not support customized swift location yet
- [ ] Does not support module alias yet 
- [ ] No idea how to support code completion yet
- [ ] The `--help` output and docs are not completed yet
- [ ] May be more ......

## Build and Run

#### Setup Working Folder

First, setup the working folder for the executable by running the script provided in `setup-script` folder. 

```sh
# first-time setup
./setup-script/dev-setup.sh
```

This will create a working folder at `~/.swift-script`

To fully remove this working folder, use the `dev-clean.sh` script:

```sh
# fully remove the working folder
./setup-script/dev-clean.sh
```

To reset the working folder (fully remove and then setup again), use the `dev-reset.sh` script:

```sh
# reset the working folder
./setup-script/dev-reset.sh
```

#### Build and Run

Build with standard swift build command:

```sh
# debug mode
swift build
# release mode
swift build -c release 
```

The binary can be found at `.build/debug/SwiftScript` (debug mode) or `.build/release/SwiftScript` (release mode)

Alternatively, you can use `swift run` command to execute it immediately:
```sh
# debug mode
swift run SwiftScript [args]
#release mode
swift run -c release SwiftScript [args]
```

To make things easier, there is a script provided in the `manual_test_scripts` folder, so you can run it with: 

```sh
./manual_test_scripts/run [args]
```

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

When run with no subcommands specified, the `run` subcommand will be automatically used. 

#### Run Command

```sh
SwiftScript run <path_to_script> [arguments]
```

Run and script written in swift specified by the path. The additional `arguments` will also be fed into the script. 

Examples:
```sh
SwiftScript run script.swift
SwiftScript ~/scripts/hello Serika
```

#### Install Command

```sh
SwiftScript install <package_url | package_identity> [version_option]
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
SwiftScript install https://github.com/apple/swift-collections.git
SwiftScript install swift-system --from 1.2.0 --to 1.2.5
SwiftScript install swift-system --branch main --force-replace
```

#### Uninstall Command

```sh
SwiftScript uninstall <package_identities>
```

Uninstall the specified list of packages. All these packages must be installed.
Alias: `remove`, `rm`

Examples:
```sh
SwiftScript uninstall swif-system
SwiftScript remove swift-system swift-collections
```

#### List Command

```sh
SwiftScript list
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
SwiftScript search <package_identity>
```

Search the provided package identity using [Swift Package Index](https://swiftpackageindex.com) and print out information related to that package.

By default the command will not print the dependency tree of the package. If you want that, add `--show-dependencies` flag.

Examples
```sh
SwiftScript search swift-system
SwiftScript search swift-collections --show-dependencies
```

#### Info Command

```sh
SwiftScript info <package_identity>
```

Print out information of the specified package identity, which must already be installed.

In addition to the output of the `Search` Command, it also includes the specified version requirement and the current version of the installed package. 

Like the `Search` Command, the command will not print the dependency tree of the package by default. If you want that, add `--show-dependencies` flag.

Examples
```sh
SwiftScript info swift-system
SwiftScript info swift-collections --show-dependencies
```

#### Update Command

```sh
SwiftScript update <package_identity> [version_option]
```

Update the specified package with the specified version requirements. This command is basically the same as calling `install` command with the `--force-replace` option. 

```sh
SwiftScript update --all
```

Another way of using this command. In this case, all the installed packages will be replaced with their latest sementic version. 

Examples:
```sh
SwiftScript update swift-system --branch main
SwiftScript update swift-collection --exact 1.3.0
SwiftScript update --all
```

#### Config Command

```sh
SwiftScript config <config_name>
SwiftScript config set <config_options>
```

Read / Modify configuration of the `SwiftCommand`. 

To modify config, use the format
```sh
SwiftScript config set --config_name1=value1 --config_name2=value2 ...
```

Currently `SwiftScript` supports the following configs: 
* `swift_version`: the version of swift for executing the script
* `macos_version`: the max macOS sdk for executing the script (this option is only valid on macOS)

Examples: 
```sh
SwiftScript config swift_version
SwiftScript config set swift_version=6.0.0
SwiftScript config set swift_version=6.0.2 macos_version=15.1
```