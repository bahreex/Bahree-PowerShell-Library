# PowerShell DSC COnfiguration for Spectre CPU Vulenrability

configuration SpectreFix {

    param(
        [string[]]$ComputerName
    )

    Import-DSCResource -ModuleName PSDesiredStateConfiguration

    node $ComputerName {
        Registry FeatureSettingsOverride {
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            ValueName = "FeatureSettingsOverride"
            ValueData = 0
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry FeatureSettingsOverrideMask {
            Key       = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            ValueName = "FeatureSettingsOverrideMask"
            ValueData = 3
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry MinVmVersionForCpuBasedMitigations {
            Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
            ValueName = "MinVmVersionForCpuBasedMitigations"
            ValueData = "1.0"
            ValueType = 'String'
            Ensure    = 'Present'
        }
    }
}
