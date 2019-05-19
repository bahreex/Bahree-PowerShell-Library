<#
.SYNOPSIS
    Lets you Search for all pending updates on a Windows OS Machine, and download/Install them

.DESCRIPTION
	This Script lets you Search for all pending updates from the Windows Update Service for the localWindows OS based
	Machine (VM or Physical), and download/Install them locally sequentially. it will restart the machine as and when
	required for Updates to be applied

.EXAMPLE
	Start-Process powershell -ArgumentList '-noprofile -file Update-PatchWinOS.ps1 >> C:\UpdatePatching.log' -verb RunAs

.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 7/Mar/2018
    Last Revision Date: 7/Mar/2018
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

#Initialize global variables
$INSTALLFAILED = $false
$REBOOTREQUIRED = $false

#Initialize objects that are needed for the script
$Searcher = New-Object -ComObject Microsoft.Update.Searcher
$Session = New-Object -ComObject Microsoft.Update.Session
$Installer = New-Object -ComObject Microsoft.Update.Installer
$Downloader = $Session.CreateUpdateDownloader()
$UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

#This set the criteria used for searching for new updates
$Criteria = "IsInstalled=0 and Type='Software'"

#This searches for new needed updates and stores them as a list in $SearchResult
Write-Output "Searching for updates. Please wait..."
$SearchResult = $Searcher.Search($Criteria).Updates

#This gets the number of updates that are currently needed by the given server
$NumberOfUpdates = $SearchResult.Count

#If $NumberOfUpdates is zero then there are no needed updates so we just exit
#Otherwise inform the user of how many updates are required then proceed
if ($NumberOfUpdates -gt 0) {
    Write-Output "There are $($SearchResult.Count) updates to install"
    Write-Output
}
else {
    Write-Output "There are no updates to install"
    Exit
}

Write-Output
Write-Output "-----------------------------------------------------------------------------------------"

#This steps through each of the discovered updates and downloads them one at a time
#These are done individually to provide more feedback on the overall progress of the script
ForEach ($Update in $SearchResult) {

    #This adds the current Update to the collection and sends the return value to null to mask bogus output
    $null = $UpdatesToDownload.Add($Update)

    #This creates a temporary download task
    $Downloader.Updates = $UpdatesToDownload

    #Update the end user with which patch is being downloaded
    $DownloadSize = "{0:N1}" -f ((($Downloader.Updates.Item(0).MaxDownloadSize) / 1024) / 1000)
    Write-Output "Downloading ->"$Downloader.Updates.Item(0).Title"  ---Please wait..."
    Write-Output "Estimated Size: "$DownloadSize"MB"

    #This checks to see if the current update has already been downloaded at some point
    #If it already exists then the download is skipped. Otherwise it starts the download
    if ($Downloader.Updates.Item(0).IsDownloaded) {
        Write-Output "Update has already been downloaded -> Skipped"
    }
    else {
        #Process the actual download
        $null = $Downloader.Download()
    }

    #This verifies that the update was successfully downloaded. If not it alerts the user and aborts the script
    if (-not ($Downloader.Updates.Item(0).IsDownloaded)) {
        Write-Output "Download failed for unknown reason. Script abort."
        Exit
    }

    #This clears the update collection to prepare for the next update
    $UpdatesToDownload.Clear()
    Write-Output
}

Write-Output "All updates have been downloaded. Proceeding with installation steps..."
Write-Output
Write-Output "-----------------------------------------------------------------------------------------"

#This steps through each of the downloaded updates and installs them one at a time
#These are done individually to provide more feedback on the overall progress of the script
ForEach ($Update in $SearchResult) {
    #This adds the current Update to the collection and sends the return value to null to mask bogus output
    $null = $UpdatesToInstall.Add($Update)

    #This creates a temporary install task
    $Installer.Updates = $UpdatesToInstall

    #Update the end user with which patch is being installed
    Write-Output "Installing ->"$Installer.Updates.Item(0).Title"  ---Please wait..."

    #This checks to see if the current update has already been installed at some point
    #If it is already installed then the install is skipped. Otherwise it starts the install
    if ($Installer.Updates.Item(0).IsInstalled) {
        Write-Output "Update has already been installed -> Skipped"
    }
    else {
        #Process the actual install
        $result = $Installer.Install()
    }

    #This verifies that the update was successfully installed. If not it alerts the user then continues with the next update
    if (-not ($result.ResultCode -eq 2)) {
        Write-Output "WARNING!!! - Installation failed for unknown reason. Continuing to next update."
        $INSTALLFAILED = $true
    }

    #This clears the update collection to prepare for the next update
    $UpdatesToInstall.Clear()
    Write-Output

    #This checks to see if the current update requires a reboot
    if ($result.rebootRequired) {
        Write-Output "INFO!!! - Installation requires reboot."
        $REBOOTREQUIRED = $true
    }
}

Write-Output
Write-Output
Write-Output "-----------------------------------------------------------------------------------------"
Write-Output "Update Results:"
Write-Output

#Alert the user about installation success
if ($INSTALLFAILED) {
    Write-Output "WARNING!!! - At least one update failed to install."
}
else {
    Write-Output "All updates have been installed."
}

#Alert the user if reboot is required
if ($REBOOTREQUIRED) {
    Write-Output "INFO!!! - At least one update requires a reboot. Rebooting now."
    Restart-Computer
}
else {
    Write-Output "Script Finished"
}

Exit