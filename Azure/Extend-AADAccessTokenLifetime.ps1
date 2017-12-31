<#
.SYNOPSIS 
    Lets you change the default lifetime of the Azure AD Access Token

.DESCRIPTION
    This script lets you change the default lifetime of the Azure AD Access Token from 60 minutes to another duration. The maximum allowed lifetime duration for Azure AD Access Token is 24 hours (23:59)

.PARAMETER PolicyName
    Name of the Azure AD Policy that will be set within the Subscription

.PARAMETER PolicyMaxLife    
    The new time duration you want to extend the Azure AD Access Token lifetime to. This should be a DateTime object or a string representing the duration in Hours:Minutes format

.EXAMPLE
    Extend-AADAccessTokenLifetime.ps1 -PolicyName "Test-Policy" -PolicyMaxLife "23:59"
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 31/Dec/2017
    Last Revision Date: 31/Dec/2017
    Version: 1.0
    Development Environment: VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>
[CmdletBinding()]
param(
[Parameters(Mandatory=$true)]
[string]$PolicyName,

[Parameters(Mandatory=$true)]
[ValidateRange(1,23)]
[datetime]$PolicyMaxLife

)

if (Get-Module -ListAvailable -Name AzureADPreview) {
    if (!(Get-Module "AzureADPreview")) {
        Write-Information "AzureADPreview Module is Installed but not loaded. Importing the module...."
        Import-Module AzureADPreview
    }
} 
else 
{
    Write-Information "AzureADPreview Module is not Installed. Installing and Importing the AzureADPreview module..."
    Install-Module -Name AzureADPreview
    Import-Module AzureADPreview
}

Connect-AzureAD -Confirm

$existingAADPolicies = Get-AzureADPolicy

foreach($aadpolicy in $existingAADPolicies)
{
    if ($aadpolicy.DisplayName -eq $PolicyName)
    {
        Write-Error "The Azure AD Policy by this name already exists in the Subscription."
        return        
    }
}


$setNewPolicy = New-AzureADPolicy -Definition @('{"TokenLifetimePolicy":{"Version":1,"AccessTokenLifetime":"0.' + $PolicyMaxLife.ToShortTimeString() + ':00"}}') -DisplayName $PolicyName -IsOrganizationDefault $true -Type "TokenLifetimePolicy"

if ($setNewPolicy)
{
    Write-Information "The Azure AD Access Token Lifetine has been extended to $PolicyMaxLife Hours"
}

