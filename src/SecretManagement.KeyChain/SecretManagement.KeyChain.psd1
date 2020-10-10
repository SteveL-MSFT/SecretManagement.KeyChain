@{
    ModuleVersion = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID = '74bb5212-2a5d-451d-8f43-edf9bcd2efe8'
    Author = 'Steve Lee'
    CompanyName = 'Microsoft Corporation'
    Copyright = '(c) Microsoft Corporation'
    Description = 'SecretManagement extension vault for macOS KeyChain'
    RootModule = 'SecretManagement.KeyChain.psm1'
    NestedModules = @('SecretManagement.KeyChain.Extension')
    FunctionsToExport = @('Unlock-KeyChain','Set-KeyChainConfiguration','Get-KeyChainConfiguration')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('SecretManagement')
            LicenseUri = 'https://github.com/SteveL-MSFT/SecretManagement.KeyChain/blob/main/LICENSE'
            ProjectUri = 'https://github.com/SteveL-MSFT/SecretManagement.KeyChain'
            ReleaseNotes = 'Initial release'
            #Prerelease = ''
            # ExternalModuleDependencies = @('Microsoft.PowerShell.SecretManagement')
        }
    }
}
