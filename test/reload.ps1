if (Get-SecretVault KeyChain) {
    Unregister-SecretVault KeyChain
}

$modules = 'SecretManagement.KeyChain','Microsoft.PowerShell.SecretStore','Microsoft.PowerShell.SecretManagement'

foreach ($module in $modules) {
    if (Get-Module $module) {
        Remove-Module $module -Force
    }
}

Register-SecretVault $PSScriptRoot/../src/SecretManagement.KeyChain -Name KeyChain

Import-Module $PSScriptRoot/../src/SecretManagement.KeyChain
