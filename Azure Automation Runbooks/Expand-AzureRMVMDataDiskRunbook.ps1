<#PSScriptInfo
.VERSION 1.1.0
.GUID 0cd49773-1cf8-480d-9b53-b3b28090ade5
.AUTHOR Arjun Bahree
.COMPANYNAME 
.COPYRIGHT (c) 2018 Arjun Bahree. All rights reserved.
.TAGS Windows PowerShell Azure AzureAutomation Runbooks AzureManagedDisk AzureUnmanagedDisk AzureDataDisk AzureStorage
.LICENSEURI https://github.com/bahreex/Bahree-PowerShell-Library/blob/master/LICENSE
.PROJECTURI https://github.com/bahreex/Bahree-PowerShell-Library/tree/master/Azure%20Automation%20Runbooks
.ICONURI 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 Lets you Increase the Data Disk Size for an Azure RM VM as a Runbook from within an Azure Automation Account.
#> 

<#
.SYNOPSIS 
    Lets you Increase the Data Disk Size for an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook lets you Increase the Data Disk size for a VM. Data Disk Size reduction is not supported by Azure. It 
    supports Data Disk resizing for both Managed and Unmanaged disks. You need to execute this Runbook through a 
    'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM, whose Data Disk you want to resize

.PARAMETER VMName    
    Name of the VM whose Data Disk you want to resize

.PARAMETER DataDiskName
    Name of the existing Data Disk attached tot he VM

.PARAMETER NewDataDiskSize    
    New Size of the Data Disk

.EXAMPLE
    .\Expand-AzureRMVMDataDisk -ResourceGroupName "RG1" -VMName "VM01" -DataDiskName "disk1234" -NewDataDiskSize 1023 
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 27/Dec/2017
    Last Revision Date: 15/Jan/2018
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName,

    [Parameter(Mandatory=$true)] 
    [String]$DataDiskName,

    [Parameter(Mandatory=$true)]
    [ValidateRange(30,4095)]
    [int]$NewDataDiskSize
)

if (!(Get-AzureRmContext).Account) {
    $connectionName = "AzureRunAsConnection"
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
    
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint > $null
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}

Write-Output "Getting VM reference..."
# Get the VM in context
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    Write-Output "Checking if VM has any Data Disks attached"
    if ($vm.StorageProfile.DataDisks)
    {
        foreach ($ddisk in $vm.StorageProfile.DataDisks)
        {
            Write-Output "Checking if VM has a Data Disk with specified name"
            if ($ddisk.Name -eq $DataDiskName)
            {
                Write-Output "Check if it is a managed data disk or unmanaged data disk..."                
                # If VM has Unamanged Disk 
                if (!$ddisk.ManagedDisk)
                {   
                    Write-Output "The VM has Unamanaged Data Disk."

                    if ($ddisk.DiskSizeGB -ge $NewDataDiskSize)
                    {
                        Write-Error "The new Data Disk size should be greater than existing Data Disk size. Disk size reduction or same Disk size allocation not supported."
                        return
                    }

                    Write-Output "Getting VM Status..."
                    # Get current status of the VM
                    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                    Write-Output "Check if VM is in a Running State..."
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Output "Stopping the VM as it is in a Running State..."
                        $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
                    }

                    Write-Output "Changing Unmanaged Data Disk Size..."
                    
                    # Change the Data Disk Size 
                    $ddisk.DiskSizeGB = $NewDataDiskSize

                    # Update the VM to apply Data Disk change
                    $resizeOps = Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $vm
                }
                else 
                {    
                    Write-Output "The VM has Managed Data Disk."

                    if ($ddisk.DiskSizeGB -eq $NewDataDiskSize)
                    {
                        Write-Error "The VM Data Disk is already at the size specified"
                        return
                    }

                    Write-Output "Getting VM Status..."
                    # Get current status of the VM
                    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                    Write-Output "Check if VM is in a Running State..."
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Output "Stopping the VM as it is in a Running State..."
                        $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force 
                    }
                    
                    Write-Output "Changing Managed Data Disk Size..."

                    # Get Data Disk for the VM in context
                    $vmDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $ddisk.Name
                    
                    # Change the Data Disk Size
                    $vmDisk.DiskSizeGB = $NewDataDiskSize

                    # Update the Disk
                    $resizeOps = Update-AzureRmDisk -ResourceGroupName $ResourceGroupName -Disk $vmDisk -DiskName $ddisk.Name
                }

                If ($stopVM)
                {
                    Write-Output "Restart the VM as it was stopped from a Running State..."
                    $startVMJob = Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -AsJob
                }

                Write-Output "Data Disk size change successful. Please restart the VM."
            }
        }
    }
    else {
        Write-Error "Cannot find any Data Disks attached to the VM"
        return
    }

}
else {
    Write-Error "Cannot find specified VM"
    return 
}
