param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$Path
)

$lnk = & ("$PSScriptRoot\Get-Link.ps1") $Path

# Set initial colors to same as Win10 Powershell prompt
$lnk.ConsoleColors[0]="#000000"
$lnk.ConsoleColors[1]="#000080"
$lnk.ConsoleColors[2]="#008000"
$lnk.ConsoleColors[3]="#008080"
$lnk.ConsoleColors[4]="#800000"
$lnk.ConsoleColors[5]="#012456"
$lnk.ConsoleColors[6]="#eeedf0"
$lnk.ConsoleColors[7]="#c0c0c0"
$lnk.ConsoleColors[8]="#808080"
$lnk.ConsoleColors[9]="#0000ff"
$lnk.ConsoleColors[10]="#00ff00"
$lnk.ConsoleColors[11]="#00ffff"
$lnk.ConsoleColors[12]="#ff0000"
$lnk.ConsoleColors[13]="#ff00ff"
$lnk.ConsoleColors[14]="#ffff00"
$lnk.ConsoleColors[15]="#ffffff"

$lnk.ScreenTextColor=0x6
$lnk.ScreenBackgroundColor=0x5
$lnk.PopUpTextColor=0x3
$lnk.PopUpBackgroundColor=0xf

$lnk.QuickEditMode = $true
$lnk.InsertMode = $true
$lnk.AutoPosition = $true
$lnk.CommandHistoryBufferSize = 50
$lnk.CommandHistoryBufferCount = 4

$lnk.SetScreenBufferSize(120,9000)
$lnk.SetWindowSize(120,50)

$lnk.CursorSize = 25

$lnk.SetFont("Consolas", 14, $false);

$lnk.Save()

Write-Host "Updated $Path to powershell default colors"