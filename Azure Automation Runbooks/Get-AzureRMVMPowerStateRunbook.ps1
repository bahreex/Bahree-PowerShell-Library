<#
.SYNOPSIS 
    Gets you the current Power State of an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook returns to you the current Power State of an Azure RM VM. You need to execute this Runbook through a 
    'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM

.PARAMETER VMName    
    Name of the VM whose Power State you want to retrieve

.EXAMPLE
    .\Get-AzureRMVMPowerStateRB.ps1 -ResourceGroupName "RG1" -VMName "VM01"
    
.Notes

Possible VM Power State Values (Instance View):

Starting     :Indicates the virtual machine is being started from the Hypervisor standpoint.
Running      :Indicates that the virtual machine is being started from the Hypervisor standpoint.
Stopping     :Indicates that the virtual machine is being stopped from the Hypervisor standpoint.
Stopped      :Indicates that the virtual machine is stopped from the Hypervisor standpoint. Note that virtual machines in the stopped state still incur compute charges.
Deallocating :Indicates that the virtual machine is being deallocated from the Hypervisor standpoint.
Deallocated  :Indicates that the virtual machine is removed from the Hypervisor standpoint but still available in the control plane. Virtual machines in the Deallocated state do not incur compute charges.
--           :Indicates that the power state of the virtual machine is unknown.


Author: Arjun Bahree
E-mail: arjun.bahree@gmail.com
Creation Date: 10/Jan/2018
Last Revision Date: 10/Jan/2018
Version: 1.0
Development Environment: Azure Automation Runbook Editor and VS Code IDE
PS Version: 5.1
Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName
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

# Get the VM in context
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    # Get current status of the VM
    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

    # Extract current Power State of the VM
    $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]

    # Return the Power State
    return $powerState.ToUpper()
}
else {
    Write-Error "Cannot find VM'"
    return 
}