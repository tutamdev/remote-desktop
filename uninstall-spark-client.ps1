# uninstall-spark-client.ps1
# Cleanly uninstall Spark Client
# - Stop client.exe if running
# - Remove scheduled task SparkClient
# - Delete folder C:\Program Files\Spark (includes run-client.vbs)
# - Remove Windows Defender exclusion

$DestDir = "C:\Program Files\Spark"
$TaskName = "SparkClient"

Write-Host ">>> Uninstalling Spark Client..."

# 1. Stop running client.exe
Write-Host ">>> Stopping client process (if any)..."
try {
    Get-Process -Name "client" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host ">>> Client process stopped."
} catch {
    Write-Warning ">>> Failed to stop client process. $_"
}

# 2. Remove scheduled task
Write-Host ">>> Removing scheduled task: $TaskName"
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host ">>> Scheduled task removed."
    } else {
        Write-Host ">>> Scheduled task not found."
    }
} catch {
    Write-Warning ">>> Failed to remove scheduled task. $_"
}

# 3. Delete Spark folder
Write-Host ">>> Deleting folder: $DestDir"
try {
    if (Test-Path $DestDir) {
        Remove-Item -Path $DestDir -Recurse -Force
        Write-Host ">>> Folder deleted."
    } else {
        Write-Host ">>> Folder not found."
    }
} catch {
    Write-Warning ">>> Failed to delete $DestDir (maybe file in use). $_"
}

# 4. Remove Defender exclusion
Write-Host ">>> Removing Defender exclusion: $DestDir"
try {
    $prefs = Get-MpPreference
    if ($prefs.ExclusionPath -contains $DestDir) {
        Remove-MpPreference -ExclusionPath $DestDir
        Write-Host ">>> Defender exclusion removed."
    } else {
        Write-Host ">>> No Defender exclusion found for: $DestDir"
    }
} catch {
    Write-Warning ">>> Failed to remove Defender exclusion. Run PowerShell as Administrator."
}

Write-Host ">>> Done. Spark Client has been fully uninstalled."
