function LogWrite {
   Param ([string]$logstring)
   $file = "C:\Windows\Temp\updates.log"
   $now = Get-Date -format s
   Add-Content $file -value "$now $logstring"
   Write-Host $logstring
}

$UpdatesListPath = "A:\windows-updates-list.csv"

$IgnoredUpdateCategories = "Feature Packs", "Update Rollups", "Silverlight"

$UpdateCategories = "Security Updates", "Critical Updates", "Windows Server 2012 R2", "Updates"

function Install-Updates {
    Param ([string[]]$updateList)

    # Loop until we successfully connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        try {
            if ($updateList.count -gt 0) {
               # Only install approved updates
               $updateResult = Get-WUInstall -MicrosoftUpdate -AutoReboot -AcceptAll -IgnoreUserInput -Debuger -KBArticleID $updateList 
            } else {
               $updateResult = Get-WUInstall -MicrosoftUpdate -AutoReboot -AcceptAll -IgnoreUserInput -Debuger -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories
            }
            return $updateResult
        } catch {
            if ($_ -match "HRESULT: 0x8024402C") {
                Write-Warning "Error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                Throw $_
                Exit 1
            }
        }
    }
    return $FALSE
}

function Update-Count {
    Param ([string[]]$updateList)

    # Loop until we successfully connect to the update server
    $sleepSeconds = 5
    $maxAttempts = 10
    for ($i = 0; $i -le $maxAttempts; $i++) {
        try {
            $count = 0
            if ($updateList.count -gt 0) {
               # Only check for approved updates
               $count = (Get-WUList -MicrosoftUpdate -IgnoreUserInput -KBArticleID $updateList | measure).Count
            } else {
               $count = (Get-WUList -MicrosoftUpdate -IgnoreUserInput -Category $UpdateCategories -NotCategory $IgnoredUpdateCategories | measure).Count
            }
            return $count
        } catch {
            if ($_ -match "HRESULT: 0x8024402C") {
                Write-Warning "Error connecting to update service, will retry in ${sleepSeconds} seconds..."
                Start-Sleep -Seconds $sleepSeconds
            } else {
                Throw $_
                Exit 1
            }
        }
    }
    return $FALSE
}

function GetUpdateKBIDs() {
    $content = Get-Content -Path $UpdatesListPath
    if ($content -Contains "ALL_AVAILABLE") {
        LogWrite "Installing all available Windows updates"
        return @()
    }

    LogWrite "Installing only the selected Windows updates specified in $UpdatesListPath"
    return (Import-Csv $UpdatesListPath).HotFixID
}

LogWrite "Checking for Windows updates"
try {
    Import-Module PSWindowsUpdate

    # Loop until there are no more updates
    $sleepSeconds = 5
    $maxAttempts = 10

    $updateList = GetUpdateKBIDs

    for ($i = 0; $i -le $maxAttempts; $i++) {
        LogWrite "Installing updates attempt #$i"
        Install-Updates($updateList)
        LogWrite "Finished updates attempt #$i"

        $count = Update-Count($updateList)
        if ($count -eq 0) {
            LogWrite "No more updates to install"
            Exit 0
        } else {
            LogWrite "There are $count updates to install, will retry in $sleepSeconds..."
            Start-Sleep -Seconds $sleepSeconds
        }
    }
} catch {
    LogWrite $_.Exception | Format-List -Force
    Exit 1
}
