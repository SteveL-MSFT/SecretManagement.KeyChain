$keyChainName = 'SecretManagement.KeyChain'
$securityCmd = '/usr/bin/security'

# Helpers

# SecretManagement converts strings in hashtable to securestring before handing it to extensions
# since I need to serialize to json, we need to convert everything to just strings
function Convert-HashTable([hashtable]$h) {
    $newh = @{}
    foreach ($key in $h.Keys) {
        if ($h[$key] -is [hashtable]) {
            $newh.$key = Convert-HashTable $h[$key]
        }
        elseif ($h[$key] -is [PSCredential]) {
            $newh.$key = @{
                __type = 'PSCredential'
                UserName = $h[$key].UserName
                Password = $h[$key].Password | ConvertFrom-SecureString -AsPlainText
            }
        }
        elseif ($h[$key] -is [SecureString]) {
            $newh.$key = $h[$key] | ConvertFrom-SecureString -AsPlainText
        }
        else {
            $newh.$key = $h[$key]
        }
    }

    $newh
}

function Convert-HashTableCreds([hashtable]$h) {
    $newh = @{}
    foreach ($key in $h.Keys) {
        if ($h[$key].__type -eq 'PSCredential') {
            $newh.$key = [PSCredential]::new($h[$key].UserName, ($h[$key].Password | ConvertTo-SecureString -AsPlainText))
        }
        elseif ($h[$key] -is [hashtable]) {
            $newh.$key = Convert-HashTableCreds $h[$key]
        }
        else {
            $newh.$key = $h[$key]
        }
    }

    $newh
}

function ConvertTo-Base64([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    [System.Convert]::ToBase64String($bytes)
}

function ConvertFrom-Base64([string]$base64) {
    $bytes = [System.Convert]::FromBase64String($base64)
    [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-SecretType($typename) {
    switch($typename) {
        'STRG' {
            [Microsoft.PowerShell.SecretManagement.SecretType]::String
        }
        'SSTR' {
            [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
        }
        'BYTE' {
            [Microsoft.PowerShell.SecretManagement.SecretType]::ByteArray
        }
        'CRED' {
            [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential
        }
        'HASH' {
            [Microsoft.PowerShell.SecretManagement.SecretType]::Hashtable
        }
        default {
            [Microsoft.PowerShell.SecretManagement.SecretType]::Unknown
        }
    }    
}

function Convert-KeyChainSecret([string]$text) {
    # Example output that needs to be parsed:
    #
    # keychain: "/Users/steve/Library/Keychains/SecretManagement.KeyChain-db"
    # version: 512
    # class: "genp"
    # attributes:
    #     0x00000007 <blob>="KeyChain"
    #     0x00000008 <blob>=<NULL>
    #     "acct"<blob>="mysecret"
    #     "cdat"<timedate>=0x32303230313030393233303831315A00  "20201009230811Z\000"
    #     "crtr"<uint32>="STRG"
    #     "cusi"<sint32>=<NULL>
    #     "desc"<blob>=<NULL>
    #     "gena"<blob>=<NULL>
    #     "icmt"<blob>=<NULL>
    #     "invi"<sint32>=<NULL>
    #     "mdat"<timedate>=0x32303230313030393233303831315A00  "20201009230811Z\000"
    #     "nega"<sint32>=<NULL>
    #     "prot"<blob>=<NULL>
    #     "scrp"<sint32>=<NULL>
    #     "svce"<blob>="KeyChain"
    #     "type"<uint32>=<NULL>
    # password: "secret"

    if ($text -match '"acct"\<blob\>="(.*?)"') {
        $name = $matches[1]
    }

    if ($text -match '"svce"\<blob\>="(.*?)"') {
        $vaultname = $matches[1]
    }

    if ($text -match '"crtr"<uint32>="(.*?)"') {
        $typename = $matches[1]
    }

    if ($text -match 'password: "(.*?)"') {
        $secret = ConvertFrom-Base64 $matches[1]
    }

    if ($null -eq $name -or $null -eq $typename) {
        throw "Failed to parse KeyChain text output: $text"
    }

    [PSCustomObject]@{
        Name = $name
        TypeName = $typename
        Type = (Get-SecretType $typename)
        Secret = $secret
        VaultName = $vaultname
    }
}

# KeyChain is case sensitive, so make sure to use the original casing
function Get-VaultName([string]$name) {
    $vault = Get-SecretVault -Name $name
    $vault.Name
}

# Public functions
function Get-Secret {
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $Name = $Name.ToLower()
    $VaultName = Get-VaultName $VaultName

    $out = & $securityCmd find-generic-password -a $Name -s $VaultName -g $keyChainName 2>&1 | Out-String
    if ($out -notmatch 'password: "(.*?)"') {
        throw $out
    }

    $secret = Convert-KeyChainSecret $out
    if ($null -eq $secret.Secret) {
        throw "Not able to parse KeyChain for secret"
    }

    switch ($secret.TypeName) {
        'STRG' {
            $secretObj = $secret.Secret
        }
        'SSTR' {
            $secretObj = ConvertTo-SecureString $secret.Secret -AsPlainText
        }
        'HASH' {
            $secretObj = $secret.Secret | ConvertFrom-Json -AsHashTable
            $secretObj = Convert-HashTableCreds $secretObj
        }
        'BYTE' {
            $secretObj = [byte[]]::new($secret.Secret.Length / 2)

            for ($i = 0; $i -lt $secret.Secret.Length; $i += 2) {
                $secretObj[$i/2] = [System.Convert]::ToByte($secret.Secret.Substring($i, 2), 16)
            }
        }
        'CRED' {
            $cred = $secret.Secret | ConvertFrom-Json
            $secretObj = [PSCredential]::new($cred.UserName, ($cred.Password | ConvertTo-SecureString -AsPlainText))
        }
        default {
            throw "Unknown type: $($secret.TypeName)"
        }
    }

    return $secretObj
}

function Set-Secret {
    param (
        [string] $Name,
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $VaultName = Get-VaultName $VaultName
    Test-SecretVault -Name $VaultName

    # KeyChain is case-sensitive, so always use lowercase
    $Name = $Name.ToLower()

    switch ($Secret.GetType()) {
        'String' {
            $type = 'STRG'
        }
        'SecureString' {
            $type = 'SSTR'
            $Secret = $Secret | ConvertFrom-SecureString -AsPlainText
        }
        'Hashtable' {
            $type = 'HASH'
            $Secret = Convert-HashTable $secret | ConvertTo-Json -Depth 100 -Compress
        }
        'Byte[]' {
            $type = 'BYTE'
            $Secret = [System.BitConverter]::ToString($Secret).Replace('-','')
        }
        'PSCredential' {
            $type = 'CRED'
            $Secret = [PSCustomObject]@{
                UserName = $Secret.UserName
                Password = $Secret.Password | ConvertFrom-SecureString -AsPlainText
            } | ConvertTo-Json -Compress
        }
        default {
            throw "Unsupported object type: $($Secret.GetType().Name)"
        }
    }

    $Secret = ConvertTo-Base64 $Secret
    $out = & $securityCmd add-generic-password -a $Name -s $VaultName -c $type -w $Secret -U $keyChainName 2>&1
    if (!$?) {
        throw $out
    }

    return $?
}

function Remove-Secret {
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $VaultName = Get-VaultName $VaultName

    # KeyChain is case-sensitive, so always use lowercase
    $Name = $Name.ToLower()

    $out = & $securityCmd delete-generic-password -a $Name -s $VaultName $keyChainName 2>&1 | Out-String
    $exitstatus = $out -match 'password has been deleted'
    if (!$exitstatus) {
        throw $out
    }
    return $exitstatus
}

function Get-SecretInfo {
    param (
        [string] $Filter,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $VaultName = Get-VaultName $VaultName

    if ($filter.Contains('*')) {
        $output = & $securityCmd dump-keychain $keyChainName | Out-String
        if (!$?) {
            throw "Unable to get contents of KeyChain"
        }

        if ($null -eq $output) {
            return
        }

        foreach ($secretText in $output.Split('keychain:', [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $secret = Convert-KeyChainSecret $secretText

            if ($secret.Name -like $Filter -and $secret.VaultName -eq $VaultName) {
                [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
                    $secret.Name,
                    $secret.Type,
                    $VaultName
                )
            }
        }
    }
    else {
        $output = & $securityCmd find-generic-password -a $Filter -s $VaultName $keyChainName | Out-String
        if (!$?) {
            return $null
        }

        $secret = Convert-KeyChainSecret $output
        [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            $secret.Name,
            $secret.Type,
            $VaultName
        )
    }
}

function Test-SecretVault {
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )
    if ($AdditionalParameters.Verbose) {
        $VerbosePreference = 'Continue'
    }
    # VaultName corresponds to service within a secret item
    # SecretManagement.KeyChain is a constant for this extension
    #
    # show-keychain-info - possible outputs
    # Keychain "SecretManagement.KeyChain" no-timeout
    # Keychain "SecretManagement.KeyChain" timeout=240s
    # Keychain "SecretManagement.KeyChain" lock-on-sleep timeout=300s
    # security: SecKeychainCopySettings SecretManagement.KeyChain: The specified keychain could not be found.

    $out = & $securityCmd show-keychain-info $keyChainName 2>&1 | Out-String
    $keyChainExists = $out -match '^Keychain'
    Write-Verbose -Message $out
    Write-Verbose -Message ('keyChainExists {0}' -f $keyChainExists)
    if (!$keyChainExists) {
        & $securityCmd create-keychain -P $keyChainName
        # confirm keychain was properly created
        $out = & $securityCmd show-keychain-info $keyChainName 2>&1 | Out-String
        $keyChainExists = $out -match '^Keychain'
        Write-Verbose -Message $out
        Write-Verbose -Message ('keyChainExists {0}' -f $keyChainExists)    
    }
    return $keyChainExists
}
