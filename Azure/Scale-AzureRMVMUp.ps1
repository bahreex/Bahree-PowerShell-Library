<#
.SYNOPSIS 
    Lets you Scale Up any Azure RM VM from its current size to a new size within the same Family.

.DESCRIPTION
    This script lets you Scale Up any Azure RM VM from its current Size to a new size that you specify. By default the 
    new size to scale is Immediately after the current size in the Size Table published by Microsoft, which means the 
    SizeStep parameter with value 1. However, if you specify another value for SizeStep parameter, which should be
    greater than your current VM size number in the Size Table, your VM will be scaled up to that Size in the Size table
    corresponding to that number. If your VM is already at the last size of the VM family, you will not be able to scale
    up the VM any further as cross-family resizing is not allowed by Microsoft Azure. Since Microsoft does not make the 
    VM Size Table available in a format that cna be consumed programmatically for reference, I have manually created the
    same and publicly shared through a Gist in my Github repository. The URL for the Gist is embedded in the Script 
    code, which I will regularly update as and when Microsoft updates the VM Size table. You can find the most current 
    VM Size table at the Gist URL (https://gist.github.com/bahreex/96a611b5ca05de2df2c3d7f45b11b75d) and within this 
    repository as a CSV file named "Azure-VM-Sizes-29122017.csv". You need to be already logged into your Azure account 
    through PowerShell before calling this script.

.Parameter ResourceGroupName
    Name of the Resource Group where the target VM is located

.Parameter VMName
    Name of the target VM

.Parameter SizeStep
    Scalar value between 1 to 8. This has a default value of 1, which will upgrade the VM to Immediately next size 
    within same VM family within the Size Table. The value you specify in this parameter, which should be greater than 
    your current VM size number in the Size Table, will be used to scale up your VM to that Size in the Size table 
    corresponding to the specified number.

.EXAMPLE
    .\Scale-AzureRMVMUp.ps1 -ResourceGroupName rg-100 -VMName vm100 -SizeStep 2

.EXAMPLE
    .\Scale-AzureRMVMDown.ps1 -ResourceGroupName rg-100 -VMName vm100
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 29/Dec/2017
    Last Revision Date: 12/Jan/2018
    Version: 2.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

[CmdletBinding()]
param
(

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 8)]
    [int]$SizeStep = 1

)

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}
 
# Create Stopwatch and Start the Timer
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()
 
function ResizeVM ($rgName, $vmName, $newVMSize) {

    Write-Verbose "Scaling-Up $vmName to $newVMSize ... this will require a Reboot!"

    $vmRef = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName
    
    $vmRef.HardwareProfile.VmSize = $newVMSize
    
    $Job = Update-AzureRmVM -VM $vmRef -ResourceGroupName $rgName -AsJob

    Get-Job | Wait-Job | Receive-Job > $null
}

Write-Verbose "Starting the VM Scaling-Up Process."

$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue

If ($VM) {

    $vSize = $VM.HardwareProfile.VmSize

    $vmSizeURL = "https://gist.githubusercontent.com/bahreex/96a611b5ca05de2df2c3d7f45b11b75d/raw/bf2065fd27171d616b6c2373d58a387a82dff114/Azure-VM-Sizes-29122017.csv"

    $content = (Invoke-WebRequest -Uri $vmSizeURL -UseBasicParsing).Content

    $vmSizes = $content.Split("`r`n")

    $vmFamilyList = @()

    foreach ($line in $vmSizes) {
        $row = $line.split(',');

        if ($row -contains $vSize) {
            $index = $row.IndexOf($vSize)

            $count = 0

            foreach ($subLine in $vmSizes) {
                $subRow = $subLine.split(',');

                if ($count -eq 0) {
                    $vmFamily = $subRow[$index]
                }
                else {
                    if ($subRow[$index]) {
                        $vmFamilyList += $subRow[$index]
                    }
                }            
                $count++
            }
            break 
        }
    }

    $nextSizeIndex = $vmFamilyList.IndexOf($vSize) + $SizeStep

    if (!$vmFamilyList[$nextSizeIndex]) {
        
        # Stop the Timer
        $StopWatch.Stop()

        Write-Verbose "The VM $($VM.Name) is at the maximum allowed size for the $vmFamily family."
    }
    else {
        
        ResizeVM $ResourceGroupName $VMName $vmFamilyList[$nextSizeIndex]

        Write-Verbose "The Scaling-Up for VM $($VM.Name) has been completed!"

        # Stop the Timer
        $StopWatch.Stop()

        # Display the Elapsed Time
        Write-Verbose "Total Execution Time for Scaling Up the VM: $($StopWatch.Elapsed.ToString())"
    }
}
else {

    # Stop the Timer
    $StopWatch.Stop()

    Write-Verbose "Could not get the VM {$VMName} in the Resource Group {$ResourceGroupName}."
}


 
