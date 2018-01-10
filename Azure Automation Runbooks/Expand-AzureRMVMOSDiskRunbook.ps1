<#
.SYNOPSIS 
    Lets you Increase the OS Disk Size for an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook lets you Increase the OS Disk size for a VM. OS Disk Size reduction is not supported by Azure. It 
    supports OS Disk resizing for both Managed and Unmanaged disks. You need to execute this Runbook through a 
    'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM, whose OS Disk you want to resize

.PARAMETER VMName    
    Name of the VM whose OS Disk you want to resize

.PARAMETER NewOSDiskSize    
    New Size of OS Disk

.EXAMPLE
    .\Expand-AzureRMVMOSDisk -ResourceGroupName "RG1" -VMName "VM01" -NewOSDiskSize 1023 
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 23/Dec/2017
    Last Revision Date: 26/Dec/2017
    Version: 1.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>
[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName,

    [Parameter(Mandatory=$true)]
    [ValidateRange(30,2048)]
    [int]$NewOSDiskSize
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    $account = Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Write-Verbose "Getting VM reference..."
# Get the VM in context
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    if ($vm.StorageProfile.OSDisk.DiskSizeGB -ge $NewOSDiskSize)
    {
        Write-Error "The new OS Disk size should be greater than existing OS Disk size. Disk size reduction or same Disk size allocation not supported."
        return
    }

    Write-Verbose "Checking if the VM has a Managed disk or Unmanaged disk..."
    # If VM has Unamanged Disk 
    if (!$vm.StorageProfile.OsDisk.ManagedDisk)
    {   
        Write-Verbose "The VM has Unmanaged OS Disk."

        Write-Verbose "Getting VM Status..."
        # Get current status of the VM
        $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    
        Write-Verbose "Checking if VM is in a Running State..."
        If ($vmstatus.Statuses.Code -contains "PowerState/running")
        {
            Write-Verbose "Stopping the VM as it is in a Running State..."
            $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
        }

        Write-Verbose "Changing Unmanaged OS Disk Size..."
        
        # Change the OS Disk Size 
        $vm.StorageProfile.OSDisk.DiskSizeGB = $NewOSDiskSize

        # Update the VM to apply OS Disk change
        $resizeOps = Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $vm
    }
    else 
    {    
        Write-Verbose "The VM Has Managed OS Disk."

        Write-Verbose "Getting VM Status..."
        # Get current status of the VM
        $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    
        Write-Verbose "Checking if VM is in a Running State..."
        If ($vmstatus.Statuses.Code -contains "PowerState/running")
        {
            Write-Verbose "Stopping the VM as it is in a Running State..."
            $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
        }
        
        Write-Verbose "Changing Managed OS Disk Size..."

        # Get OS Disk for the VM in context
        $vmDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $vm.StorageProfile.OSDisk.Name
        
        # Change the OS Disk Size
        $vmDisk.DiskSizeGB = $NewOSDiskSize

        # Update the Disk
        $resizeOps = Update-AzureRmDisk -ResourceGroupName $ResourceGroupName -Disk $vmDisk -DiskName $vmDisk.Name
    }

    If ($stopVM)
    {
        Write-Verbose "Restart the VM as it was stopped from a Running State..."
        $startVMJob = Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -AsJob
    }

    Write-Verbose "OS Disk size change successful."

}
else {
    Write-Error "Cannot find VM'"
    return 
}