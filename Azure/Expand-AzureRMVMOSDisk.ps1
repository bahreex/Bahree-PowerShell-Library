<#
.SYNOPSIS 
    Lets you upgrade the OS Disk Size for a VM.

.DESCRIPTION
    This script lets you upgrade the OS Disk size for a VM. It supports OS Disk resizing for both Managed and Unmanaged disks.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM, whose OS Disk you want to resize

.PARAMETER VMName    
    Name of the VM whose OS Disk you want to resize

.PARAMETER NewOSDiskSize    
    New Size of OS Disk

.EXAMPLE
    Expand-AzureRMVMOSDisk -ResourceGroupName "RG1" -VMName "VM01" -NewOSDiskSize 1023 
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 23/Dec/2017
    Last Revision Date: 23/Dec/2017
    Version: 1.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName,

    [Parameter(Mandatory=$true)]
    [int]$NewOSDiskSize
)

if (!(Get-AzureRmContext).Account){
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Get the VM in context
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    # Get current status of the VM in context for the Input State
    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

    If ($vmstatus.Statuses.Code -notcontains "PowerState/deallocated")
    {
        Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
    }

    # Check if VM has a managed disk or unmanaged disk
    # If VM has Unamanged Disk 
    if (!$vm.StorageProfile.OsDisk.ManagedDisk)
    {   
        # Change the OS Disk Size 
        $vm.StorageProfile.OSDisk.DiskSizeGB = $NewOSDiskSize

        # Update the VM to apply OS Disk change
        $resizeOps = Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $vm
    }
    else 
    {    
        # Get OS Disk for the VM in context
        $vmDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $vm.StorageProfile.OSDisk.Name
        
        # Change the OS Disk Size
        $vmDisk.DiskSizeGB = $NewOSDiskSize
        
        # Update the Disk
        $resizeOps = Update-AzureRmDisk -ResourceGroupName $ResourceGroupName -Disk $vmDisk -DiskName $vmDisk.Name
    }

    # Get current status of the VM in context for the Input State
    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

    If ($vmstatus.Statuses.Code -contains "PowerState/deallocated")
    {
        Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
    }
}
else {
    Write-Error "Cannot find VM'"
    return 
}