# Bahree-PowerShell-Library

_**Library of various PowerShell scripts/modules created for automating different tasks across Cloud, On-Premises, and Devices**_

## Azure

- **Expand-AzureRMVMOSDisk.ps1** - Increase the OS Disk size of an Azure RM VM. Supports both Managed and Unmanaged Disks. Disk size reduction not supported by Azure.
- **Expand-AzureRMVMDataDisk.ps1** - Increase a particular Data Disk size of an Azure RM VM. Supports both Managed and Unmanaged Disks. Disk size reduction not supported by Azure.
- **Get-AzureRMVMPowerState.ps1** - Get the current Power State of an Azure RM VM.
- **Get-AzureRMVMProvisioningState.ps1** - Get the current Provisioning State of an Azure RM VM.
- **Scale-AzureRMVMUp.ps1** - Lets you scale-up any VM by resizing it to a new size within the same VM family.
- **Scale-AzureRMVMDown.ps1** - Lets you scale-down any VM by resizing it to a new size within the same VM family.
- **Start-AzureRMVMAll.ps1** - Asynchronously starts all Azure RM VMs in a Subscription or in one or more Resource Groups, or a specific VM
- **Stop-AzureRMVMAll.ps1** - Asynchronously stops all Azure RM VMs in a Subscription, or in one or more Resource Groups, or a specific VM
- **Extend-AADAccessTokenLifetime.ps1** - Lets you change the default lifetime of the Azure AD Access Token
- **Nuke-AllAzureRMResources.ps1** - Lets you asynchronously destroy/nuke all Azure RM resources in an Azure Subscription.

## Azure Automation Runbooks

- **Start-AzureRMVMAllRunbook.ps1** - Asynchronously starts all Azure RM VMs in a Subscription or in one or more Resource Groups, or a specific VM from within an Azure Automation account
- **Stop-AzureRMVMAllRunbook.ps1** - Asynchronously stops all Azure RM VMs in a Subscription, or in one or more Resource Groups, or a specific VM from within an Azure Automation account
- **Expand-AzureRMVMOSDiskRunbook.ps1** - Increase the OS Disk size of an Azure RM VM. Supports both Managed and Unmanaged Disks. Disk size reduction not supported by Azure.
- **Expand-AzureRMVMDataDiskRunbook.ps1** - Increase a particular Data Disk size of an Azure RM VM. Supports both Managed and Unmanaged Disks. Disk size reduction not supported by Azure.
- **Get-AzureRMVMPowerStateRunbook.ps1** - Get the current Power State of an Azure RM VM.
- **Get-AzureRMVMProvisioningStateRunbook.ps1** - Get the current Provisioning State of an Azure RM VM.
- **Execute-AzureRMVMRemoteScriptRunbook.ps1** - Enables remote execution of PowerShell Commands/Scripts on one or more target Azure VMs (or On-Premises VMs through Hybrid Worker) in an Azure Subscription.

## General

- **Extend-WinOSDiskSize.ps1** - Extend/Increase the OS Drive Partition size for any Windows based Machine by adding the entire unallocated space available on the OS Disk, if any. One use case for this script is to automate completion of the OS disk expansion in an Azure RM VM, after the OS Disk size has been increased from the outside of VM using PS Azure cmdlets or Azure REST APIs or Azure Portal (For e.g through _Expand-AzureRMVMOSDisk.ps1_ script).
- **Initialize-WinNewDataDisk.ps1** - Lets you Initialize new RAW data disks on any Windows based Machine. This will be particularly useful after creating and attaching new empty data disks to an Azure VM
- **FixSpectre-DSCConfiguration.ps1** - Fixes the Spectre CPU Vulnerability on your Windows Machines through DSC Configuration for Registry changes recommended by Microsoft