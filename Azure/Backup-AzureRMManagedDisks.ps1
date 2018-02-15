
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$false)]
    [string[]]$ResourceGroups,

    [Parameter(Mandatory=$false)]
    [string[]]$ManagedDiskNames,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory=$true)]
    [string]$StorageAccountKey,

    [Parameter(Mandatory=$false)]
    [string]$BlobContainerName = 'managed-disks-storage',

    [Parameter(Mandatory=$false)]
    [bool]$RunAsAzureAutomationRunbook=$false
)

# Custom function to print context specific messages depending upon if the current script is running
# as an Azure Automation PS Runbook or a normal PS Script
function Write-Message ($msg) {
    # If running as normal PS Script
    if ($RunAsAzureAutomationRunbook -eq $false) {
        Write-Verbose $msg
    }
    # If running as an Azure Automation PS Runbook
    else {
        Write-Output $msg
    }
}

$eAction = 'SilentlyContinue'

if (!(Get-AzureRmContext).Account) {
    if ($RunAsAzureAutomationRunbook -eq $true)
    {
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
                $ErrorMessage = "Connection $connectionName not found. This script is running in Runbook mode, and needs to be executed from Azure Automation as a PS Runbook."
                throw $ErrorMessage
            }
            else {
                Write-Error -Message "This script is running in Runbook mode, and needs to be executed from Azure Automation as a PS Runbook."
                Write-Error -Message $_.Exception
                throw $_.Exception
            }
        }
    }
    else {
        Write-Error "You need to be first logged into your Azure Subscription from your PowerShell Session."
    }
}

# Get the Azure Storage Context
$Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction $eAction

# Check if we got a valid Azure Storage Context or not
if (!$Context) {
    Write-Error -Message ("Error: Could not get the Context for Storage Account '{0}'. Please check your permissions and Storage Account/Key, and try again." -f $StorageAccountName)
}

# Set Container name, either one passed as parameter or the default value
$containerName = $BlobContainerName

# Check if the container already exists or not
$containerExists = Get-AzureStorageContainer -Name $containerName -Context $Context -ErrorAction $eAction

if (!$containerExists) {
    # Create New Blob Container
    $newContainer = New-AzureStorageContainer -Context $Context -Name $containerName -Permission Off -ErrorAction $eAction

    if (!$newContainer) {
        Write-Error "Error: The Container {$containerName} did not exist. The new Container {$containerName} could not be created in the Storage Account {$StorageAccountName}. Please check your permissions and try again."
    }
}

# Declare the variable array for holding all candidate Managed Disks Information
$mDisks = @()

if ($PSBoundParameters.ContainsKey('ManagedDiskNames') -and !$PSBoundParameters.ContainsKey('ResourceGroups')) {

    # Get references to all Managed Disks names passed as parameter
    $mDisks = Get-AzureRmDisk | Where-Object {$_.Name -in $ManagedDiskNames}

}
elseif (!$PSBoundParameters.ContainsKey('ManagedDiskNames') -and !$PSBoundParameters.ContainsKey('ResourceGroups')) {

    # Get references to all Managed Disks within the current Subscription
    $mDisks = Get-AzureRmDisk
}
elseif (!$PSBoundParameters.ContainsKey('ManagedDiskNames') -and $PSBoundParameters.ContainsKey('ResourceGroups')) {

    foreach ($rg in $ResourceGroups) {

        # Get references to all Managed Disks within all the Resource Groups passed
        $tmpDisks = Get-AzureRmDisk -ResourceGroupName $rg -ErrorAction $eAction

        if ($tmpDisks) {$mDisks += $tmpDisks}
    }
}

# Iterate through all the Managed Disks
foreach ($mDisk in $mDisks) {
    # Get datetime stamp in format DDMMYYYYHHMMSS
    $datetimeStamp = (Get-Date).Day.ToString() + (Get-Date).Month.ToString() + (Get-Date).Year.ToString() + (Get-Date).Hour.ToString() + (Get-Date).Minute.ToString() + (Get-Date).Second.ToString()

    $mDiskRG = $mDisk.ResourceGroupName

    # Create a new unique Blob name
    $blobName = $mDisk.Name + '_' + $datetimeStamp

    # Create SAS URL for accessing the Managed Disk
    $mDiskSAS = Grant-AzureRmDiskAccess -ResourceGroupName $mDiskRG -DiskName $mDisk.Name -Access Read -DurationInSecond 3600 -ErrorAction $eAction

    if (!$mDiskSAS) {
        Write-Message "Could net get the SAS URL for the Managed Disk {$($mDisk.Name)} in Resource Group {$mDiskRG}. Please check your permissions. Continuing..."
        continue
    }

    # Copy the Managed Disk to the new BLOB Container
    $copyBlob = Start-AzureStorageBlobCopy -AbsoluteUri $mDiskSAS.AccessSAS -DestContainer $containerName -DestBlob $blobName -DestContext $Context -ErrorAction $eAction

    if (!$copyBlob) {
        Write-Message "Could not copy the Managed Disk '{$($mDisk.Name)}' in Resource Group {$mDiskRG} to the Storage Account '{$StorageAccountName}'. Please check your permissions. Continuing..."
        continue
    }
}

