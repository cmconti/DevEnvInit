<#
.SYNOPSIS
Install/Update and configure choolately, git, and posh-git
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

#--- Local functions ---
. "$PSScriptRoot\support\LocalInstallUtils.ps1"

$HTTP_PROXY = $null
$HTTPS_PROXY = $null

#Check Admin
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

prepForPSModule

#Check env vars
# Set default CONF_ variables here:

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
$install = Read-Host -Prompt "Are the above CONF_ variables correct (if not, edit '$PSScriptRoot\gitInstPersonal.ps1')? [y/n]"
if ( $install -notmatch "[yY]" ) {
  exit 1
}

#Chocolatey
write-host 'Checking if chocolatey is installed...'
if ($null -eq (Get-Command "choco.exe" -ErrorAction SilentlyContinue)) {
  #ChocoInstall
  write-host 'Chocolatey is not installed.  Exiting.'
  exit 1
}

If (!(Get-module chocolateyInstaller )) {Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1}

#Git
write-host ''
write-host 'Checking if git is installed or out of date...'
$outOfDate = $null -ne (choco outdated | ? { $_ -match '^git.install\||^git\|' })
$needToInstall = $outOfDate -or ($null -eq (Get-Command "git.exe" -ErrorAction SilentlyContinue))

if ($needToInstall) {
  $install = Read-Host -Prompt "Install/Upgrade Git in $env:ProgramFiles\Git ? [y/n]"
  if ( $install -match "[yY]" ) {
    #Validate that wish.exe is not running
    while ($null -ne (get-process "wish" -ea SilentlyContinue)) {
      Read-Host -Prompt "gitk is running...please close.  press return to continue."
    }

    #Validate that git.exe is not running
    while ($null -ne (get-process "git" -ea SilentlyContinue)) {
      Read-Host -Prompt "git is running...please close.  press return to continue."
    }

    # see https://chocolatey.org/packages/git.install for all options
    choco upgrade -y git --params '"/GitOnlyOnPath /WindowsTerminal /NoShellIntegration /SChannel"'
  }

  update-sessionenvironment
}

#GitConfigure
if ($null -ne $CONF_GIT_PROXY) {
  git config --global http.proxy $CONF_GIT_PROXY
}

write-host ''
$install = Read-Host -Prompt "[Re]Configure git with github for windows defaults, (e.g. p4, beyond compare, and visual studio merge/diff parameters) ? [y/n]"
if ( $install -match "[yY]" ) {

  # Set some default git options
  git config --global diff.algorithm histogram
  git config --global difftool.prompt false
  git config --global difftool.bc4.cmd '\"c:/Program Files/Beyond Compare 4/bcomp.exe\" \"$LOCAL\" \"$REMOTE\"'
  git config --global difftool.bc4dir.cmd '\"c:/Program Files/Beyond Compare 4/BCompare.exe\" -ro -expandall -solo \"$LOCAL\" \"$REMOTE\"'
  git config --global difftool.bc4diredit.cmd '\"c:/Program Files/Beyond Compare 4/BCompare.exe\" -lro -expandall -solo \"$LOCAL\" \"$REMOTE\"'
  git config --global difftool.p4.cmd '\"c:/Program files/Perforce/p4merge.exe\" \"$LOCAL\" \"$REMOTE\"'
  git config --global difftool.vs2012.cmd '\"c:/Program files (x86)/microsoft visual studio 11.0/common7/ide/devenv.exe\" ''//diff'' \"$LOCAL\" \"$REMOTE\"'
  git config --global difftool.vs2013.cmd '\"c:/Program files (x86)/microsoft visual studio 12.0/common7/ide/devenv.exe\" ''//diff'' \"$LOCAL\" \"$REMOTE\"'

  git config --global mergetool.prompt false
  git config --global mergetool.keepbackup false
  git config --global mergetool.p4.cmd '\"c:/program files/Perforce/p4merge.exe\" \"$BASE\" \"$LOCAL\" \"$REMOTE\" \"$MERGED\"'
  git config --global mergetool.p4.trustexitcode false

  if ($null -eq (git config --global --get-all safe.directory | ? { $_ -match '^\*$' })) {
    git config --global --add safe.directory '*'
  }
  git config --global alias.diffdir 'difftool --dir-diff --tool=bc4dir --no-prompt'
  git config --global alias.diffdirsym '-c core.symlinks=true difftool --dir-diff --tool=bc4diredit --no-prompt'
}

#GitConfigureDefaultUser
if ($null -ne $CONF_GIT_DEFAULT_USER) {
  write-host ''
  $install = Read-Host -Prompt "[Re]Configure git with $CONF_GIT_DEFAULT_USER/$CONF_GIT_DEFAULT_EMAIL as the default user/email ? [y/n]"
  if ( $install -match "[yY]" ) {
    git config --global user.name $CONF_GIT_DEFAULT_USER
    git config --global user.email $CONF_GIT_DEFAULT_EMAIL
  }
}

#GitConfigureSecondaryUser
if ($null -ne $CONF_GIT_SECONDARY_USER) {
  write-host ''
  write-host "If you have a path (CONF_GIT_SECONDARY_PATH=$CONF_GIT_SECONDARY_PATH) under which git credentials need to be different, you can set them here."
  $install = Read-Host -Prompt "[Re]Configure git with $CONF_GIT_SECONDARY_USER/$CONF_GIT_SECONDARY_EMAIL as the secondary user/email for repos under $CONF_GIT_SECONDARY_PATH? [y/n]"
  if ( $install -match "[yY]" ) {
    # todo: don't override .gitconfig-secondary
    &"$PSScriptRoot\support\UpdateINI.exe" -s user name $CONF_GIT_SECONDARY_USER "$env:USERPROFILE\.gitconfig-secondary"
    &"$PSScriptRoot\support\UpdateINI.exe" -s user email $CONF_GIT_SECONDARY_EMAIL "$env:USERPROFILE\.gitconfig-secondary"
    # convert crlf to lf
    # $file="$env:USERPROFILE\.gitconfig-secondary";$text = [IO.File]::ReadAllText($file) -replace '`r`n', '`n';[IO.File]::WriteAllText($file, $text)"
    git config --global includeIf."gitdir:$CONF_GIT_SECONDARY_PATH".path ".gitconfig-secondary"
  }
}

#GitConfigureDiff
write-host ''
$install = Read-Host -Prompt "[Re]Configure git with p4merge as merge/difftool ? [y/n]"
if ( $install -match "[yY]" ) {
  git config --global diff.tool p4
  git config --global merge.tool p4

  $gitkConfigDir = "$env:USERPROFILE\.config\git"
  $gitkConfigFile = "$gitkConfigDir\gitk"

  if (-not(Test-Path $gitkConfigDir)) {
    New-Item -ItemType Directory -Force -Path $gitkConfigDir
  }

  if (Test-Path $gitkConfigFile) {
    $CurDate = [DateTime]::Now.ToString("yyyyMMddTHHmmss")
    $gitkConfigBackupFile = "$gitkConfigDir\gitk_$CurDate.bak"
    write-host "copy `"$gitkConfigFile`" `"$gitkConfigBackupFile`""
    copy $gitkConfigFile $gitkConfigBackupFile

    $file = $gitkConfigFile
    (gc $file) -replace '^set extdifftool .*$', 'set extdifftool p4merge' -replace '^set diffcontext .*$', 'set diffcontext 6' | sc -Encoding ASCII $file

    if ((Get-FileHash $gitkConfigFile).hash -eq (Get-FileHash $gitkConfigBackupFile).hash) {
      del $gitkConfigBackupFile
    }
  }
  else {
    copy "$PSScriptRoot\support\gitk" $gitkConfigDir
  }
}

#GitConfigureLogAndColor
write-host ''
$install = Read-Host -Prompt "[Re]Configure git with useful log alias and updated colors (improves readability of some dull-colored defaults) ? [y/n]"
if ( $install -match "[yY]" ) {
  # Git Log and color settings
  git config --global alias.lg 'log --graph --pretty=format:''%C(red bold)%h%Creset -%C(yellow bold)%d%Creset %s%Cgreen(%cr) %C(cyan)<%an>%Creset'' --abbrev-commit --date=relative'
  git config --global alias.lg2 'log --graph --pretty=format:''%C(red bold)%h%Creset -%C(blue bold)%d%Creset %s%Cgreen(%cr) %C(cyan)<%an>%Creset'''
  git config --global alias.lg3 'log --graph --pretty=format:''%C(red bold)%h%Creset -%C(yellow bold)%d%Creset %s%C(cyan)<%an>%Creset'''
  git config --global color.branch.remote 'red bold'
  git config --global color.diff.new 'green bold'
  git config --global color.diff.old 'red bold'
  #status colors:
  #see https://github.com/git/git/blob/master/wt-status.h, https://github.com/git/git/blob/master/wt-status.c, https://github.com/git/git/blob/master/builtin/commit.c
  #WT_STATUS_UPDATED 'added' or 'updated'
  git config --global color.status.added 'green bold'
  #WT_STATUS_CHANGED
  git config --global color.status.changed 'red bold'
  #WT_STATUS_UNTRACKED
  git config --global color.status.untracked 'red bold'
  #WT_STATUS_NOBRANCH
  git config --global color.status.nobranch 'red bold'
  #WT_STATUS_UNMERGED
  git config --global color.status.unmerged 'red bold'
  #WT_STATUS_LOCAL_BRANCH
  git config --global color.status.localBranch 'green bold'
  #WT_STATUS_REMOTE_BRANCH
  git config --global color.status.remoteBranch 'red bold'

  $gitkConfigDir = "$env:USERPROFILE\.config\git"
  $gitkConfigFile = "$gitkConfigDir\gitk"

  if (-not(Test-Path $gitkConfigDir)) {
    New-Item -ItemType Directory -Force -Path $gitkConfigDir
  }

  if (Test-Path $gitkConfigFile) {
    $CurDate = [DateTime]::Now.ToString("yyyyMMddTHHmmss")
    $gitkConfigBackupFile = "$gitkConfigDir\gitk_$CurDate.bak"
    write-host "copy `"$gitkConfigFile`" `"$gitkConfigBackupFile`""
    copy $gitkConfigFile $gitkConfigBackupFile

    $file = $gitkConfigFile
    (gc $file) -replace '^set permviews {}$', 'set permviews {{{First Parent} {} --first-parent {}}}' | sc -Encoding ASCII $file

    if ((Get-FileHash $gitkConfigFile).hash -eq (Get-FileHash $gitkConfigBackupFile).hash) {
      del $gitkConfigBackupFile
    }
  }
  else {
    copy "$PSScriptRoot\support\gitk" $gitkConfigDir
  }
}

# skip certs/schannel/unconfigured items
<#
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
git config --global http.sslcainfo "C:/Program Files/Git/mingw64/ssl/certs/ca-bundle-plusWinRoot.crt"

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
#>

#GitPad - not necessary anymore?
<#
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
git config --global core.editor gitpad

goto Posh-Git
#>

#NotepadAsEditor
write-host ''
$install = Read-Host -Prompt "Configure Notepad as the git editor ? [y/n]"
if ( $install -match "[yY]" ) {
  git config --global core.editor notepad
}

# todo:
# notepad++ (git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin")

#Posh-Git
$installedVer = (Get-InstalledModule posh-git -erroraction silentlycontinue).Version
$availableVer = (Find-Module posh-git).Version

$chocoPoshGitInstalled = ($null -ne (choco list -lo | ? { $_ -match '^poshgit\b' }))

if ($chocoPoshGitInstalled) {
  write-host ''
  $install = Read-Host -Prompt "Uninstall chocolatey version of posh-git ? [y/n]"
  if ( $install -match "[yY]" ) {
    choco Uninstall -y  posh-git
  }
}

if (($null -eq $installedVer) -or ($installedVer -lt $availableVer)) {
  write-host ''
  $install = Read-Host -Prompt "Install/update posh-git ? [y/n]"
  if ( $install -match "[yY]" ) {
    if ($null -eq $installedVer) {
      Install-Module posh-git -Scope CurrentUser -Repository PSGallery -Confirm:$False -Force
    }
    elseif ($installedVer -lt $availableVer) {
      Update-Module posh-git -Scope CurrentUser -Repository PSGallery -Confirm:$False -Force
    }
  }
}

# if (get-service 'ssh-agent'-ErrorAction SilentlyContinue){
#   $svc = get-service 'ssh-agent'
#   if ($svc.StartType -eq 'Disabled') {
#     Set-Service ssh-agent -StartupType Manual
#   }
#   git config --global core.sshcommand "C:/Windows/System32/OpenSSH/ssh.exe"
# }

#Posh-GitConfigure
$poshgitConfigFile = 'C:\bin\PoshGitInit.ps1'
if (-not(Test-Path $poshgitConfigFile)) {
  New-Item -ItemType Directory -Force -Path 'C:\bin'
  'Import-Module posh-git' | sc $poshgitConfigFile
}

#append line to file if line not found
function Add-MissingLine($file, $line) {
  If (-not (sls -Path $file -SimpleMatch $line -Quiet)) {
    Add-Content $file $line
  }
}

write-host ''
$install = Read-Host -Prompt "[Re]Configure Posh-Git colors (improves readability of some dull-colored defaults) ? [y/n]"
if ( $install -match "[yY]" ) {
  Add-MissingLine $poshgitConfigFile '$GitPromptSettings.LocalDefaultStatusSymbol.ForegroundColor = [ConsoleColor]::Red'
  Add-MissingLine $poshgitConfigFile '$GitPromptSettings.WorkingColor.ForegroundColor = [ConsoleColor]::Red' 'WorkingColor.ForegroundColor'
  #Add-MissingLine $poshgitConfigFile '$env:LC_ALL=''C.UTF-8'''
}

#Shortcut
write-host ''
$install = Read-Host -Prompt "[Re]Create Posh-Git shell shortcut on desktop (select y if poshgit was upgraded)? [y/n]"
if ( $install -match "[yY]" ) {
  if (-not(Test-Path $CONF_POSHGIT_STARTDIR)) {
    New-Item -ItemType Directory -Force -Path $CONF_POSHGIT_STARTDIR
  }

  $shortcutFile = "$Home\Desktop\PoshGitShell.lnk"
  createShortcut $shortcutFile `
    '%WINDIR%\System32\WindowsPowershell\v1.0\Powershell.exe' `
    "-NoExit -ExecutionPolicy Unrestricted -File ""$poshgitConfigFile""" `
    "$PSScriptRoot\images\poshgit.ico" `
    $CONF_POSHGIT_STARTDIR

    & "$PSScriptRoot\support\pscolor.ps1" $shortcutFile

    copy $shortcutFile "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch"

    # todo admin poshgitshell
}

# todo: add this:
# {
#     // posh-git.
#     "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44be}",
#     "name": "PoshGitShell",
#     "commandline": "powershell.exe -NoExit -ExecutionPolicy Unrestricted -File \"C:\\Tools\\poshgit\\dahlbyk-posh-git-9bda399\\profile.example.ps1\" choco",
#     "hidden": false,
#     "icon" : "C:\\github-personal\\DevEnvInit\\images\\poshgit.ico",
#     "startingDirectory" : "C:\\github-personal",
#     "colorScheme": "Campbell Powershell"
# },
# to %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
# while retaining comments (and whitespace?)
