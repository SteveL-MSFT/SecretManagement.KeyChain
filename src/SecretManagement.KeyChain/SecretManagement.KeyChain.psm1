$keyChainName = 'SecretManagement.KeyChain'

function Unlock-KeyChain {
    [CmdletBinding()]
    param (
        [securestring] $Password
    )

    if ($Password) {
        security unlock-keychain -p ($Password | ConvertFrom-SecureString -AsPlainText)
    }
    else {
        security unlock-keychain
    }
}

function Set-KeyChainConfiguration {
    [CmdletBinding()]
    param (
        [int] $PasswordTimeout
    )

    if ($PasswordTimeout -eq 0) {
        security set-keychain-settings $keyChainName
    }
    else {
        security set-keychain-settings -t $PasswordTimeout $keyChainName
    }
}

function Get-KeyChainConfiguration {
    [CmdletBinding()]
    param ()

    $null = Test-SecretVault -VaultName $keyChainName
    $out = security show-keychain-info $keyChainName 2>&1

    # example output:
    # Keychain "SecretManagement.KeyChain" lock-on-sleep timeout=300s
    if ($out -match 'timeout=(.*?)s') {
        $timeout = $matches[1]
    }
    elseif ($out -match 'no-timeout') {
        $timeout = 0
    }
    else {
        throw "Could not parse KeyChain configuration info"
    }

    [PSCustomObject]@{
        Name = $keyChainName
        PasswordTimeout = $timeout
    }
}
