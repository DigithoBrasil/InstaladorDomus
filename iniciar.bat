@echo off
PowerShell.exe -NoProfile -Command "& {Start-Process PowerShell.exe -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File ""%~dp0instalador.ps1""' -Verb RunAs}"
pause