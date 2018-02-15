<#PSScriptInfo
.VERSION 1.0.0
.GUID 1dc44777-04ac-45f9-9a75-5b1b6f07fc97
.AUTHOR Arjun Bahree
.COMPANYNAME
.COPYRIGHT (c) 2018 Arjun Bahree. All rights reserved.
.TAGS Windows PowerShell DiskPartition OSDisk
.LICENSEURI https://github.com/bahreex/Bahree-PowerShell-Library/blob/master/LICENSE
.PROJECTURI https://github.com/bahreex/Bahree-PowerShell-Library/tree/master/General
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.DESCRIPTION
 Lets you Initialize new RAW data disks on any Windows based Machine.
#>

<#
.SYNOPSIS
    Lets you Initialize new RAW data disks on any Windows based Machine.

.DESCRIPTION
    This script lets you Initialize all new additional RAW data disks attached to your system in one go. It has default
    values for the Partition Style, FileSystem, and Disk Labels Prefix for all the new disks attached, but which can be
    changed by passing appropriate parameters when Invoking the script.

.EXAMPLE
    .\Initialize-WinNewDataDisk.ps1

.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 04/Feb/2018
    Last Revision Date: 04/Feb/2018
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

[CmdletBinding()]
param (
    [string]$PartitionStyle = "MBR",
    [string]$FileSystem = "NTFS",
    [string]$LabelPrefix = "Data"
    )

# Get list of all the RAW disks in the systme, which are to be Initialized
$disks = Get-Disk | Where-Object PartitionStyle -eq 'raw' | Sort-Object Number

# Create an array of all possible single CHAR Drive Letters in WIndows, from C to Z (CHAR values 67 to 90)
$masterLetters = 67..90 | ForEach-Object { [char]$_ }

# Counter for Data Disk Labels
$count = 0

# Iterate through all the RAW Disks in the system
foreach ($disk in $disks) {

    # Get latest list of Drive Letters assigned to existing already Initialized drives in the system. This is called
    # with every run of the loop for iterating through RAW disks because each time a new drive letter will be
    # assigned to the newly initialized disk, and we will have to exclude that newly assigned drive letter in our next
    # run
    $assignedDriveLetters = Get-Disk | Get-Partition | Where-Object {$_.DriveLetter} | Select-Object DriveLetter `
    | Sort-Object DriveLetter

    # Iterate through all the possible drive letter values from C to Z
    foreach($driveLetter in $masterLetters)
    {
        # If the current drive letter is already assigned to a partition in a disk, skip and continue
        if ($driveLetter.ToString() -in $assignedDriveLetters.DriveLetter)
        {
            continue
        }
        # If the current drive letter is free and not assigned already to another partition in a disk,
        # select the value and break out
        else{
            $selectedDriveLetter = $driveLetter.ToString()
            break
        }
    }
    # Dynamically create a string label for the new disk being initialized
    $finalLabel = $LabelPrefix + $count

    # Initialize and format the new disk
    $disk | Initialize-Disk -PartitionStyle $PartitionStyle -PassThru | New-Partition -UseMaximumSize `
    -DriveLetter $selectedDriveLetter | Format-Volume -FileSystem $FileSystem -NewFileSystemLabel $finalLabel `
    -Confirm:$false -Force

    # Increment the Label count
    $count++
}