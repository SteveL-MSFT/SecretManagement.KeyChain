$keyChainName = 'SecretManagement.KeyChain'
$securityCmd = '/usr/bin/security'

function Unlock-KeyChain {
    [CmdletBinding()]
    param (
        [securestring] $Password
    )

    if ($Password) {
        & $securityCmd unlock-keychain -p ($Password | ConvertFrom-SecureString -AsPlainText) $keyChainName
    }
    else {
        & $securityCmd unlock-keychain $keyChainName
    }
}

function Set-KeyChainConfiguration {
    [CmdletBinding()]
    param (
        [SecureString] $Password,
        [int] $PasswordTimeout
    )

    if ($PasswordTimeout -eq 0) {
        & $securityCmd set-keychain-settings $keyChainName
    }
    else {
        & $securityCmd set-keychain-settings -t $PasswordTimeout $keyChainName
    }

    if ($Password) {
        & $securityCmd set-keychain-password -p ($Password | ConvertFrom-SecureString -AsPlainText) $keyChainName
    }
}

function Get-KeyChainConfiguration {
    [CmdletBinding()]
    param ()

    $null = Test-SecretVault -Name $keyChainName
    $out = & $securityCmd show-keychain-info $keyChainName 2>&1

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
