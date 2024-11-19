#!/bin/bash

mkdir ~/.swift-script
cd ~/.swift-script

mkdir runner 
cd runner 
env swift package init --type executable --name swift-script-runner > /dev/null 2>&1
rm ./Sources/main.swift
touch ./Sources/Placeholder.swift
env swift package resolve
cd .. 

echo "[]" > packages.json

mkdir temp 
mkdir "exec"

configContent="
{
    \"swiftVersion\": \"6.0\",
    \"macosVersion\": \"15\",
    \"strictConcurrency\": false 
}
"
echo "$configContent" > config.json
