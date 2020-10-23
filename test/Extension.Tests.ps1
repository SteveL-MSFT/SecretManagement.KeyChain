Describe 'SecretManagement.KeyChain tests' {
    BeforeAll {
        & $PSScriptRoot/reload.ps1
    }

    BeforeEach {
        $secretName = New-Guid
    }

    It 'KeyChain vault is registered' {
        Get-SecretVault -Name KeyChain | Should -Not -BeNullOrEmpty
    }

    It 'Can store a string secret' {
        $secretText = 'This is my string secret'
        Set-Secret -Name $secretName -Vault KeyChain -Secret $secretText

        $secretInfo = Get-SecretInfo -Name $secretName -Vault KeyChain
        $secretInfo.Name | Should -BeExactly $secretName
        $secretInfo.Type | Should -BeExactly 'String'
        $secretInfo.VaultName | Should -BeExactly 'KeyChain'
        $secret = Get-Secret -Name $secretName -Vault KeyChain -AsPlainText
        $secret | Should -BeExactly $secretText

        Remove-Secret -Name $secretName -Vault KeyChain
        { Get-Secret -Name $secretName -Vault KeyChain -ErrorAction Stop } | Should -Throw -ErrorId 'GetSecretInvalidOperation,Microsoft.PowerShell.SecretManagement.GetSecretCommand'
    }

    It 'Can store a secure string secret' {
        $secretText = 'This is my securestring secret'
        Set-Secret -Name $secretName -Vault KeyChain -Secret ($secretText | ConvertTo-SecureString -AsPlainText)

        $secretInfo = Get-SecretInfo -Name $secretName -Vault KeyChain
        $secretInfo.Name | Should -BeExactly $secretName
        $secretInfo.Type | Should -BeExactly 'SecureString'
        $secretInfo.VaultName | Should -BeExactly 'KeyChain'

        $secret = Get-Secret -Name $secretName -Vault KeyChain -AsPlainText
        $secret | Should -BeExactly $secretText

        Remove-Secret -Name $secretName -Vault KeyChain
        { Get-Secret -Name $secretName -Vault KeyChain -ErrorAction Stop } | Should -Throw -ErrorId 'GetSecretInvalidOperation,Microsoft.PowerShell.SecretManagement.GetSecretCommand'
    }

    It 'Can store a byte array secret' {
        $secretText = 'This is my byte array secret'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($secretText)
        Set-Secret -Name $secretName -Vault KeyChain -Secret $bytes

        $secretInfo = Get-SecretInfo -Name $secretName -Vault KeyChain
        $secretInfo.Name | Should -BeExactly $secretName
        $secretInfo.Type | Should -BeExactly 'ByteArray'
        $secretInfo.VaultName | Should -BeExactly 'KeyChain'

        $secret = Get-Secret -Name $secretName -Vault KeyChain
        [System.Text.Encoding]::UTF8.GetString($secret) | Should -BeExactly $secretText

        Remove-Secret -Name $secretName -Vault KeyChain
        { Get-Secret -Name $secretName -Vault KeyChain -ErrorAction Stop } | Should -Throw -ErrorId 'GetSecretInvalidOperation,Microsoft.PowerShell.SecretManagement.GetSecretCommand'
    }

    It 'Can store a PSCredential secret' {
        $secretText = 'This is my pscredential secret'
        $secret = [PSCredential]::new('myUser', ($secretText | ConvertTo-SecureString -AsPlainText))
        Set-Secret -Name $secretName -Vault KeyChain -Secret $secret

        $secretInfo = Get-SecretInfo -Name $secretName -Vault KeyChain
        $secretInfo.Name | Should -BeExactly $secretName
        $secretInfo.Type | Should -BeExactly 'PSCredential'
        $secretInfo.VaultName | Should -BeExactly 'KeyChain'

        $secret = Get-Secret -Name $secretName -Vault KeyChain
        $secret.UserName | Should -BeExactly 'myUser'
        $secret.Password | ConvertFrom-SecureString -AsPlainText | Should -BeExactly $secretText

        Remove-Secret -Name $secretName -Vault KeyChain
        { Get-Secret -Name $secretName -Vault KeyChain -ErrorAction Stop } | Should -Throw -ErrorId 'GetSecretInvalidOperation,Microsoft.PowerShell.SecretManagement.GetSecretCommand'
    }

    It 'Can store hashtable secret' {
        $secretText = 'This is my hashtable secret'
        $cred = [pscredential]::new('myUser', ($secretText | convertto-securestring -asplaintext))
        $securestring = $secretText | convertto-securestring -asplaintext
        $hashtable = @{
            a = 1
            b = $cred
            c = @{
                d = 'nested'
                e = $cred
                f = $securestring
            }
            g = $securestring
        }

        Set-Secret -Name $secretName -Vault KeyChain -Secret $hashtable
        $secretInfo = Get-SecretInfo -Name $secretName -Vault KeyChain
        $secretInfo.Name | Should -BeExactly $secretName
        $secretInfo.Type | Should -BeExactly 'Hashtable'
        $secretInfo.VaultName | Should -BeExactly 'KeyChain'

        $secret = Get-Secret -Name $secretName -Vault KeyChain -AsPlainText
        $secret.a | Should -Be 1
        $secret.b | Should -BeOfType [PSCredential]
        $secret.b.UserName | Should -BeExactly 'myUser'
        $secret.b.Password | ConvertFrom-SecureString -AsPlainText | Should -BeExactly $secretText
        $secret.c | Should -BeOfType [Hashtable]
        $secret.c.d | Should -BeExactly 'nested'
        $secret.c.e | Should -BeOfType [PSCredential]
        $secret.c.e.UserName | Should -BeExactly 'myUser'
        $secret.c.e.Password | ConvertFrom-SecureString -AsPlainText | Should -BeExactly $secretText
        $secret.c.f | Should -BeExactly $secretText
        $secret.g | Should -BeExactly $secretText

        Remove-Secret -Name $secretName -Vault KeyChain
        { Get-Secret -Name $secretName -Vault KeyChain -ErrorAction Stop } | Should -Throw -ErrorId 'GetSecretInvalidOperation,Microsoft.PowerShell.SecretManagement.GetSecretCommand'
    }
}
