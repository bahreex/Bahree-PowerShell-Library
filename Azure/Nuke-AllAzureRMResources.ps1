<#
.SYNOPSIS 
    Lets you asynchronously destory/nuke all Azure RM resources in an Azure Subscription

.DESCRIPTION
    This script lets you destory/nuke all Azure RM resources in an Azure Subscription asynchronously. You need to be already 
    logged into your Azure account through PowerShell before calling this script.

.EXAMPLE
    .\Nuke-AzureRMAllResources.ps1
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 09/Jan/2018
    Last Revision Date: 09/Jan/2018
    Version: 1.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>
[CmdletBinding()]
param
()

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Get a list of all the Resource Groups in the Azure Subscription
$RGs = Get-AzureRmResourceGroup 

[System.Collections.ArrayList] $Job = @()

# Check if there are Resource Groups in the current Azure Subscription
if ($RGs) {        
    # Iterate through all the Resource Groups in the Azure Subscription        
    foreach ($rg in $RGs) 
    {
        $RGBaseName = $rg.ResourceGroupName

        # Remove the Resource Group Arsynchronously using PS Jobs
        $retVal = Start-Job -ScriptBlock {Remove-AzureRmResourceGroup -Name $args[0] -Force} -ArgumentList $RGBaseName
        
        # Add each Job to an Arraylist. Reserved for use in any future use case
        $Job.Add($retVal)

        Write-Verbose "Removing Resource Group $RGBaseName..."

        # Wait for a pre-defined time to throttle the job requests
        Start-Sleep 10
    }

    # Remove all completed Jobs
    Get-Job | Wait-Job | Remove-Job

    Write-Verbose "Nuked all the Azure RM resource from the Azure Subscription. Any Azure Classic resources, if there, were not touched..."
}
else {
    Write-Error "There are no Azure Resource Groups in the Azure Subscription. Aborting..."
    return $null
}