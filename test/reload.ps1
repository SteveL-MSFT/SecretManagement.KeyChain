if (Get-SecretVault -Name KeyChain) {
    # Any secrets stored in the KeyChain vault will be preserved
    Unregister-SecretVault KeyChain
}

# $modules = 'SecretManagement.KeyChain','Microsoft.PowerShell.SecretStore','Microsoft.PowerShell.SecretManagement'
# SecretStore should not come into play
# If we trusted Microsoft.PowerShell.SecretManagement to do the Unregister above, it should be ok as well
$modules = 'SecretManagement.KeyChain'

foreach ($module in $modules) {
    if (Get-Module $module) {
        Remove-Module $module -Force
    }
}

# Register must be done from scratch to make sure ModulePath is from src
$srcmodulepath = Resolve-Path -Path $PSScriptRoot/../src/SecretManagement.KeyChain
Register-SecretVault  $srcmodulepath -Name KeyChain 

Import-Module $srcmodulepath
