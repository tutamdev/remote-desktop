# uninstall-spark-client.ps1
# Uninstall Spark Client from Windows

$DestDir = "C:\Program Files\Spark"
$TaskName = "SparkClient"

Write-Host ">>> Uninstalling Spark Client..."

# 1. Remove scheduled task
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host ">>> Removing scheduled task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host ">>> Scheduled task not found: $TaskName"
}

# 2. Remove folder
if (Test-Path -Path $DestDir) {
    Write-Host ">>> Deleting folder: $DestDir"
    Remove-Item -Path $DestDir -Recurse -Force
} else {
    Write-Host ">>> Folder not found: $DestDir"
}

# 3. Remove Defender exclusion
try {
    $prefs = Get-MpPreference
    if ($prefs.ExclusionPath -contains $DestDir) {
        Write-Host ">>> Removing Defender exclusion: $DestDir"
        Remove-MpPreference -ExclusionPath $DestDir
    } else {
        Write-Host ">>> No Defender exclusion found for: $DestDir"
    }
} catch {
    Write-Warning ">>> Failed to remove Defender exclusion (please run PowerShell as Administrator)."
}

Write-Host ">>> Done. Spark Client has been removed."
