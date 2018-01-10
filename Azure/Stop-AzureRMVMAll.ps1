<#
.SYNOPSIS 
    Asynchronously Stop all or specific Azure RM VMs in an Azure Subscription

.DESCRIPTION
    This script asynchronously Stops either all Azure RM VMs in an Azure Subscription, or all Azure RM VMs in one or more specified Resource Groups, or a specific Azure RM VM. The choice around which VMs to stop
    depends on the parameters provided. You need to be already logged into your Azure account through PowerShell before calling this script.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to remote Into. Specifying just the Resource Group without the $VMName parameter, will consider all VMs in this specified Resource Group

.PARAMETER VMName    
    Name of the VM you want to remote Into. this parameter cannot be specified without it's Resource group in the $ResourceGroupName parameter, or else will throw error  

.EXAMPLE
    .\Stop-AzureRMVMAll.ps1
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1,RG2,RG3
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName "RG1" -VMName "VM01"
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 6/Dec/2017
    Last Revision Date: 10/Jan/2018
    Version: 3.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

[CmdletBinding()]
param(
 
    [Parameter()]
    [String[]]$ResourceGroupName,
    
    [Parameter()]
    [String]$VMName	
)

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}  

[System.Collections.ArrayList]$jobQ = @()

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
    # Get a list of all the Resource Groups in the Azure Subscription
    $RGs = Get-AzureRmResourceGroup 
    
    # Check if there are Resource Groups in the current Azure Subscription
    if ($RGs) {        
        # Iterate through all the Resource Groups in the Azure Subscription        
        foreach ($rg in $RGs) {
            $RGBaseName = $rg.ResourceGroupName
            
            # Get a list of all the VMs in the specific Resource Group for this Iteration
            $VMs = Get-AzureRmVm -ResourceGroupName $RGBaseName

            if ($VMs) {
                # Iterate through all the VMs within the specific Resource Group for this Iteration
                foreach ($vm in $VMs) {
                    $VMBaseName = $vm.Name

                    # Get current status of the VM
                    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                    # Extract current Power State of the VM
                    $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]
                    
                    # Return the Power State
                    $VMState = $powerState.ToUpper()
                    
                    if ($VMState) {
                        if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                            Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                            continue
                        }
                        elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                            Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting."
                            $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                            $jobQ.Add($retval) > $null
                        }
                        elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                            Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                            continue
                        }
                    }
                    else {
                        Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
                        continue
                    }
                }
            }
            else {
                Write-Verbose "There are no VMs in the Resource Group {$RGBaseName}. Continuing with next Resource Group, if any."
                continue
            }
        }
    }
    else {
        Write-Error "There are no Resource Groups in the Azure Subscription {$AzureSubscriptionId}. Aborting..."
        return $null
    }
}
# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
    foreach ($rg in $ResourceGroupName) {
        # Get a list of all the VMs in the specific Resource Group
        $VMs = Get-AzureRmVm -ResourceGroupName $rg
        
        if ($VMs) {
            # Iterate through all the VMs within the specific Resource Group for this Iteration
            foreach ($vm in $VMs) {
                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                # Extract current Power State of the VM
                $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]

                # Return the Power State
                $VMState = $powerState.ToUpper()
                
                if ($VMState) {
                    if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is either already Started or Starting."
                        $retval = Stop-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot start the VM. Skipping to next VM..."
                    continue
                }
            }
        }
        else {
            Write-Verbose "There are no Virtual Machines in Resource Group {$rg}. Skipping to next Resource Group"
            continue
        }
    }
}
# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {
    # Get the specified VM in the specific Resource Group
    $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $VMName

    if ($vm) {    
        $VMBaseName = $vm.Name

        # Get current status of the VM
        $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

        # Extract current Power State of the VM
        $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]
        
        # Return the Power State
        $VMState = $powerState.ToUpper()
        
        if ($VMState) {
            if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                Write-Verbose "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is currently already Deallocated/Stopped. Skipping."
                continue
            }
            elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                Write-Verbose "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is either already Started or Starting."
                $retval = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMBaseName -AsJob -Force
                $jobQ.Add($retval) > $null
            }
            elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                Write-Verbose "The VM {$VMBaseName} in Resource Group {$ResourceGroupName} is in a transient state of Stopping or Deallocating. Skipping."
                continue
            }
        }        
        else {
            Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$ResourceGroupName}. Hence, cannot start the VM. Skipping to next VM..."
            continue
        }
    }
    else {
        Write-Error "There is no Virtual Machine named {$VMName} in Resource Group {$ResourceGroupName}. Aborting..."
        return
    }
}
# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {
    Write-Error "VM Name parameter cannot be specified alone, without specifying its Resource Group Name parameter also. Aborting..."
    return
}

$jobStatus = 0

while ($jobStatus -ne $jobQ.Count) { 
    foreach ($job in $jobQ) {
        if ($job.State -eq "Completed") {
            Remove-Job $job.Id
            $jobStatus++
            continue
        }
    }

    if ( $jobStatus -eq $jobQ.Count) {
        Write-Information "All VMs have been stopped"
    }
}