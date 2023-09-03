@{
    RootModule = 'SecretManagement.KeyChain.Extension.psm1'
    ModuleVersion = '0.1.4'
    CompatiblePSEditions = @('Core')
    GUID = '6a4caa73-b31c-4df3-a751-9b96b1daf294'
    Author = 'Steve Lee'
    CompanyName = 'Microsoft Corporation'
    Copyright = '(c) Microsoft Corporation'
    FunctionsToExport = 'Set-Secret', 'Get-Secret', 'Remove-Secret', 'Get-SecretInfo', 'Test-SecretVault'
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}

