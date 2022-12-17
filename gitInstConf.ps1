<#
.SYNOPSIS
Install/Update and configure choolately, git, and posh-git
#>

#Requires -Version 5.1

$HTTP_PROXY = $null
$HTTPS_PROXY = $null

#Check Admin
function Test-AdminElevation {
  <#
.SYNOPSIS
Determines if the console is elevated

#>
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
  return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

if (!(Test-AdminElevation)) {
  write-host "must run as admin"
  exit 1
}

#Check powershell execution policy
$pol = get-executionpolicy
if (@('Unrestricted', 'Bypass') -notcontains $pol) {
  write-host "Powershell must have an execution policy of unrestricted or bypass for this tool to work."

  $install = Read-Host -Prompt "Do you want to set the execution policy to Unrestricted for the current user? [y/n]"
  if ( $install -match "[yY]" ) {
    set-executionpolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
  }
  else {
    exit 1
  }
}

#--- Local functions ---
. "$PSScriptRoot\support\LocalInstallUtils.ps1"

#Check env vars
# Set default value here.  If the variable exists, do not change.  If not, override in CONF_ section below
$CONF_CHOCO_TOOLS = $env:ChocolateyToolsLocation
# Special case:  ChocolateyToolsLocation is a user env var, not a system env var.
#                if another user has already created C:\Bin\chocotools or C:\tools, use that base
if ($null -eq $CONF_CHOCO_TOOLS) {
  if (Test-Path C:\Bin\chocotools) {
    $CONF_CHOCO_TOOLS = 'C:\Bin\chocotools'
  }
  else {
    if (Test-Path  C:\tools) {
      $CONF_CHOCO_TOOLS = 'C:\Tools'
    }
  }
}

# Set default CONF_ variables here:

# only override CONF_CHOCO_TOOLS if chocolatey is not installed yet
if ($null -eq $CONF_CHOCO_TOOLS) {
  $CONF_CHOCO_TOOLS = 'C:\Tools'
}

# if http proxy is needed for git, set this variable
# $CONF_GIT_PROXY='http://proxy.foo.com:8080'
$CONF_GIT_PROXY = $null

# root folder in which you will call git clone.  Do not use a Drive root (e.g. C:\)
$CONF_POSHGIT_STARTDIR = 'C:\github-personal'

# USER and EMAIL can be blank (set XXX=) if you want to force prompting

# standard user info for git operations
$CONF_GIT_DEFAULT_USER = 'John Doe'
$CONF_GIT_DEFAULT_EMAIL = 'johndoe@users.noreply.github.com'

# optional settings if a particular dir needs different git credentials for child repos
$CONF_GIT_SECONDARY_USER = 'Jane Doe'
$CONF_GIT_SECONDARY_EMAIL = 'janedoe@users.noreply.github.com'
$CONF_GIT_SECONDARY_PATH = 'C:/github-personal/'

# End of default CONF_ variables

# User overrides of CONF_
if (Test-Path "$PSScriptRoot\gitInstPersonal.ps1" ) { . "$PSScriptRoot\gitInstPersonal.ps1" }

write-host ''
Get-Variable | ? { $_.Name -match '^CONF_' } | % { "$($_.Name)=$($_.Value)" }
write-host ''

$install = Read-Host -Prompt "Are the above CONF_ variables correct (if not, edit '$PSScriptRoot\gitInstPersonal.cmd')? [y/n]"
if ( $install -notmatch "[yY]" ) {
  exit 1
}

#Chocolatey
write-host 'Checking if chocolatey is installed...'
if ((Get-Command "choco.exe" -ErrorAction SilentlyContinue) -eq $null) {
  #ChocoInstall
  write-host 'Chocolatey is not installed.'

  $install = Read-Host -Prompt "Install Chocolatey to $($env:ALLUSERSPROFILE)\chocolatey\bin ? [y/n]"
  if ( $install -match "[yY]" ) {
    $env:ChocolateyToolsLocation = $CONF_CHOCO_TOOLS
    #Proxy
    #[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    #No Proxy
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Add to current path
    $env:Path += "$($env:ALLUSERSPROFILE)\chocolatey\bin"

    if (-not(Test-Path $CONF_CHOCO_TOOLS)) { New-Item -ItemType Directory -Force -Path $CONF_CHOCO_TOOLS }
    setx ChocolateyToolsLocation "%CONF_CHOCO_TOOLS%"

    choco feature enable -n useRememberedArgumentsForUpgrades
  }
}

<#

:Git
# see https://chocolatey.org/packages/git.install for all options
SET GIT_OPT=/GitOnlyOnPath /WindowsTerminal /NoShellIntegration /SChannel

write-host ''
write-host Checking if git is installed...
choco outdated | find /i "git.install|"
if not errorlevel 1 (goto GitInstall)
choco outdated | find /i "git|"
if not errorlevel 1 (goto GitInstall)

git --version > NUL
if NOT ERRORLEVEL 1 GOTO GitConfigure

:GitInstall
write-host ''
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

# Add to current path
SET PATH=%PATH%;%ProgramFiles%\Git\cmd

:GitConfigure
if .%CONF_GIT_PROXY%. NEQ .. (
  git config --global http.proxy %CONF_GIT_PROXY%
)
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with github for windows defaults, (e.g. p4, beyond compare, and visual studio merge/diff parameters) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureDefaultUser

# Set some default git options
git config --system diff.algorithm histogram
git config --system difftool.prompt false
git config --system difftool.bc4.cmd "\"c:/Program Files/Beyond Compare 4/bcomp.exe\" \"$LOCAL\" \"$REMOTE\""
git config --system difftool.bc4dir.cmd "\"c:/Program Files/Beyond Compare 4/BCompare.exe\" -ro -expandall -solo \"$LOCAL\" \"$REMOTE\""
git config --system difftool.bc4diredit.cmd "\"c:/Program Files/Beyond Compare 4/BCompare.exe\" -lro -expandall -solo \"$LOCAL\" \"$REMOTE\""
git config --system difftool.p4.cmd "\"c:/program files/Perforce/p4merge.exe\" \"$LOCAL\" \"$REMOTE\""
git config --system difftool.vs2012.cmd "\"c:/program files (x86)/microsoft visual studio 11.0/common7/ide/devenv.exe\" '//diff' \"$LOCAL\" \"$REMOTE\""
git config --system difftool.vs2013.cmd "\"c:/program files (x86)/microsoft visual studio 12.0/common7/ide/devenv.exe\" '//diff' \"$LOCAL\" \"$REMOTE\""

git config --system mergetool.prompt false
git config --system mergetool.keepbackup false
git config --system mergetool.bc3.cmd "\"c:/program files (x86)/beyond compare 3/bcomp.exe\" \"$LOCAL\" \"$REMOTE\" \"$BASE\" \"$MERGED\""
git config --system mergetool.bc3.trustexitcode true
git config --system mergetool.p4.cmd "\"c:/program files/Perforce/p4merge.exe\" \"$BASE\" \"$LOCAL\" \"$REMOTE\" \"$MERGED\""
git config --system mergetool.p4.trustexitcode false

git config --global --add safe.directory '*'
git config --global alias.diffdir "difftool --dir-diff --tool=bc4dir --no-prompt"
git config --global alias.diffdirsym "-c core.symlinks=true difftool --dir-diff --tool=bc4diredit --no-prompt"

:GitConfigureDefaultUser
if "%CONF_GIT_DEFAULT_USER%" EQU "" Goto :GitConfigureSecondaryUser
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with %CONF_GIT_DEFAULT_USER%/%CONF_GIT_DEFAULT_EMAIL% as the default user/email ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto :GitConfigureSecondaryUser

git config --global user.name "%CONF_GIT_DEFAULT_USER%"
git config --global user.email %CONF_GIT_DEFAULT_EMAIL%

:GitConfigureSecondaryUser
if "%CONF_GIT_SECONDARY_USER%" EQU "" Goto :GitConfigureDiff
write-host ''
write-host if you have a path (CONF_GIT_SECONDARY_PATH=%CONF_GIT_SECONDARY_PATH%) under which git credentials need to be different, you can set them here.
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with %CONF_GIT_SECONDARY_USER%/%CONF_GIT_SECONDARY_EMAIL% as the secondary user/email for repos under %CONF_GIT_SECONDARY_PATH%? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureDiff

# todo: don't override .gitconfig-secondary
UpdateINI -s user name "%CONF_GIT_SECONDARY_USER%" "%USERPROFILE%\.gitconfig-secondary"
UpdateINI -s user email "%CONF_GIT_SECONDARY_EMAIL%" "%USERPROFILE%\.gitconfig-secondary"
# convert crlf to lf
# powershell "$file='%USERPROFILE%\.gitconfig-secondary';$text = [IO.File]::ReadAllText($file) -replace '`r`n', '`n';[IO.File]::WriteAllText($file, $text)"
git config --global includeIf."gitdir:%CONF_GIT_SECONDARY_PATH%".path ".gitconfig-secondary"


:GitConfigureDiff
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with p4merge as merge/difftool ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureLogAndColor

git config --global diff.tool p4
git config --global merge.tool p4

# todo:  C:\Users\Admin\.config\git\gitk  update set extdifftool meld to set extdifftool p4merge- handle fresh install or missing setting
if exist "%USERPROFILE%\.config\git\gitk" (
    FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO (set DTS=%%a&set CUR_DATE=!DTS:~0,8!T!DTS:~8,6!)
    echo copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak"
    powershell "copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak""

    powershell "$file = '%USERPROFILE%\.config\git\gitk';(gc $file) -replace '^set extdifftool .*$','set extdifftool p4merge' -replace '^set diffcontext .*$','set diffcontext 6' | sc -Encoding ASCII $file
)

:GitConfigureLogAndColor
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Configure git with useful log alias and updated colors (improves readability of some dull-colored defaults) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureCerts

# Git Log and color settings
git config --global alias.lg "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(yellow bold)%%d%%Creset %%s%%Cgreen(%%cr) %%C(cyan)<%%an>%%Creset' --abbrev-commit --date=relative"
git config --global alias.lg2 "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(blue bold)%%d%%Creset %%s%%Cgreen(%%cr) %%C(cyan)<%%an>%%Creset'"
git config --global alias.lg3 "log --graph --pretty=format:'%%C(red bold)%%h%%Creset -%%C(yellow bold)%%d%%Creset %%s%%C(cyan)<%%an>%%Creset'"
git config --global color.branch.remote "red bold"
git config --global color.diff.new "green bold"
git config --global color.diff.old "red bold"
::status colors:
::see https://github.com/git/git/blob/master/wt-status.h, https://github.com/git/git/blob/master/wt-status.c, https://github.com/git/git/blob/master/builtin/commit.c
::WT_STATUS_UPDATED 'added' or 'updated'
git config --global color.status.added "green bold"
::WT_STATUS_CHANGED
git config --global color.status.changed "red bold"
::WT_STATUS_UNTRACKED
git config --global color.status.untracked "red bold"
::WT_STATUS_NOBRANCH
git config --global color.status.nobranch "red bold"
::WT_STATUS_UNMERGED
git config --global color.status.unmerged "red bold"
::WT_STATUS_LOCAL_BRANCH
git config --global color.status.localBranch "green bold"
::WT_STATUS_REMOTE_BRANCH
git config --global color.status.remoteBranch "red bold"

# todo:  C:\Users\Admin\.config\git\gitk  update set permviews {} to set permviews {{{First Parent} {} --first-parent {}}}- handle fresh install or missing/different setting
if exist "%USERPROFILE%\.config\git\gitk" (
    FOR /f %%a in ('WMIC OS GET LocalDateTime ^| find "."') DO (set DTS=%%a&set CUR_DATE=!DTS:~0,8!T!DTS:~8,6!)
    echo copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak"
    powershell "copy "%USERPROFILE%\.config\git\gitk" "%USERPROFILE%\.config\git\gitk_!CUR_DATE!.bak""

    powershell "$file = '%USERPROFILE%\.config\git\gitk';(gc $file) -replace '^set permviews {}$','set permviews {{{First Parent} {} --first-parent {}}}' | sc -Encoding ASCII $file
)

:GitConfigureCerts
# skip reconfiguring certs.  Ass-u-me git is already configured for schannel
goto GitPad
write-host ''
SET INSTALL_=
set /p INSTALL_="Use OpenSSL and refresh CA cert bundle with certs from the windows cert store ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitConfigureSChannel

# export the windows certs
BundleWinCerts "C:\Program Files\Git\mingw64\ssl\certs\ca-bundle.crt" "C:\Program Files\Git\mingw64\ssl\certs\ca-bundle-plusWinRoot.crt"

git config --global http.sslBackend openssl
git config --system http.sslcainfo "C:/Program Files/Git/mingw64/ssl/certs/ca-bundle-plusWinRoot.crt"

goto GitPad

:GitConfigureSChannel
write-host ''
SET INSTALL_=
set /p INSTALL_="Use schannel ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto GitPad

git config --global http.sslBackend schannel

goto GitPad
# other stuff todo that GH4W did, but I'm not (yet):
# create ssh key
# editor env var
# alias.c=commit
# alias.co=checkout
# alias.dt=difftool
# alias.mt=mergetool
# alias.praise=blame
# alias.ff=merge --ff-only
# alias.st=status
# alias.sync=!git pull && git push

# These settings aren't set, either because they are defaults, or I still need to decide
#     apply.whitespace=nowarn                 (default: warn)     OK
#     core.editor=gitpad                      (default: n/a)      Set below (optionally)
#     core.preloadindex=true                  (default: true)     OK
#     color.ui=true                           (default: true)     OK
#     pack.packsizelimit=2g                   (default: <none>)   OK
#     filter.ghcleansmudge.clean=cat          (default: )         TBD
#     filter.ghcleansmudge.smudge=cat         (default: )         TBD
#     push.default=upstream                   (default: simple)   OK

# these are set, which weren't by GH4W:
#     http.sslbackend=openssl                (default: )          TBD
#     http.proxy=http://proxy.foo.com:8080   (default: n/a)       OK (set above)
#     core.hidedotfiles=dotGitOnly           (default: dotGitOnly)   OK

:GitPad
# https://stackoverflow.com/questions/10564/how-can-i-set-up-an-editor-to-work-with-git-on-windows
# as of git for windows 2.5.3, notepad can be used as the editor (see https://github.com/git-for-windows/git/releases/tag/v2.5.3.windows.1)
# as of git for windows 2.16, git will warn if it is waiting for editor to close
# git 2.19.2 fixed a problem with wrapping that showed up when using notepad2 (?)
# ** just tested with git 2.22.0.  using notepad 3 still produces some weird messages in the UI and on the commandline, so disable for now.
# GitPad 1.4 not available on Chocloatey
# GitPad 1.4 (official) targets .NET 2, so install modified version that targets .NET 4.5

:GitPadMigrateFromAppDataFile
if not exist "%APPDATA%\GitPad\GitPad.exe" Goto GitPadMigrateFromAppDataPath

if not exist "%PROGRAMDATA%\GitPad\GitPad.exe" robocopy "%APPDATA%\GitPad" "%PROGRAMDATA%\GitPad"

rd /s /q "%APPDATA%\GitPad"

:GitPadMigrateFromAppDataPath
if not exist "%PROGRAMDATA%\GitPad\GitPad.exe"  Goto GitPadInstall

# remove appdata\gitpad
powershell -Command "$regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true);$oldpath = $regKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$pathvals = $oldpath -split ';';if ($pathvals -like '*appdata*gitpad'){$pathvals2 = $pathvals -notlike '*appdata*gitpad';$newpath=$pathvals2 -join ';';$newpath=$newpath -replace ';;',';';$regKey.SetValue('Path', $newpath, [Microsoft.Win32.RegistryValueKind]::ExpandString)}"

goto GitPadAddToPath

:GitPadInstall
if exist "%PROGRAMDATA%\GitPad\GitPad.exe" Goto GitPadConfigureCheck
write-host ''
SET INSTALL_=
set /p INSTALL_="Install GitPad to %PROGRAMDATA%\GitPad ? [y/n]"
# if /I "%INSTALL_:~0,1%" NEQ "y" Goto NotepadAsEditor
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-Git

# powershell -Command "if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)) {[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12} (new-object System.Net.WebClient).Downloadfile('https://github.com/github/GitPad/releases/download/v1.4.0/Gitpad.zip', '%TEMP%\GitPad.zip');"
# powershell -Command "Expand-Archive '%TEMP%\GitPad.zip' -DestinationPath '%PROGRAMDATA%\GitPad' -Force"

md "%PROGRAMDATA%\GitPad"
copy Gitpad.exe "%PROGRAMDATA%\GitPad"

:GitPadAddToPath
# Add to current path
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
write-host ''
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
write-host ''
SET INSTALL_=
set /p INSTALL_="Configure Notepad as the git editor ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-Git

git config --system core.editor notepad

# todo:
# notepad++ (git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin")
goto Posh-Git

:Posh-Git

choco outdated | find /i "poshgit|"
if not errorlevel 1 (goto Posh-GitInstall)

powershell -ExecutionPolicy Unrestricted -Command "if (test-path '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git-*\profile.example.ps1'){exit 1}"
if ERRORLEVEL 1 Goto Posh-GitConfigure

:Posh-GitInstall
write-host ''
SET INSTALL_=
set /p INSTALL_="Install Posh-Git to %CONF_CHOCO_TOOLS%\poshgit (close any running instances if upgrade is needed)? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Posh-GitConfigure

# get  current profile (if any)
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
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Configure Posh-Git colors (improves readability of some dull-colored defaults) ? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Shortcut

# restore previous profile/delete
if "%PROF_EXISTS%" EQU "0" (
  DEL "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
) ELSE (
  DEL "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
  ren "%USERPROFILE%\Documents\WindowsPowerShell\tmpMicrosoft.PowerShell_profile.ps1" "Microsoft.PowerShell_profile.ps1"
)

# tweak some posh-git prompt colors to improve readaility (IMHO)
> "$PSScriptRoot\tmpCustomInstall.ps1" (
write-host function insert-line($file, $line, $match, $after^) {
write-host     $fc = gc $file
write-host     If (-not (sls -Path $file -Pattern $match -Quiet^)^) {
write-host         $idx=($fc^|sls $after^).LineNumber
write-host         $newfc=@(^)
write-host         0..($fc.Count-1^)^|%%{
write-host             if ($_ -eq $idx^){
write-host                 $newfc +=$line
write-host             }
write-host             $newfc += $fc[$_]
write-host         }
write-host         $newfc ^| out-file $file
write-host     }
write-host }
write-host $file = (gci '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git*\profile.example.ps1'^).FullName;
write-host insert-line $file '$Global:GitPromptSettings.LocalWorkingStatusForegroundColor  = [ConsoleColor]::Red' 'LocalWorkingStatusForegroundColor' 'GitPromptSettings.BranchBehindAndAheadDisplay';
write-host insert-line $file '$Global:GitPromptSettings.WorkingForegroundColor  = [ConsoleColor]::Red' 'WorkingForegroundColor' 'GitPromptSettings.LocalWorkingStatusForegroundColor';
write-host #insert-line $file '$env:LC_ALL=''C.UTF-8''' 'LC_ALL' 'GitPromptSettings.WorkingForegroundColor';
)

powershell -ExecutionPolicy Unrestricted -Command "& '$PSScriptRoot\tmpCustomInstall.ps1'"
del "$PSScriptRoot\tmpCustomInstall.ps1"

Goto Shortcut

# create powershell shortcut on desktop pointing to install path
:Shortcut

# if exist "%USERPROFILE%\Desktop\PoshGitShell.lnk" Goto Done
write-host ''
SET INSTALL_=
set /p INSTALL_="[Re]Create Posh-Git shell shortcut on desktop (select y if poshgit was upgraded)? [y/n]"
if /I "%INSTALL_:~0,1%" NEQ "y" Goto Done

md %CONF_POSHGIT_STARTDIR%

> "$PSScriptRoot\tmpCustomInstall.ps1" (
write-host $Home
write-host $file = (gci '%CONF_CHOCO_TOOLS%\poshgit\dahlbyk-posh-git*\profile.example.ps1'^).FullName;
write-host $WshShell = New-Object -comObject WScript.Shell
write-host $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\PoshGitShell.lnk"^)
write-host $Shortcut.TargetPath = '%WINDIR%\System32\WindowsPowershell\v1.0\Powershell.exe'
write-host $Shortcut.Arguments = "-NoExit -ExecutionPolicy Unrestricted -File ""$file"" choco"
write-host $Shortcut.IconLocation = "$PSScriptRoot\poshgit.ico"
write-host $Shortcut.WorkingDirectory = '%CONF_POSHGIT_STARTDIR%'
write-host $Shortcut.Save(^)
)

powershell -ExecutionPolicy Unrestricted -Command "& '$PSScriptRoot\tmpCustomInstall.ps1'"
del "$PSScriptRoot\tmpCustomInstall.ps1"

powershell -ExecutionPolicy Unrestricted -Command "& '$PSScriptRoot\pscolor.ps1' '%USERPROFILE%\Desktop\PoshGitShell.lnk'"

copy "%USERPROFILE%\Desktop\PoshGitShell.lnk" "%APPDATA%\Microsoft\Internet Explorer\Quick Launch"
# todo admin poshgitshell (and update profile.example.ps1?)
# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -ExecutionPolicy Unrestricted -Command "cd c:\github-personal; C:\Tools\poshgit\dahlbyk-posh-git-9bda399\profile.example.ps1 choco"
Goto Done

# todo: add this:
# {
#     // posh-git.
#     "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44be}",
#     "name": "PoshGitShell",
#     "commandline": "powershell.exe -NoExit -ExecutionPolicy Unrestricted -File \"C:\\Tools\\poshgit\\dahlbyk-posh-git-9bda399\\profile.example.ps1\" choco",
#     "hidden": false,
#     "icon" : "C:\\github-personal\\DevEnvInit\\poshgit.ico",
#     "startingDirectory" : "C:\\github-personal",
#     "colorScheme": "Campbell Powershell"
# },
# to %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
# while retaining comments (and whitespace?)

::UtilityFunctions

:broadcastSettingsChange
> "$PSScriptRoot\tmpCustomInstall.ps1" (
write-host if (-not ("Win32.NativeMethods" -as [Type]^)^) {
write-host Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
write-host [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto^)]
write-host public static extern IntPtr SendMessageTimeout(
write-host     IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
write-host     uint fuFlags, uint uTimeout, out UIntPtr lpdwResult^);
write-host "@
write-host }
write-host $HWND_BROADCAST = [IntPtr] 0xffff;
write-host $WM_SETTINGCHANGE = 0x1a;
write-host $result = [UIntPtr]::Zero
write-host [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref] $result^);
)

powershell -ExecutionPolicy Unrestricted -Command "& '$PSScriptRoot\tmpCustomInstall.ps1'" >nul
del "$PSScriptRoot\tmpCustomInstall.ps1"
goto :eof

:Done
write-host ''
write-host Done

ENDLOCAL
#>