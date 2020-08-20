@ECHO OFF
SETLOCAL EnableDelayedExpansion

SET HTTP_PROXY=
SET HTTPS_PROXY=

SET _ISADMIN=0
call :checkadmin
if %_ISADMIN% NEQ 1 echo Must run as admin^^!^^! & goto :Done

powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 5){exit 1}"
if ERRORLEVEL 1 echo You need to install powershell 5 or later & goto Done

powershell -Command "$pol = get-executionpolicy;if (@('Unrestricted','Bypass') -notcontains $pol){exit 1}"
if NOT ERRORLEVEL 1 goto CheckEnv
echo Powershell must have an execution policy of unrestricted or bypass for this tool to work.

SET INSTALL_=
set /p INSTALL_="Do you want to set the execution policy to Unrestricted for the current user? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done

powershell "set-executionpolicy -ExecutionPolicy Unrestricted -Scope CurrentUser"

:CheckEnv
REM Set default value here.  If the variable exists, do not change.  If not, override in CONF_ section below
SET CONF_CHOCO_TOOLS=%ChocolateyToolsLocation%
REM Special case:  ChocolateyToolsLocation is a user env var, not a system env var.
REM                if another user has already created C:\Bin\chocotools\poshgit or C:\tools\poshgit, use that base
if .%CONF_CHOCO_TOOLS%. EQU .. (
  if EXIST C:\Bin\chocotools\poshgit (
    SET CONF_CHOCO_TOOLS=C:\Bin\chocotools
  ) else (
    if EXIST C:\tools\poshgit (
      SET CONF_CHOCO_TOOLS=C:\Tools
    )
  )
)

REM *****
REM *****
REM set default CONF_ variables here:

REM only override CONF_CHOCO_TOOLS if chocolatey is not installed yet
if .%CONF_CHOCO_TOOLS%. EQU .. SET CONF_CHOCO_TOOLS=C:\Tools

rem if http proxy is needed for git, set this variable
rem SET CONF_GIT_PROXY=http://proxy.foo.com:8080
SET CONF_GIT_PROXY=

REM root folder in which you will call git clone.  Do not use a Drive root (e.g. C:\)
SET CONF_POSHGIT_STARTDIR=c:\github-personal

REM USER and EMAIL can be blank (set XXX=) if you want to force prompting

REM standard user info for git operations
SET CONF_GIT_DEFAULT_USER=John Doe
SET CONF_GIT_DEFAULT_EMAIL=johndoe@users.noreply.github.com

REM optional settings if a particular dir needs different git credentials for child repos
SET CONF_GIT_SECONDARY_USER=Jane Doe
SET CONF_GIT_SECONDARY_EMAIL=janedoe@users.noreply.github.com
SET CONF_GIT_SECONDARY_PATH=C:/github-personal/

REM End of default CONF_ variables
REM *****
REM *****

REM User overrides of CONF_
if exist "%~dp0\gitInstPersonal.cmd" call "%~dp0\gitInstPersonal.cmd"

echo.
SET CONF_
echo.

SET INSTALL_=
set /p INSTALL_="Are the above CONF_ variables correct (if not, edit '%~dp0\gitInstPersonal.cmd')? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done


:Chocolatey
REM SET INST_CHOC_PROXY=powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
SET INST_CHOC_NOPROXY=powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

echo Checking if chocolatey is installed...
powershell -ExecutionPolicy Unrestricted -Command "choco -?" > NUL 2>&1
if ERRORLEVEL 1 GOTO ChocoInstall

echo Chocolatey is installed.
rem echo Checking if chocolatey or other apps are outdated...

rem echo.
rem echo Apps Installed via chocolatey:
rem choco list -l

rem echo.
rem echo Apps with pending chocolatey updates:
rem choco outdated -l
REM TODO: check for updates, system config settings need to be re-applied after update

rem SET UPGRADE_=
rem set /p UPGRADE_="If there are any outdated packages listed above, do you want to update them outside of this tool before continuing? [y/n] (select n for git or poshgit as they will need to be reconfigured)"
rem if /I "%UPGRADE_:~0,1%" NEQ "y" Goto Git

rem echo To update all apps, use the command 'choco upgrade all -y'
rem echo When finished, re-run this script.
rem Goto Done

Goto Git

:ChocoInstall
echo Chocolatey is not installed.

SET INSTALL_=
set /p INSTALL_="Install Chocolatey to %ALLUSERSPROFILE%\chocolatey\bin ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Git

set ChocolateyToolsLocation=%CONF_CHOCO_TOOLS%

%INST_CHOC_NOPROXY%

REM Add to current path
SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

set ChocolateyToolsLocation=%CONF_CHOCO_TOOLS%
md %CONF_CHOCO_TOOLS%
setx ChocolateyToolsLocation "%CONF_CHOCO_TOOLS%"

choco feature enable -n useRememberedArgumentsForUpgrades

Goto Git

:Git
REM see https://chocolatey.org/packages/git.install for all options
SET GIT_OPT=/GitOnlyOnPath /WindowsTerminal /NoShellIntegration /SChannel

echo.
echo Checking if git is installed...
choco outdated | find /i "git.install|"
if not errorlevel 1 (goto GitInstall)

git --version > NUL
if NOT ERRORLEVEL 1 GOTO GitConfigure

:GitInstall
echo.
SET INSTALL_=
set /p INSTALL_="Install/Upgrade Git in %ProgramFiles%\Git ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigure

:retryWish
tasklist /FI "IMAGENAME eq wish.exe" 2>NUL | find /I /N "wish.exe">NUL
if "%ERRORLEVEL%"=="0" echo gitk is running...please close&pause&goto retryWish

:retryGit
tasklist /FI "IMAGENAME eq git.exe" 2>NUL | find /I /N "git.exe">NUL
if "%ERRORLEVEL%"=="0" echo git is running...please close&pause&goto retryGit

choco upgrade git --params="'%GIT_OPT%'" -y

REM Add to current path
SET PATH=%PATH%;%ProgramFiles%\Git\cmd

:GitConfigure
if .%CONF_GIT_PROXY%. NEQ .. (
  git config --global http.proxy %CONF_GIT_PROXY%
)
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with github for windows defaults, (e.g. p4, beyond compare, and visual studio merge/diff parameters) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureDefaultUser

REM Set some default git options
git config --system diff.algorithm histogram
git config --system difftool.prompt false
git config --system difftool.bc4.cmd "\"c:/program files (x86)/beyond compare 3/bcomp.exe\" \"$LOCAL\" \"$REMOTE\""
git config --system difftool.p4.cmd "\"c:/program files/Perforce/p4merge.exe\" \"$LOCAL\" \"$REMOTE\""
git config --system difftool.vs2012.cmd "\"c:/program files (x86)/microsoft visual studio 11.0/common7/ide/devenv.exe\" '//diff' \"$LOCAL\" \"$REMOTE\""
git config --system difftool.vs2013.cmd "\"c:/program files (x86)/microsoft visual studio 12.0/common7/ide/devenv.exe\" '//diff' \"$LOCAL\" \"$REMOTE\""

git config --system mergetool.prompt false
git config --system mergetool.keepbackup false
git config --system mergetool.bc3.cmd "\"c:/program files (x86)/beyond compare 3/bcomp.exe\" \"$LOCAL\" \"$REMOTE\" \"$BASE\" \"$MERGED\""
git config --system mergetool.bc3.trustexitcode true
git config --system mergetool.p4.cmd "\"c:/program files/Perforce/p4merge.exe\" \"$BASE\" \"$LOCAL\" \"$REMOTE\" \"$MERGED\""
git config --system mergetool.p4.trustexitcode false

:GitConfigureDefaultUser
if "%CONF_GIT_DEFAULT_USER%" EQU "" Goto :GitConfigureSecondaryUser
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with %CONF_GIT_DEFAULT_USER%/%CONF_GIT_DEFAULT_EMAIL% as the default user/email ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto :GitConfigureSecondaryUser

git config --global user.name "%CONF_GIT_DEFAULT_USER%"
git config --global user.email %CONF_GIT_DEFAULT_EMAIL%

:GitConfigureSecondaryUser
if "%CONF_GIT_SECONDARY_USER%" EQU "" Goto :GitConfigureDiff
echo.
echo if you have a path (CONF_GIT_SECONDARY_PATH=%CONF_GIT_SECONDARY_PATH%) under which git credentials need to be different, you can set them here.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with %CONF_GIT_SECONDARY_USER%/%CONF_GIT_SECONDARY_EMAIL% as the secondary user/email for repos under %CONF_GIT_SECONDARY_PATH%? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureDiff

rem todo: don't override .gitconfig-secondary
UpdateINI -s user name "%CONF_GIT_SECONDARY_USER%" "%USERPROFILE%\.gitconfig-secondary"
UpdateINI -s user email "%CONF_GIT_SECONDARY_EMAIL%" "%USERPROFILE%\.gitconfig-secondary"
rem convert crlf to lf
rem powershell "$file='%USERPROFILE%\.gitconfig-secondary';$text = [IO.File]::ReadAllText($file) -replace '`r`n', '`n';[IO.File]::WriteAllText($file, $text)"
git config --global includeIf."gitdir:%CONF_GIT_SECONDARY_PATH%".path ".gitconfig-secondary"


:GitConfigureDiff
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with p4merge as merge/difftool ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureLogAndColor

git config --global diff.tool p4
git config --global merge.tool p4

rem todo:  C:\Users\Admin\.config\git\gitk  update set extdifftool meld to set extdifftool p4merge- handle fresh install or missing setting
if exist "%USERPROFILE%\.config\git\gitk" (
    FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO (set DTS=%%a&set CUR_DATE=!DTS:~0,8!T!DTS:~8,6!)
    echo copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak"
    powershell "copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak""

    powershell "$file = '%USERPROFILE%\.config\git\gitk';(gc $file) -replace '^set extdifftool .*$','set extdifftool p4merge' -replace '^set diffcontext .*$','set diffcontext 6' | sc -Encoding ASCII $file
)

:GitConfigureLogAndColor
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with useful log alias and updated colors (improves readability of some dull-colored defaults) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureCerts

REM Git Log and color settings
git config --global alias.lg "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(yellow bold)%%d%%Creset %%s%%Cgreen(%%cr) %%C(cyan)<%%an>%%Creset' --abbrev-commit --date=relative"
git config --global alias.lg2 "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(blue bold)%%d%%Creset %%s%%Cgreen(%%cr) %%C(cyan)<%%an>%%Creset'"
git config --global alias.lg3 "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(yellow bold)%%d%%Creset %%s%%C(cyan)<%%an>%%Creset'"
git config --global color.branch.remote "red bold"
git config --global color.diff.new "green bold"
git config --global color.diff.old "red bold"
git config --global color.status.changed "red bold"
git config --global color.status.untracked "red bold"
git config --global color.status.added "green bold"
git config --global color.status.localBranch "green bold"
git config --global color.status.remoteBranch "red bold"

rem todo:  C:\Users\Admin\.config\git\gitk  update set permviews {} to set permviews {{{First Parent} {} --first-parent {}}}- handle fresh install or missing/different setting
if exist "%USERPROFILE%\.config\git\gitk" (
    FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO (set DTS=%%a&set CUR_DATE=!DTS:~0,8!T!DTS:~8,6!)
    echo copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak"
    powershell "copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak""

    powershell "$file = '%USERPROFILE%\.config\git\gitk';(gc $file) -replace '^set permviews {}$','set permviews {{{First Parent} {} --first-parent {}}}' | sc -Encoding ASCII $file
)

:GitConfigureCerts
REM skip reconfiguring certs.  Ass-u-me git is already configured for schannel
goto GitPad
echo.
SET INSTALL_=
set /p INSTALL_="Use OpenSSL and refresh CA cert bundle with certs from the windows cert store ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureSChannel

REM export the windows certs
BundleWinCerts "C:\Program Files\Git\mingw64\ssl\certs\ca-bundle.crt" "C:\Program Files\Git\mingw64\ssl\certs\ca-bundle-plusWinRoot.crt"

git config --global http.sslBackend openssl
git config --system http.sslcainfo "C:/Program Files/Git/mingw64/ssl/certs/ca-bundle-plusWinRoot.crt"

goto GitPad

:GitConfigureSChannel
echo.
SET INSTALL_=
set /p INSTALL_="Use schannel ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitPad

git config --global http.sslBackend schannel

goto GitPad
REM other stuff todo that GH4W did, but I'm not (yet):
REM create ssh key
REM editor env var
REM alias.c=commit
REM alias.co=checkout
REM alias.dt=difftool
REM alias.mt=mergetool
REM alias.praise=blame
REM alias.ff=merge --ff-only
REM alias.st=status
REM alias.sync=!git pull && git push

REM These settings aren't set, either because they are defaults, or I still need to decide
REM     apply.whitespace=nowarn                 (default: warn)     OK
REM     core.editor=gitpad                      (default: n/a)      Set below (optionally)
REM     core.preloadindex=true                  (default: true)     OK
REM     color.ui=true                           (default: true)     OK
REM     pack.packsizelimit=2g                   (default: <none>)   OK
REM     filter.ghcleansmudge.clean=cat          (default: )         TBD
REM     filter.ghcleansmudge.smudge=cat         (default: )         TBD
REM     push.default=upstream                   (default: simple)   OK

REM these are set, which weren't by GH4W:
REM     http.sslbackend=openssl                (default: )          TBD
REM     http.proxy=http://proxy.foo.com:8080   (default: n/a)       OK (set above)
REM     core.hidedotfiles=dotGitOnly           (default: dotGitOnly)   OK

:GitPad
rem https://stackoverflow.com/questions/10564/how-can-i-set-up-an-editor-to-work-with-git-on-windows
rem as of git for windows 2.5.3, notepad can be used as the editor (see https://github.com/git-for-windows/git/releases/tag/v2.5.3.windows.1)
rem as of git for windows 2.16, git will warn if it is waiting for editor to close
rem git 2.19.2 fixed a problem with wrapping that showed up when using notepad2 (?)
rem ** just tested with git 2.22.0.  using notepad 3 still produces some weird messages in the UI and on the commandline, so disable for now.
REM GitPad 1.4 not available on Chocloatey
REM GitPad 1.4 (official) targets .NET 2, so install modified version that targets .NET 4.5

:GitPadMigrateFromAppDataFile
if not exist "%APPDATA%\GitPad\GitPad.exe" Goto GitPadMigrateFromAppDataPath

if not exist "%PROGRAMDATA%\GitPad\GitPad.exe" robocopy "%APPDATA%\GitPad" "%PROGRAMDATA%\GitPad"

rd /s /q "%APPDATA%\GitPad"

:GitPadMigrateFromAppDataPath
if not exist "%PROGRAMDATA%\GitPad\GitPad.exe"  Goto GitPadInstall

rem remove appdata\gitpad
powershell -Command "$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true);$oldpath = $regKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$pathvals = $oldpath -split ';';if ($pathvals -like '*appdata*gitpad'){$pathvals2 = $pathvals -notlike '*appdata*gitpad';$newpath=$pathvals2 -join ';';$newpath=$newpath -replace ';;',';';$regKey.SetValue('Path', $newpath, [Microsoft.Win32.RegistryValueKind]::ExpandString)}"

goto GitPadAddToPath

:GitPadInstall
if exist "%PROGRAMDATA%\GitPad\GitPad.exe" Goto GitPadConfigureCheck
echo.
SET INSTALL_=
set /p INSTALL_="Install GitPad to %PROGRAMDATA%\GitPad ? [y/n]"
rem if /I "%INSTALL_:~0,1%" NEQ "y" Goto NotepadAsEditor
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-Git

rem powershell -Command "if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)) {[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12} (new-object System.Net.WebClient).Downloadfile('https://github.com/github/GitPad/releases/download/v1.4.0/Gitpad.zip', '%TEMP%\GitPad.zip');"
rem powershell -Command "Expand-Archive '%TEMP%\GitPad.zip' -DestinationPath '%PROGRAMDATA%\GitPad' -Force"

md "%PROGRAMDATA%\GitPad"
copy Gitpad.exe "%PROGRAMDATA%\GitPad"

:GitPadAddToPath
REM Add to current path
SET PATH=%PATH%;%PROGRAMDATA%\GitPad

powershell  -Command !="^"!^
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true);^
    $oldpath = $regKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);^
    $pathvals = $oldpath -split ';';^
    if (($pathvals ^| %%{$_ -like '*programdata*gitpad'}) -notcontains $true) {^
        $newpath=$oldpath + ';%%PROGRAMDATA%%\GitPad';^
        $newpath=$newpath -replace ';;',';';^
        $regKey.SetValue('Path', $newpath, [Microsoft.Win32.RegistryValueKind]::ExpandString)^
    }"

call :broadcastSettingsChange

goto GitPadConfigure

:GitPadConfigureCheck
echo.
git config -l | find "core.editor" > NUL
if NOT ERRORLEVEL 1 Goto Posh-Git
SET INSTALL_=
set /p INSTALL_="Configure GitPad as the git editor (use notepad instead of Vim)? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-Git


:GitPadConfigure
git config --system core.editor gitpad

goto Posh-Git

:NotepadAsEditor
goto Posh-Git
echo.
SET INSTALL_=
set /p INSTALL_="Configure Notepad as the git editor ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-Git

git config --system core.editor notepad

rem todo:
rem notepad++ (git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin")
goto Posh-Git

:Posh-Git

choco outdated | find /i "poshgit|"
if not errorlevel 1 (goto Posh-GitInstall)

powershell -ExecutionPolicy Unrestricted -Command "if (test-path '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git-*\profile.example.ps1'){exit 1}"
if ERRORLEVEL 1 Goto Posh-GitConfigure

:Posh-GitInstall
echo.
SET INSTALL_=
set /p INSTALL_="Install Posh-Git to %CONF_CHOCO_TOOLS%\poshgit (close any running instances if upgrade is needed)? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-GitConfigure

rem get  current profile (if any)
SET PROF_EXISTS=0
if EXIST "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" (
  SET PROF_EXISTS=1
) ELSE (
 copy "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" "%USERPROFILE%\Documents\WindowsPowerShell\tmp Microsoft.PowerShell_profile.ps1"
)
choco upgrade poshgit -y

powershell -ExecutionPolicy Unrestricted -Command "if (get-service 'ssh-agent'-ErrorAction SilentlyContinue){$svc = get-service 'ssh-agent'; if ($svc.StartType -eq 'Disabled'){Set-Service ssh-agent -StartupType Manual}; git config --global core.sshcommand "C:/Windows/System32/OpenSSH/ssh.exe"}"

Goto Posh-GitConfigure

:Posh-GitConfigure
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Configure Posh-Git colors (improves readability of some dull-colored defaults) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Shortcut

rem restore previous profile/delete
if "%PROF_EXISTS%" EQU "0" (
  DEL "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
) ELSE (
  DEL "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
  ren "%USERPROFILE%\Documents\WindowsPowerShell\tmpMicrosoft.PowerShell_profile.ps1" "Microsoft.PowerShell_profile.ps1"
)

rem tweak some posh-git prompt colors to improve readaility (IMHO)
> "%~dp0\tmpCustomInstall.ps1" (
echo function insert-line($file, $line, $match, $after^) {
echo     $fc = gc $file;
echo     $alreadydone = $fc ^| %%{$_ -match $match};
echo     If($alreadydone -contains $false^){
echo         $idx=($fc^|sls $after^).LineNumber;
echo         $newfc=@(^);
echo         0..($fc.Count-1^)^|%%{
echo             if ($_ -eq $idx^){
echo                 $newfc +=$line;
echo             }
echo             $newfc += $fc[$_];
echo         }
echo         $newfc ^| out-file $file;
echo     }
echo }
echo $file = (gci '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git*\profile.example.ps1'^).FullName;
echo insert-line $file '$Global:GitPromptSettings.LocalWorkingStatusForegroundColor  = [ConsoleColor]::Red' 'LocalWorkingStatusForegroundColor' 'GitPromptSettings.BranchBehindAndAheadDisplay';
echo insert-line $file '$Global:GitPromptSettings.WorkingForegroundColor  = [ConsoleColor]::Red' 'WorkingForegroundColor' 'GitPromptSettings.LocalWorkingStatusForegroundColor';
echo #insert-line $file '$env:LC_ALL=''C.UTF-8''' 'LC_ALL' 'GitPromptSettings.WorkingForegroundColor';
)

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\tmpCustomInstall.ps1'"
del "%~dp0\tmpCustomInstall.ps1"

Goto Shortcut

rem create powershell shortcut on desktop pointing to install path
:Shortcut

rem if exist "%USERPROFILE%\Desktop\PoshGitShell.lnk" Goto Done
echo.
SET INSTALL_=
set /p INSTALL_="[Re]Create Posh-Git shell shortcut on desktop (select y if poshgit was upgraded)? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done

md %CONF_POSHGIT_STARTDIR%

> "%~dp0\tmpCustomInstall.ps1" (
echo $Home
echo $file = (gci '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git*\profile.example.ps1'^).FullName;
echo $WshShell = New-Object -comObject WScript.Shell
echo $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\PoshGitShell.lnk"^)
echo $Shortcut.TargetPath = '%WINDIR%\System32\WindowsPowershell\v1.0\Powershell.exe'
echo $Shortcut.Arguments = "-NoExit -ExecutionPolicy Unrestricted -File ""$file"" choco"
echo $Shortcut.IconLocation = "%~dp0poshgit.ico"
echo $Shortcut.WorkingDirectory = '%CONF_POSHGIT_STARTDIR%'
echo $Shortcut.Save(^)
)

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\tmpCustomInstall.ps1'"
del "%~dp0\tmpCustomInstall.ps1"

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\pscolor.ps1' '%USERPROFILE%\Desktop\PoshGitShell.lnk'"

copy "%USERPROFILE%\Desktop\PoshGitShell.lnk" "%APPDATA%\Microsoft\Internet Explorer\Quick Launch"
rem todo admin poshgitshell (and update profile.example.ps1?)
Goto Done

rem todo: add this:
rem {
rem     // posh-git.
rem     "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44be}",
rem     "name": "PoshGitShell",
rem     "commandline": "powershell.exe -NoExit -ExecutionPolicy Unrestricted -File \"C:\\Tools\\poshgit\\dahlbyk-posh-git-9bda399\\profile.example.ps1\" choco",
rem     "hidden": false,
rem     "icon" : "C:\\github-personal\\DevEnvInit\\poshgit.ico",
rem     "startingDirectory" : "C:\\github-personal",
rem     "colorScheme": "Campbell Powershell"
rem },
rem to %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
rem while retaining comments (and whitespace?)

::UtilityFunctions

:checkadmin
openfiles > NUL 2>&1 
if NOT %ERRORLEVEL% EQU 0 (
SET _ISADMIN=0
) else (
SET _ISADMIN=1
)
goto :eof

:broadcastSettingsChange
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

powershell -ExecutionPolicy Unrestricted -Command "& '%~dp0\tmpCustomInstall.ps1'" >nul
del "%~dp0\tmpCustomInstall.ps1"
goto :eof

:Done
echo.
echo Done

ENDLOCAL
