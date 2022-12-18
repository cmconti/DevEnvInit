#Check if console is Admin-elavated
function Test-AdminElevation {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
  return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}

#Set things up for PowerShellGet
function prepForPSModule {
    #validate per-user PSModulePath (it's not uncommon for installers to bork this value)
    $perUserPSModuleDefault="$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    if ($env:PSModulePath -notmatch [Regex]::Escape($perUserPSModuleDefault)) {
        $exists = Get-ItemProperty 'HKCU:\Environment' 'PSModulePath' -ErrorAction SilentlyContinue
        if (($exists -eq $null) -or ($exists.PSModulePath.Length -eq 0)) {
            Write-Host
            Write-Host "Warning: Per-User environment variable 'PSModulePath' not set.  Using synthesized value" -ForegroundColor Yellow
            $env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$perUserPSModuleDefault"
        }
    }

    #make sure Tls12 is enabled (using SystemDefault assumes .NET 4.7+ is installed)
    if (([Net.ServicePointManager]::SecurityProtocol -ne [Net.SecurityProtocolType]::SystemDefault) -and
        !([Net.SecurityProtocolType]::Tls12 -eq ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12))) {
        Write-Host
        Write-Host "Warning: Tls12 not enabled for powershell.  Attempting to enable." -ForegroundColor Yellow
        #set for this session
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        #try to persist for future
        try {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Value '1' -Type DWord
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord

            Write-Host "Enable Tls12 succeeded" -ForegroundColor Yellow
        }
        catch {
            Write-Host "Enabling Tls12 permanently failed.  You may experience other related errors later." -ForegroundColor Red
        }
    }

    #install/update NuGet provider if not already present
    if ((-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) -or
        ((Get-PackageProvider -Name NuGet).version -lt 2.8.5.201 )) {
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Confirm:$False -Force
        }
        catch {
            Write-Host "$_" -ForegroundColor Red
            exit 1
        }
    }
}

#-- Change Notification
function notifySettingsChanged {
    if (-not ("Win32.NativeMethods" -as [Type])) {
        Add-Type @"
using System;using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
namespace Win32
{
    public class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam);

        [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern int SHChangeNotify(int eventId, int flags, UIntPtr item1, UIntPtr item2);
    }
}
"@
    }
    $HWND_BROADCAST = [IntPtr] 0xffff
    $WM_SETTINGCHANGE = 0x1a
    $SHCNE_ASSOCCHANGED = 0x8000000
    $SHCNF_FLUSH = 0x1000
    $result = [UIntPtr]::Zero
    [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref] $result) | Out-Null
    [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'intl', 2, 5000, [ref] $result) | Out-Null
    [Win32.Nativemethods]::SendNotifyMessage($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'TraySettings') | Out-Null
    [Win32.Nativemethods]::SHChangeNotify($SHCNE_ASSOCCHANGED, $SHCNF_FLUSH, [UIntPtr]::Zero, [UIntPtr]::Zero) | Out-Null
}

#-- Shortcut functions
function createShortcut ($shortcutfile, $targetExe, $arguments, $iconLocation, $workingDirectory, $description) {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutfile)
    $Shortcut.TargetPath = $targetExe
    if (![string]::IsNullOrWhiteSpace($arguments)){$Shortcut.Arguments = $arguments}
    if (![string]::IsNullOrWhiteSpace($iconLocation)){$Shortcut.IconLocation = $iconLocation}
    if (![string]::IsNullOrWhiteSpace($workingDirectory)){$Shortcut.WorkingDirectory = $workingDirectory}
    if (![string]::IsNullOrWhiteSpace($description)){$Shortcut.Description = $description}
    $Shortcut.Save()
}

function makeShortcutAdmin($shortcutfile) {
    # Make the Shortcut runas Administrator
    # Source: https://stackoverflow.com/questions/28997799/how-to-create-a-run-as-administrator-shortcut-using-powershell
    $bytes = [System.IO.File]::ReadAllBytes($shortcutfile)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($shortcutfile, $bytes)
}

#-- Json config files
function AddOrUpdateMember ($object, $propName, $propValue) {
    $object | Add-Member -NotePropertyName $propName -NotePropertyValue $propValue -ErrorAction "SilentlyContinue"

    $object.$propName = $propValue
}

function LoadOrInitJsonConfigFile([string]$configFile, [string]$defaultConfig) {
    $configDir =  Split-Path -Path $configFile
    if (-not (Test-Path "$configDir")) {
        mkdir "$configDir" | out-null
    }

    $config = $null
    $configCurrentContent = $defaultConfig
    if (Test-Path $configFile) {
        $configCurrentContent = (Get-Content -Raw -Path $configFile)
        #strip comments (https://stackoverflow.com/questions/51066978/convert-to-json-with-comments-from-powershell)
        $configCurrentContent = $configCurrentContent -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -replace '(?ms)/\*.*?\*/'
    }

    $config = ($configCurrentContent | ConvertFrom-Json)

    return $config
}

# https://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom
function RemoveUT8BOM([string]$file) {
    $data = Get-Content -Raw $file
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($file, $data, $Utf8NoBomEncoding)
}

function SaveJsonConfigFile([string]$configFile, $config) {
    if (Test-Path $configFile) {
        copy $configFile "$configFile.bak"
    }

    $config | ConvertTo-Json | Set-Content -Path $configFile -Encoding UTF8
    RemoveUT8BOM $configFile
}