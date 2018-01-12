<#
.SYNOPSIS 
    Asynchronously Stops all or specific Azure RM VMs in an Azure Subscription as a Runbook from within an Azure 
    Automation Account

.DESCRIPTION
    This Runbook asynchronously Stops either all Azure RM VMs in an Azure Subscription, or all Azure RM VMs in one or 
    more specified Resource Groups, or one or more VMs in a specific Resource Group, or any number of Random VMs in a 
    Subscription. The choice around which VMs to stop depends on the combination and values of the parameters provided. 
    You need to execute this Runbook through a 'Azure Run As account (service principal)' Identity from an Azure 
    Automation account.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to Stop. Specifying just the Resource Group without 
    the "VMName" parameter will consider all VMs in that specified Resource Group. You can specify an array of 
    Resource Group names without "VMname" parameter, and all VMs withihn the specified Resource Groups in the array will
    be stopped. You can specify just a single Resource Group Name in this parameter, along with one or more VM names in 
    the "VMName" parameter, wherein all the VMs specified will be stopped in that specific Resource Group. You cannot
    specify more than one Resource Group Names when combined with the "VMName" parameter.

.PARAMETER VMName    
    Name of the VM you want to Stop. This parameter when specified alone, without the $ResourceGroupName 
    parameter, can Include one or more VM Names to be stopped across any resource groups in the Azure Subscription. When
    specified with the "-ResourceGroupName" parameter, you need to Include one or more VMs in the specified Resource
    Group only.

.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1,RG2,RG3
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1 -VMName VM01
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ResourceGroupName RG1 -VMName VM01,VM02,VM05
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -VMName VM01,VM011,VM23,VM35
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 10/Jan/2018
    Last Revision Date: 11/Jan/2018
    Version: 2.0
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(
 
    [Parameter()]
    [String[]]$ResourceGroupName,
    
    [Parameter()]
    [String[]]$VMName	
)

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

# Create Stopwatch
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
# Start Stopwatch
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
                if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }
            else {
                Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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

    foreach ($rg in $ResourceGroupName) {

        $testRG = Get-AzureRmResourceGroup -Name $rg -ErrorAction SilentlyContinue
        if (!$testRG) {
            Write-Output "The Resource Group {$rg} does not exist. Skipping."
            continue            
        }

        # Get a list of all the VMs in the specific Resource Group
        $VMs = Get-AzureRmVm -ResourceGroupName $rg
        
        if ($VMs) {
            # Iterate through all the VMs within the specific Resource Group for this Iteration
            foreach ($vm in $VMs) {
                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]

                # Return the Power State
                $VMState = $powerState
                
                if ($VMState) {
                    if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot stop the VM. Skipping to next VM..."
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
        Write-Output "You can only specify a single Resource Group Name value when using both '-ResourceGroupName' and '-VMName' parameters together."
        return
    }

    # Check if Resource Group exists
    $testRG = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$testRG) {
        Write-Verbose "The Resource Group {$ResourceGroupName} does not exist. Skipping."
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
                if ($VMState -eq "deallocated" -Or $VMState -eq "stopped") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }        
            else {
                Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -eq "running" -Or $VMState -eq "starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -eq "stopping" -Or $VMState -eq "deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }        
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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
Write-Output "Total Execution Time for Stopping All Target VMs: $($StopWatch.Elapsed.ToString())"

Get-Job | Wait-Job | Receive-Job

Write-Output "All Target VM's which were Running, have been stopped Successfully!"