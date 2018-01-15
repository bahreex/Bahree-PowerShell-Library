
<#PSScriptInfo
.VERSION 1.0.0
.GUID f886e06d-323d-4eb1-a3ca-bd9e66524ec9
.AUTHOR Arjun Bahree
.COMPANYNAME 
.COPYRIGHT (c) 2018 Arjun Bahree. All rights reserved.
.TAGS Windows PowerShell Azure AzureAutomation Runbooks AzureVM
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
Asynchronously Starts all or specific Azure RM VMs in an Azure Subscription as a Runbook from within an Azure 
Automation Account
#> 

<#
.SYNOPSIS 
    Asynchronously Starts all or specific Azure RM VMs in an Azure Subscription as a Runbook from within an Azure 
    Automation Account

.DESCRIPTION
    This Runbook asynchronously Starts either all Azure RM VMs in an Azure Subscription, or all Azure RM VMs in one or 
    more specified Resource Groups, or one or more VMs in a specific Resource Group, or any number of Random VMs in a 
    Subscription. You can specify one or more Resource Groups to exclude, wherein all VMs in those Resource Groups will 
    not be started. You can specify one or more VMs to exclude, wherein all those VMs will not be started. The choice 
    around which VMs to start depends on the combination and values of the parameters provided. You need to execute this
    Runbook through a 'Azure Run As account (service principal)' Identity from an Azure 
    Automation account.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to Start. Specifying just the Resource Group without 
    the "VMName" parameter will consider all VMs in that specified Resource Group. You can specify an array of 
    Resource Group names without "VMname" parameter, and all VMs withihn the specified Resource Groups in the array will
    be started. You can specify just a single Resource Group Name in this parameter, along with one or more VM names in 
    the "VMName" parameter, wherein all the VMs specified will be started in that specific Resource Group. You cannot
    specify more than one Resource Group Names when combined with the "VMName" parameter.

.PARAMETER VMName    
    Name of the VM you want to Start. This parameter when specified alone, without the "ResourceGroupName" 
    parameter, can Include one or more VM Names to be started across any resource groups in the Azure Subscription. When
    specified with the "ResourceGroupName" parameter, you need to Include one or more VMs in the specified Resource
    Group only.

.PARAMETER ExcludedResourceGroupName
    Name of the Resource Group(s) containing the VMs you want excluded from being Started. It cannot be combined with 
    "ResourceGroupName" and "VMName" parameters.

.PARAMETER ExcludedVMName    
    Name of the VM(s) you want excluded from being Started. It cannot be combined with "VMName" parameter.


.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1,RG2,RG3
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1 -VMName VM01
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1 -VMName VM01,VM02,VM05
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -VMName VM01,VM011,VM23,VM35
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ExcludedResourceGroupName RG5,RG6,RG7
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ExcludedResourceGroupName RG5,RG6,RG7 -ExludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1 -ExcludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Start-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1,RG2,RG3 -ExcludedVMName VM5,VM6,VM7
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 10/Jan/2018
    Last Revision Date: 15/Jan/2018
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(
 
    [Parameter(Mandatory = $false)]
    [String[]]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [String[]]$VMName,

    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedVMName
)

if (!(Get-AzureRmContext).Account) {
    $connectionName = "AzureRunAsConnection"
    try {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
    
        $account = Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
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

# Create Stopwatch and Start the Timer
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

[System.Collections.ArrayList]$jobQ = @()

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
   # Get a list of all the VMs across all Resource Groups in the Subscription
   $VMs = Get-AzureRmVm

   # Check if one or more VMs were discovered across Subscription
   if ($VMs) {
       
       # Iterate through all the VMs discovered within the Subscription
       foreach ($vmx in $VMs) {

            If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
            {
                if ($ExcludedResourceGroupName.Contains($vmx.ResourceGroupName))
                {
                    Write-Output "Skipping VM {$($vmx.Name)} since the Resource Group {$($vmx.ResourceGroupName)} containing it is specified as Excluded..."
                    continue
                }
            }

            If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
            {
                if ($ExcludedVMName.Contains($vmx.Name))
                {
                    Write-Output "Skipping VM {$($vmx.Name)} since it is specified as Excluded..."
                    continue
                }
            }
           
           # Get reference to the specific VM for this Iteration
           $vm = Get-AzureRmVM -ResourceGroupName $vmx.ResourceGroupName -Name $vmx.Name

           $VMBaseName = $vm.Name
           $RGBaseName = $vm.ResourceGroupName

           # Get current status of the VM
           $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status
                   
           # Extract current Power State of the VM
           $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
           
           # Check PowerState Level of the VM, and stop it only if it is in a "Running" or "Starting" state
           if ($VMState) {
               if ($VMState -in "deallocated","stopped") {
                   Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                   $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                   $jobQ.Add($retval) > $null
               }
               elseif ($VMState -in "running","starting") {
                   Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting. Skipping."
                   continue
               }
               elseif ($VMState -in "stopping","deallocating") {
                   Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                   continue
               }
           }
           else {
               Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
               continue
           }
       }
   }
   else 
   {
       Write-Output "There are no VMs in the Azure Subscription."
       continue
   }
}
# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
   
    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedResourceGroupName' together with 'ResourceGroupName'"
        return
    }

    foreach ($rg in $ResourceGroupName) {

        # Get a list of all the VMs in the specific Resource Group
        $VMs = Get-AzureRmVm -ResourceGroupName $rg -ErrorAction SilentlyContinue

        if(!$?)
        {
            Write-Output "The Resource Group {$rg} does not exist. Skipping."
            continue             
        }
        
        if ($VMs) {
            # Iterate through all the VMs within the specific Resource Group for this Iteration
            foreach ($vm in $VMs) {

                If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
                {
                    if ($ExcludedVMName.Contains($vm.Name))
                    {
                        Write-Output "Skipping VM {$($vm.Name)} from Resource Group {$rg} since it is specified as Excluded..."
                        continue
                    }
                }

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
                
                if ($VMState) {
                    if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is currently Deallocated/Stopped. Starting..."
                        $retval = Start-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -AsJob
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is either already Started or Starting. Skipping."
                        continue
                    }
                    elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot start the VM. Skipping to next VM..."
                    continue
                }
            }
        }
        else {
            Write-Output "There are no Virtual Machines in Resource Group {$rg}. Skipping to next Resource Group"
            continue
        }
    }
}
# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {

    # You cannot specify Resource Groups more than 1 when both ResourceGroupName and VMName parameters are specified
    if ($ResourceGroupName.Count -gt 1)
    {
        Write-Output "You can only specify a single Resource Group Name value when using both 'ResourceGroupName' and 'VMName' parameters together."
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedResourceGroupName' together with 'ResourceGroupName'"
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedVMName' together with 'ResourceGroupName' and 'VMName'"
        return
    }

    # Check if Resource Group exists
    $testRG = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$testRG) {
        Write-Output "The Resource Group {$ResourceGroupName} does not exist. Skipping."
        continue            
    }

    # Iterate through all VM's specified
    foreach ($vms in $VMName)
    {
        # Get the specified VM in the specific Resource Group
        $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $vms -ErrorAction SilentlyContinue

        if ($vm) {
            
            $VMBaseName = $vm.Name
            $RGBaseName = $vm.ResourceGroupName

            # Get current status of the VM
            $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

            # Extract current Power State of the VM
            $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

            if ($VMState) {
                if ($VMState -in "deallocated","stopped") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                    $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "running","starting") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting. Skipping"
                    continue
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }        
            else {
                Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
                continue
            }
        }
        else {
            Write-Error "There is no Virtual Machine named {$vms} in Resource Group {$ResourceGroupName}. Aborting..."
            return
        }
    }
}
# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {

    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedResourceGroupName' and 'VMName' together"
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedVMName' and 'VMName' together"
        return
    }

    foreach ($vms in $VMName) {
       
        # Find the specific VM resource
        $vmFind = Find-AzureRmResource -ResourceNameEquals $vms

        # If the VM resource is found in the Subscription
        if ($vmFind)
        {
            # Extract the Resource Group Name of the VM
            $RGBaseName = $vmFind.ResourceGroupName
            
            # Get reference object of the VM
            $vm = Get-AzureRmVm -ResourceGroupName $RGBaseName -Name $vms
            
            if ($vm) {

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
                    
                if ($VMState) {
                    if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                        $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting. Skipping."
                        continue 
                    }
                    elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }        
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
                    continue
                }
            }
            else {
                
                Write-Error "There is no Virtual Machine named {$vms} in the Azure Subscription. Aborting..."
                return
            }
        }
        else {
            Write-Output "Could not find Virtual Machine {$vms} in the Azure Subscription."
            continue
        }
    }
}

# Stop the Timer
$StopWatch.Stop()

# Display the Elapsed Time
Write-Output "Total Execution Time for Starting All Target VMs:" + $StopWatch.Elapsed.ToString()

Get-Job | Wait-Job | Receive-Job

Write-Output "All Target VM's which were stopped/deallocated, have been Started Successfully!"
