@echo off
SETLOCAL EnableDelayedExpansion

SET HTTP_PROXY=
SET HTTPS_PROXY=

SET _ISADMIN=0
call :checkadmin
if %_ISADMIN% NEQ 1 echo Must run as admin^^!^^! & goto :Done

goto notepad3

:notepad2
SET INSTALL_=
set /p INSTALL_="Install notepad2 ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto notepad3
choco upgrade notepad2-mod -y
:::: configure
UpdateINI -s Settings SaveRecentFiles 1 "%APPDATA%\Notepad2\Notepad2.ini"
UpdateINI -s Settings SaveFindReplace 1 "%APPDATA%\Notepad2\Notepad2.ini"
UpdateINI -s Settings TabsAsSpaces 1 "%APPDATA%\Notepad2\Notepad2.ini"
UpdateINI -s Settings ViewWhiteSpace 1 "%APPDATA%\Notepad2\Notepad2.ini"

:notepad3
SET INSTALL_=
set /p INSTALL_="Install notepad3 ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto p4merge
choco upgrade notepad3 -y
:::: configure
UpdateINI -s Settings SaveRecentFiles true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings SaveFindReplace true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings TabsAsSpaces true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings ViewWhiteSpace true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings SaveBeforeRunningTools true "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings RegExprSearch false "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings efrData_fuFlags 2097152 "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings FileWatchingMode 1 "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"
UpdateINI -s Settings ResetFileWatching false "%APPDATA%\Rizonesoft\Notepad3\Notepad3.ini"

:p4merge
SET INSTALL_=
set /p INSTALL_="Install p4merge ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto curl
REM p4merge
choco upgrade p4merge -y
REM update path
powershell -Command "$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true);$oldpath = $regKey.GetValue('Path', $null, 'DoNotExpandEnvironmentNames');if ($oldpath -notmatch 'Perforce'){$oldpath += ';%PROGRAMFILES%\Perforce';$regKey.SetValue('Path', $oldpath, 'ExpandString')}"

> "%~dp0\tmpCustomInstall.ps1" (
echo if (-not ("Win32.NativeMethods" -as [Type]^)^) {
echo Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
echo [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto^)]
echo public static extern IntPtr SendMessageTimeout(
echo     IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
echo     uint fuFlags, uint uTimeout, out UIntPtr lpdwResult^);
echo "@
echo }
echo $HWND_BROADCAST = [IntPtr] 0xffff;
echo $WM_SETTINGCHANGE = 0x1a;
echo $result = [UIntPtr]::Zero
echo [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref] $result^);
)

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\tmpCustomInstall.ps1'"
del "%~dp0\tmpCustomInstall.ps1"

REM configure
if exist "%userprofile%\.p4merge\ApplicationSettings.xml" goto UpdateP4Merge

md "%userprofile%\.p4merge"

> "%userprofile%\.p4merge\ApplicationSettings.xml" (
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<^^!--perforce-xml-version=1.0--^>
echo ^<PropertyList varName="ApplicationSettings" IsManaged="TRUE"^>
echo  ^<String varName="CharSet"^>none^</String^>
echo  ^<String varName="DiffOption"^>dl^</String^>
echo  ^<Font varName="Font"^>
echo   ^<family^>Courier New^</family^>
echo   ^<pointSize^>10^</pointSize^>
echo   ^<weight^>true^</weight^>
echo   ^<italic^>false^</italic^>
echo  ^</Font^>
echo  ^<Bool varName="InlineDiffsEnabled"^>true^</Bool^>
echo  ^<String varName="LineEnding"^>Windows^</String^>
echo  ^<Bool varName="ShowTabsSpaces"^>true^</Bool^>
echo  ^<Bool varName="TabInsertsSpaces"^>true^</Bool^>
echo  ^<Int varName="TabWidth"^>4^</Int^>
echo  ^<PropertyList varName="Windows" IsManaged="TRUE"^>
echo   ^<PropertyList varName="CompareDialog" IsManaged="TRUE"^>
echo    ^<ByteArray varName="WindowGeometry"^>AdnQywACAAAAAAIvAAABjgAABBMAAAJ1AAACNwAAAa0AAAQLAAACbQAAAAAAAAAABpA=^</ByteArray^>
echo   ^</PropertyList^>
echo   ^<PropertyList varName="MergeDiff" IsManaged="TRUE"^>
echo    ^<Bool varName="ShowLineNumbers"^>true^</Bool^>
echo   ^</PropertyList^>
echo  ^</PropertyList^>
echo ^</PropertyList^>
)

goto tools
:UpdateP4Merge
echo TODO

> "%~dp0\tmpCustomInstall.ps1" (
echo [xml]$myXML = Get-Content "%userprofile%\.p4merge\ApplicationSettings.xml"
echo $myXML.SelectSingleNode("/PropertyList/Bool[@varName='ShowTabsSpaces']"^).set_InnerText("false"^)
echo $myXML.SelectSingleNode("/PropertyList/Bool[@varName='ShowTabsSpaces']"^).set_InnerText("true"^)
echo $myXML.SelectSingleNode("/PropertyList/Bool[@varName='TabInsertsSpaces']"^).set_InnerText("true"^)
echo $myXML.SelectSingleNode("/PropertyList/Int[@varName='TabWidth']"^).set_InnerText("4"^)
echo $myXML.Save("%userprofile%\.p4merge\ApplicationSettings.xml"^)
)

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\tmpCustomInstall.ps1'"
del "%~dp0\tmpCustomInstall.ps1"


:tools
:curl
SET INSTALL_=
set /p INSTALL_="Install curl ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto perl
REM curl
choco upgrade curl -y

:perl
SET INSTALL_=
set /p INSTALL_="Install perl ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto putty
REM perl
choco upgrade activeperl --version 5.24.2.2403 -y

:putty
SET INSTALL_=
set /p INSTALL_="Install putty ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto hashdeep
REM putty
choco upgrade putty -y

:hashdeep
SET INSTALL_=
set /p INSTALL_="Install hashdeep ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto sysinternals
REM hashdeep
choco upgrade hashdeep -y

:sysinternals
SET INSTALL_=
set /p INSTALL_="Install sysinternals ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done
REM sysinternals
choco upgrade -y sysinternals --params "/InstallDir:C:\sysinternals"

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
ENDLOCAL
refreshenv