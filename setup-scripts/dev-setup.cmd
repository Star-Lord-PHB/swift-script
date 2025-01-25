@echo off

mkdir %USERPROFILE%\.swift-script
cd %USERPROFILE%\.swift-script

mkdir runner
cd runner

swift package init --type executable --name Runner >NUL 2>&1
del .\Sources\main.swift
echo. > .\Sources\Placeholder.swift
swift package resolve
cd ..

echo [] > packages.json

mkdir temp
mkdir exec
mkdir bin 

echo "{}" > config.json