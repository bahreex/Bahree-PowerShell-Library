<#
.SYNOPSIS 
    Gets you the current Provisioning State of an Azure RM VM.

.DESCRIPTION
    This script returns to you current Provisioning State of an Azure RM VM.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM

.PARAMETER VMName    
    Name of the VM whose Provisioning State you want to retrieve

.EXAMPLE
    Get-AzureRMVMProvisioningState.ps1 -ResourceGroupName "RG1" -VMName "VM01"
    
.Notes

Possible VM Provisioning State Values (Model View):

- Creating	:Indicates the virtual Machine is being created.
- Updating	:Indicates that there is an update operation in progress on the Virtual Machine.
- Succeeded	:Indicates that the operation executed on the virtual machine succeeded.
- Deleting	:Indicates that the virtual machine is being deleted.
- Failed	:Indicates that the update operation on the Virtual Machine failed.


Author: Arjun Bahree
E-mail: arjun.bahree@gmail.com
Creation Date: 26/Dec/2017
Last Revision Date: 26/Dec/2017
Version: 1.0
Development Environment: VS Code IDE
PS Version: 5.1
Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName
)

if (!(Get-AzureRmContext).Account){
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Get the VM in context
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    # Get current status of the VM
    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

    # Extract current Provisioning State of the VM
    $provState = $vmstatus.Statuses[0].Code.Split('/')[1]

    # Return the Provisioning State
    return $provState.ToUpper()

}
else {
    Write-Error "Cannot find VM'"
    return 
}