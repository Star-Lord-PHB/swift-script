@echo off

mkdir %USERPROFILE%\.swift-script
cd %USERPROFILE%\.swift-script

mkdir runner
cd runner

swift package init --type executable --name swift-script-runner >NUL 2>&1
del .\Sources\main.swift
echo. > .\Sources\Placeholder.swift
swift package resolve
cd ..

echo [] > packages.json

mkdir temp
mkdir exec

setlocal enabledelayedexpansion
(
    echo {
    echo     "swiftVersion": "6.0",
    echo     "macosVersion": "15",
    echo     "strictConcurrency": false
    echo }
) > config.json
endlocal