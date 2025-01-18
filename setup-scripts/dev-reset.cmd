@echo off 

rmdir /s /q %USERPROFILE%\.swift-script
call "%~dp0\dev-setup.cmd"