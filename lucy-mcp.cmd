@echo off
setlocal
rem Use Windows PowerShell's own modules, not inherited PowerShell 7 paths.
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules;%ProgramFiles%\WindowsPowerShell\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0LucyMcp.ps1" %*
exit /b %errorlevel%
