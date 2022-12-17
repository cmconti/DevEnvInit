@echo off
SETLOCAL EnableDelayedExpansion

SET _ISADMIN=0
call :checkadmin
if %_ISADMIN% NEQ 1 echo Must run as admin^^!^^! & goto :Done

:powershell
powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 5){exit 1}"
if ERRORLEVEL 1 echo You need to install powershell 5 or later & goto Done

powershell -Command "$pol = get-executionpolicy;if (@('Unrestricted','Bypass') -notcontains $pol){exit 1}"
if NOT ERRORLEVEL 1 goto CheckEnv
echo Powershell must have an execution policy of unrestricted or bypass for this tool to work.

SET INSTALL_=
set /p INSTALL_="Do you want to set the execution policy to Unrestricted for the current user? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done

powershell "set-executionpolicy -ExecutionPolicy Unrestricted -Scope CurrentUser"

:Chocolatey
SET INSTALL_=
set /p INSTALL_="Install Chocolatey ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto chrome
:: Install choco .exe and add choco to PATH
@powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"

choco feature enable -n useRememberedArgumentsForUpgrades

:: Install all the packages
:::: Browsers
:chrome
SET INSTALL_=
set /p INSTALL_="Install chrome ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto firefox
choco upgrade googlechrome -y
:firefox
SET INSTALL_=
set /p INSTALL_="Install firefox ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto sevenzip
choco upgrade firefox -y

:::: Utilities + other
:sevenzip
SET INSTALL_=
set /p INSTALL_="Install 7zip ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto winmerge
choco upgrade 7zip.install -y
:winmerge
SET INSTALL_=
set /p INSTALL_="Install winmerge ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto notepad2
choco upgrade winmerge -y

goto notepad3

:notepad2
SET INSTALL_=
set /p INSTALL_="Install notepad2 ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto notepad3
choco upgrade notepad2-mod -y

:::: configure
support\UpdateINI -s Settings SaveRecentFiles 1 "%APPDATA%\Notepad2\Notepad2.ini"
support\UpdateINI -s Settings SaveFindReplace 1 "%APPDATA%\Notepad2\Notepad2.ini"
support\UpdateINI -s Settings TabsAsSpaces 1 "%APPDATA%\Notepad2\Notepad2.ini"
support\UpdateINI -s Settings ViewWhiteSpace 1 "%APPDATA%\Notepad2\Notepad2.ini"

:notepad3
SET INSTALL_=
set /p INSTALL_="Install notepad3 ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done
choco upgrade notepad3 -y

:::: configure
support\UpdateINI -s Settings SaveRecentFiles true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings SaveFindReplace true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings TabsAsSpaces true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings ViewWhiteSpace true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings SaveBeforeRunningTools true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings RegExprSearch false "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings efrData_fuFlags 2097152 "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings FileWatchingMode 1 "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
support\UpdateINI -s Settings ResetFileWatching false "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"

goto Done

:UtilityFunctions

:checkadmin
openfiles > NUL 2>&1 
if NOT %ERRORLEVEL% EQU 0 (
SET _ISADMIN=0
) else (
SET _ISADMIN=1
)
goto :eof

:Done
ENDLOCAL & SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
refreshenv
