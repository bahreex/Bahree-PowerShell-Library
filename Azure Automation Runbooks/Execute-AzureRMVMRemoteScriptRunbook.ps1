<#PSScriptInfo
.VERSION 1.0.1
.GUID 33caea6b-5e18-4ab4-9ff8-9a851000cc95
.AUTHOR Arjun Bahree
.COMPANYNAME 
.COPYRIGHT (c) 2018 Arjun Bahree. All rights reserved.
.TAGS Windows PowerShell PSRemoting Azure AzureAutomation Runbooks
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
Lets you setup remote connection to all Azure ARM VMs in an Azure Subscription, for remotely executing 
PowerShell Scripts/Commnads on the target Azure VMs.
#>

<#
.SYNOPSIS 
    Lets you setup remote connection to all Azure ARM VMs in an Azure Subscription for remotely executing PoweShell scripts
    on the target VMs

.DESCRIPTION
    This Runbook sets up and remotely executes Inline Powershell scripts on one/more/all Azure ARM virtual machines in 
    your Azure Subscription. It enables you to traverse through all resource groups and corresponding VMs in your Azure 
    Subscription, check the current state of VMs (and skip the deallocated/atopped ones), check OS type (Windows or 
    Linux, and skip Linux ones). Thereafter, this script triggers specific Inline functions to enable and configure 
    Windows Remote Management service on each VM, setup a connection to the Azure subscription, get the public IP 
    Address of the VM, and remote into it to for execution of whatever commands/script needs to be executed there.
    You need to pass the script to be executed on the VMs as an Inline string. You need to execute this Runbook through 
    a 'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER KeyVaultName
    Name of the Azure KeyVault, where password for each of the VMs are stored. Assuming Passwords for each VM are stored
    in Azure Keyvault in the format: "Secret Name = <VM Name>, Secret Value = <Password>" 

.PARAMETER AzureAutomationAccountName
    Name of the Azure Automation Account, from where this runbook will be run

.PARAMETER AzureAutomationResourceGroupName
    Name of the Resource Group for the Azure Automation Account, from where this runbook will be run

.PARAMETER RemoteScript
    The string represetation of the Remote PS Script you want to execute on the target VMs

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to remote Into. Specifying just the Resource Group without 
    the "VMName" parameter, will consider all VMs in this specified Resource Group. When passing this paramter from the 
    Start Runbook UI in Azure Automation, you need to pass the value using JSON String format, for e.g. a value of 'rg-01'
    should be passed as ['rg-01']. Multiple values shoudl be passed as ['rg-01', 'rg-02', 'eg-03']

.PARAMETER VMName    
    Name of the VM you want to remote Into. this parameter cannot be specified without it's Resource group in the 
    "ResourceGroupName" parameter, or else will throw error. When passing this paramter from the 
    Start Runbook UI in Azure Automation, you need to pass the value using JSON String format, for e.g. a value of 
    'vm-01' should be passed as ['vm-01']. Multiple values shoudl be passed as ['vm-01', 'vm-02', 'vm-03']

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" -ResourceGroupName RG1 -VMName VM01 `
    -RemoteScript "Write-Output 'Hello World!'" 

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" -ResourceGroupName RG1 -VMName VM01,VM02,VM11,VM13 `
    -RemoteScript "Write-Output 'Hello World!'" 

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" -ResourceGroupName RG1 -VMName "VM01" `
    -RemoteScript "Write-Output 'Hello World!'" 

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" -ResourceGroupName RG1,RG2,RG3 `
    -RemoteScript "Write-Output 'Hello World!'"

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" -VMName VM01,VM02,VM11,VM13 `
    -RemoteScript "Write-Output 'Hello World!'" 

.EXAMPLE
    Execute-AzureVMRemoting -KeyVaultName "CoreKV1" -AzureAutomationAccountName "Automation-AC1" `
    -AzureAutomationResourceGroupName "Automation-RG1" `
    -RemoteScript "Write-Output 'Hello World!'" 
    
.Notes
    Author: Arjun Bahree
    E-mail: arjun.bahree@gmail.com
    Creation Date: 6/Dec/2017
    Last Revision Date: 13/Jan/2018
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    PS Version: 5.1
    Platform: Windows
#>

param(

    [Parameter(Mandatory = $true)] 
    [String]$KeyVaultName,

    [Parameter(Mandatory = $true)] 
    [String]$AzureAutomationAccountName,

    [Parameter(Mandatory = $true)] 
    [String]$AzureAutomationResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [String]$RemoteScript,
    
    [Parameter(Mandatory = $false)]
    [String[]]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [String[]]$VMName	
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

function Remote-AzureRMVMExecute {
    Param(

        [Parameter(Mandatory = $true)] 
        [String]$RemoteVMCredName,
        
        [Parameter(Mandatory = $true)] 
        [String]$ResourceGroupName,
        
        [Parameter(Mandatory = $true)]
        [String]$RemoteScript,
    
        [Parameter(Mandatory = $true)] 
        [String]$VMName
    )   
    
    [ScriptBlock]$sb = [ScriptBlock]::Create($RemoteScript)
    
    try {   
        $IpAddress = Connect-AzureRMVMRemote -VMName $VMName -ResourceGroupName $ResourceGroupName
                   
        if ($IpAddress -And $IpAddress -match "^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)`$") {
            
            Write-Output "The IP Address for VM: {$VMName} is $IpAddress. Attempting to remote into the VM.."
    
            $VMCredential = Get-AutomationPSCredential -Name $RemoteVMCredName
    
            $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck            
    
            Invoke-Command -ComputerName $IpAddress -Credential $VMCredential -UseSSL -SessionOption $sessionOptions -ScriptBlock $sb
        }
        else {
            Write-Output "Issue in obtaining IP Address for the VM {$VMName} in Resource Group {$ResourceGroupName}: $IpAddress"
        }
    }
    catch {
        Write-Output "Could not remote into the VM: {$VMName}..."
        Write-Output "Ensure that the VM is running and that the correct VM credentials are used to remote"
        Write-Output "Error in getting the VM Details: $($_.Exception.Message)"
    }

}

function Connect-AzureRMVMRemote {
    Param
    (            
        [parameter(Mandatory = $true)]
        [String]$ResourceGroupName,
    
        [parameter(Mandatory = $true)]
        [String]$VMName      
    )

    $ErrorActionPreference = "SilentlyContinue"

    # Get the VM we need to configure
    $VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

    #--------------------------------------------------------------------------------------------------------

    $DNSName = $env:COMPUTERNAME
    $SourceAddressPrefix = "*"

    # Define a temporary configuration script file in the users TEMP directory
    $file = $env:TEMP + "\ConfigureWinRM_HTTPS.ps1"
    $string = "param(`$DNSName)" + "`r`n" + "Enable-PSRemoting -Force" + "`r`n" + "New-NetFirewallRule -Name 'WinRM HTTPS' -DisplayName 'WinRM HTTPS' -Enabled True -Profile 'Any' -Action 'Allow' -Direction 'Inbound' -LocalPort 5986 -Protocol 'TCP'" + "`r`n" + "`$thumbprint = (New-SelfSignedCertificate -DnsName `$DNSName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint" + "`r`n" + "`$cmd = `"winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"`"`$DNSName`"`"; CertificateThumbprint=`"`"`$thumbprint`"`"}`"" + "`r`n" + "cmd.exe /C `$cmd"
    $string | Out-File -FilePath $file -force

    if ($VM) {
        # Add Azure CustomScript Extension to the VM in context, and download/run a custom PS configuration script located on a remote Uri location (on a Public Github GIST within the repository for this Runbook)
        $extension = Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VM.Name -Name "EnableWinRM_HTTPS" `
            -Location $VM.Location -RunFile "ConfigureWinRM_HTTPS.ps1" -Argument $DNSName `
            -FileUri "https://gist.githubusercontent.com/bahreex/526de42953a13ef0e3f3af093cff6a74/raw/b6e42d627d37cd39dc0e31e851a3c1b9230ebc0e/ConfigureWinRM_HTTPS.ps1"

        # Get the name of the first NIC in the VM
        $nicName = Get-AzureRmResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].Id

        # Get NIC object for the first NIC in the VM
        $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName.ResourceName

        # Get the network security group attached to the NIC
        $nsgRes = Get-AzureRmResource -ResourceId $nic.NetworkSecurityGroup.Id
        $nsg = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $ResourceGroupName  -Name $nsgRes.Name

        # Get NSG Rule named "WinRM_HTTPS" in the NSG attached to the NIC
        $CheckNSGRule = $nsg | Get-AzureRmNetworkSecurityRuleConfig -Name "WinRM_HTTPS" -ErrorAction SilentlyContinue

        # Check if the NSG Rule named "WinRM_HTTPS" already exists or not. If it already exists, skip, else create new rule with same name
        if (!$CheckNSGRule) {
            # Add the new NSG rule, and update the NSG
            $InboundRule = $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "WinRM_HTTPS" -Priority 1100 -Protocol TCP -Access Allow -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Direction Inbound -ErrorAction SilentlyContinue | Set-AzureRmNetworkSecurityGroup -ErrorAction SilentlyContinue
        }

        $NICs = Get-AzureRmNetworkInterface | Where-Object {$_.VirtualMachine.Id -eq $VM.Id}
    
        $IPConfigArray = New-Object System.Collections.ArrayList
    
        foreach ($nic in $NICs) {
            if ($nic.IpConfigurations.LoadBalancerBackendAddressPools) {
                $arr = $nic.IpConfigurations.LoadBalancerBackendAddressPools.id.Split('/')
                $LoadBalancerNameIndex = $arr.IndexOf("loadBalancers") + 1                    
                $loadBalancer = Get-AzureRmLoadBalancer | Where-Object {$_.Name -eq $arr[$LoadBalancerNameIndex]}
                $PublicIpId = $loadBalancer.FrontendIPConfigurations.PublicIpAddress.Id
            }

            $publicips = New-Object System.Collections.ArrayList

            if ($nic.IpConfigurations.PublicIpAddress.Id) {
                $publicips.Add($nic.IpConfigurations.PublicIpAddress.Id) | Out-Null
            }

            if ($PublicIpId) {
                $publicips.Add($PublicIpId) | Out-Null
            }

            foreach ($publicip in $publicips) {
                $name = $publicip.split('/')[$publicip.Split('/').Count - 1]
                $ResourceGroup = $publicip.Split('/')[$publicip.Split('/').Indexof("resourceGroups") + 1]
                $PublicIPAddress = Get-AzureRmPublicIpAddress -Name $name -ResourceGroupName $ResourceGroup | Select-Object -Property Name, ResourceGroupName, Location, PublicIpAllocationMethod, IpAddress
                $IPConfigArray.Add($PublicIPAddress) | Out-Null
            }
        }
    
        $Uri = $IPConfigArray | Where-Object {$_.IpAddress -ne $null} | Select-Object -First 1 -Property IpAddress

        if ($Uri.IpAddress -ne $null) {               
            return $Uri.IpAddress.ToString()           
        }
        else {
            Write-Output "Couldnt get the IP Address of the VM"
            return
        }
    }
    else {
        Write-Output "VM not found"
        return
    }
}

function Create-AzureAutomationCredentials {
    Param
    (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$AzureAutomationAccountName,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$AzureAutomationResourceGroupName,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$CredentialName,

        # Parameter help description
        [Parameter()]
        [String]$Suffix = "-AACredential",

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$UserName,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$Password
    )

    # Form standardized name of the Azure Automation PS Credential for the Input credential Info
    $CredName = $CredentialName + $Suffix    

    # Get all the existing Azure Automation PS Credential for the Input credential Info
    $CredsCollection = Get-AzureRmAutomationCredential -ResourceGroupName $AzureAutomationResourceGroupName -AutomationAccountName $AzureAutomationAccountName -ErrorAction "SilentlyContinue"

    if ($CredsCollection) {
        # Iterate through all existing Automation PS Credential to check for presence of that for the Input credential Info
        foreach ($credItem in $CredsCollection) {                    
            if ($credItem.Name -eq $CredName) {
                $Cred = $credItem
                return 0
            }
        }
    }

    # If Azure Automation PS Credential for the Input credential Info is null
    if (!$Cred) {
        try {
            # Get Secure version of the Input Password
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            
            # Form PS Credential Object from the Input User Name and Password
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
            
            # Creat new Azure Automation PS Credential object for the Input credential Info
            $vmAzureAutomationCredential = New-AzureRmAutomationCredential -AutomationAccountName $AzureAutomationAccountName -Name $CredName -Value $Credential -ResourceGroupName $AzureAutomationResourceGroupName
        }
        catch {
            Write-Error "Unable to create new Azure Automation Credential for VM {$CredentialName}. Exception: $($_.Exception)" 2> $null
            return 1
        }
    }
}

function InitRemoting {

    Param
    (
        [Parameter(Mandatory = $true)]
        [String]$AAName,

        [Parameter(Mandatory = $true)]
        [String]$AARGName,

        [Parameter(Mandatory = $false)]
        [String]$RGName,

        [Parameter(Mandatory = $false)]
        [String]$vmName,

        [Parameter(Mandatory = $true)]
        [String]$KVName
    )

    $VMBaseName = $vmName
    $RGBaseName = $RGName

    $vmRef = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName

    # Get OS Type of the VM
    $OSX = $vmRef.StorageProfile.OsDisk.OsType.ToString()
                    
    # Check if OS is Windows or Linux
    if ($OSX -And $OSX -eq "Linux") {

        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is on $OSX OS. Hence, cannot process further since only Windows OS Remoting supported. Skipping forward."
        continue
    }

    # Get current Status of the VM
    $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

    # Extract current Power State of the VM
    $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]                   
        
    # Check if PowerState is deallocated/stopped, or in a transient state of deallocating/stopping
    if ($VMState -And ($VMState -in "deallocated","stopped","deallocating","stopping")) {
        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either deallocated/stopped, or in a transient state. Hence, cannot get IP address, and skipping."
        continue
    }
    else {
        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Running. Proceeding forward."
    }
        
    # For the VM in context, extract the corresponding username/password from Azure KeyVault
    $secret = Get-AzureKeyVaultSecret -VaultName $KVName -Name $VMBaseName

    if ($secret)
    {        
        # Call the script to check if the Azure Automation Credential for the VM in context alredy exists, and create a new one if absent
        $SetCredentials = Create-AzureAutomationCredentials -AzureAutomationAccountName $AAName `
            -AzureAutomationResourceGroupName $AARGName `
            -CredentialName $VMBaseName `
            -UserName $vmRef.oSProfile.AdminUsername `
            -Password $secret.SecretValueText
            
        if ($SetCredentials -eq 0) {

            # Form standardized name of the Azure Automation PS Credential for the VM in context
            $RemoteVMCredName = $VMBaseName + "-AACredential"

            # Call PS Script to Remote Into the VM in context
            Remote-AzureRMVMExecute -RemoteVMCredName $RemoteVMCredName `
                -ResourceGroupName $RGBaseName `
                -VMName $VMBaseName `
                -RemoteScript $RemoteScript
        }
        else {
            Write-Output "Unable to get or set Azure Automation Credentials for VM {$VMBaseName}. Skipping forward..."
            continue
        }
    }
    else{
        Write-Output "The VM {$VMBaseName} does not have its Credentail Password stored in KeyVault {$KVName}. Skipping..."
        continue 
    }   
}

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
    
    # Get a list of all the VMs in the Azure Subscription
    $VMs = Get-AzureRmVm -ErrorAction SilentlyContinue

    # If there are one or more VMs in the Subscription
    if ($VMs) {

        # Iterate through all the VMs within the specific Resource Group for this Iteration
        foreach ($vm in $VMs) {

            # Call function to proceed further with remoting into the VM
            InitRemoting -AAName $AzureAutomationAccountName -AARGName $AzureAutomationResourceGroupName `
            -RGName $vm.ResourceGroupName -vmName $vm.Name -KVName $KeyVaultName
        }
    }
    else {
        Write-Output "There are no Azure RM VMs in the Azure Subscription."
    }
}

# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {

    # Iterate for one or more Resource Group Names passed in the parameter
    foreach ($rgName in $ResourceGroupName)
    {
        # Get reference to the Resource Group
        $RG = Get-AzureRmResourceGroup -Name $rgName -ErrorAction SilentlyContinue

        # If Resource Group exists 
        if ($RG)
        {
            # Get a list of all the VMs in the specific Resource Group
            $VMs = Get-AzureRmVm -ResourceGroupName $rgName -ErrorAction SilentlyContinue

            if ($VMs) {

                # Iterate through all the VMs within the specific Resource Group for this Iteration
                foreach ($vm in $VMs) {
                    
                    # Call function to proceed further with remoting into the VM
                    InitRemoting -AAName $AzureAutomationAccountName -AARGName $AzureAutomationResourceGroupName `
                    -RGName $vm.ResourceGroupName -vmName $vm.Name -KVName $KeyVaultName
                }
            }
            else {
                Write-Output "There are no Virtual Machines in the Resource Group {$rgName}. Aborting..."
                return
            }
        }
        else {
            Write-Output "There is no Resource Group {$rgName} in the Azure Subscription. Aborting..."
                return
        }
    }
}

# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {

    # Check if only One value is passed for the "Resource Group Name" parameter, or else quit
    if ($ResourceGroupName.Count -gt 1)
    {
        Write-Error "You cannot specify more than One Resource Group, when combined with the "VMName" Parameter."
        return
    }
    
    $RG = Get-AzureRmResourceGroup -Name $rgName -ErrorAction SilentlyContinue

    # Check if the Resource Group already exists, or else quit
    if (!$RG)
    {
        Write-Output "There is no Resource Group named {$ResourceGroupName} in the Azure Subscription. Aborting..."
        return
    }

    # Iterate for one or more VM Names passed in the parameter
    foreach ($vmx in $VMName)
    {
        # Get the specified VM in the specific Resource Group
        $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $vmx -ErrorAction "SilentlyContinue"

        if ($vm) {

            # Call function to proceed further with remoting into the VM
            InitRemoting -AAName $AzureAutomationAccountName -AARGName $AzureAutomationResourceGroupName `
                -RGName $ResourceGroupName -vmName $VMName -KVName $KeyVaultName
        }
        else {
            Write-Output "There is no Virtual Machine named {$VMName} in Resource Group {$ResourceGroupName}. Aborting..."
            return
        }
    }
}

# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {
    
    # Iterate for one or more VM Names passed in the parameter
    foreach ($vmx in $VMName)
    {
        # Find the specific VM resource
        $vmFind = Find-AzureRmResource -ResourceNameEquals $vmx

        # If the VM resource is found in the Subscription
        if ($vmFind)
        {
            # Extract the Resource Group Name of the VM
            $RGBaseName = $vmFind.ResourceGroupName
            
            # Call function to proceed further with remoting into the VM
            InitRemoting -AAName $AzureAutomationAccountName -AARGName $AzureAutomationResourceGroupName `
            -RGName $RGBaseName -vmName $vmx -KVName $KeyVaultName
        }
        else {
            Write-Output "Could not find Virtual Machine {$vmx} in the Azure Subscription."
            continue
        }
    }
}
