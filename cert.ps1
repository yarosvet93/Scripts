[CmdletBinding()]
param (
    [Parameter(HelpMessage="SecMan URL")]
    [ValidateNotNullOrEmpty()]
    $secmanUrl = 'https://p.secrets.ca.sbrf.ru',
    [Parameter(HelpMessage="SecMan Namespace")]
    [ValidateNotNullOrEmpty()]
    $secmanNamespace = "CI02315894_CI04913004",
    [Parameter(HelpMessage="SecMan approle path")]
    [ValidateNotNullOrEmpty()]
    $secmanApprolePath = "A/CI04801419/OSH/CONFIG/KV/approle",
    [Parameter(HelpMessage="SecMan sberca path")]
    [ValidateNotNullOrEmpty()]
    $secmanSberCAPath = "A/CI04801419/OSH/CONFIG/SBERCA/sberca-int",
    [Parameter(HelpMessage="SecMan sberca role")]
    [ValidateNotNullOrEmpty()]
    $secmanSberCARole = "client_1y_AS_rsa",
    [Parameter(HelpMessage="SecMan sberca cn")]
    [ValidateNotNullOrEmpty()]
    $secmanSberCACN = "CI04801419PROM_RDS-$Env:COMPUTERNAME",
    [Parameter(HelpMessage="Certificate Format (pkcs12, pem)")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("pkcs12","pem")]
    $secmanSberCAFormat = "pkcs12",
    [Parameter(HelpMessage="Auth domain (sigma, smartbio, omega)")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("sigma","omega","smartbio")]
    $AuthDomain = "omega"
)

function Set-SecmanLogin {
    [CmdletBinding(DefaultParameterSetName = "approle")]
    param(
        [Parameter(Mandatory, ParameterSetName = "ldap",HelpMessage="SecMan Uri")]
        [Parameter(Mandatory, ParameterSetName = "ldap2fa",HelpMessage="SecMan Uri")]
        [Parameter(Mandatory, ParameterSetName = "approle",HelpMessage="SecMan Uri")]
        [ValidateNotNullOrEmpty()]
        [string]$SecmanUrl,
        [Parameter(Mandatory=$false, ParameterSetName = "ldap", HelpMessage="Namespace")]
        [Parameter(Mandatory=$false, ParameterSetName = "ldap2fa",HelpMessage="SecMan Uri")]
        [Parameter(Mandatory=$false, ParameterSetName = "approle", HelpMessage="Namespace")]
        [string]$Namespace,
        [Parameter(Mandatory, ParameterSetName = "approle", HelpMessage="Logon creds json")]
        [ValidateNotNullOrEmpty()]
        [psobject]$CredList,
        [Parameter(Mandatory, ParameterSetName = "ldap", HelpMessage="Namespace")]
        [Parameter(Mandatory, ParameterSetName = "ldap2fa",HelpMessage="SecMan Uri")]
        [ValidateNotNullOrEmpty()]
        [string]$MountPath,
        [Parameter(Mandatory, ParameterSetName = "ldap", HelpMessage="Namespace")]
        [Parameter(Mandatory, ParameterSetName = "ldap2fa",HelpMessage="SecMan Uri")]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Credentials,
        [Parameter(Mandatory, ParameterSetName = "ldap2fa",HelpMessage="SecMan 2fa")]
        [ValidateNotNullOrEmpty()]
        [string]$secondFactor,
        [Parameter(Mandatory=$true, ParameterSetName = "ldap")]
        [switch]$ldap,
        [Parameter(Mandatory=$true, ParameterSetName = "approle")]
        [switch]$approle,
        [Parameter(Mandatory=$true, ParameterSetName = "ldap2fa")]
        [switch]$ldap2fa
    )
    
    Write-Debug $PSCmdlet.ParameterSetName
    
    switch ($PSCmdlet.ParameterSetName) {
        "approle" {
            $SecmanApproleLoginUri = '/v1/auth/approle/login'
            $SecmanApiUri = "$SecmanUrl$SecmanApproleLoginUri"
            $SecmanPayload = @{
               "role_id" = $CredList.role_id;
               "secret_id" = $CredList.secret_id;
            }
            $SecmanMethod = "Post"
            $SecmanHeaders = @{
                'X-Vault-Namespace' = $Namespace
            }
            Write-Debug ($SecmanPayload)
            Write-Debug ($SecmanApiUri)
            Write-Debug ($SecmanHeaders)
            $response = Invoke-WebRequest -Uri $SecmanApiUri -Headers $SecmanHeaders -Method $SecmanMethod -Body $SecmanPayload
        }
        "ldap" {
            Write-Debug ($Credentials | ConvertTo-Json)
            $username = $Credentials.username
            $passwd = (New-Object PSCredential 0, ($Credentials.password)).GetNetworkCredential().Password
            $SecmanLdapLoginUri = "/v1/auth/$MountPath/login/$username"
            $SecmanApiUri = "$SecmanUrl$SecmanLdapLoginUri"
            $SecmanPayload = @{
                "password" = $passwd
            }
            $SecmanMethod = "Post"
            $SecmanHeaders = @{
                'X-Vault-Namespace' = $Namespace
            }
            Write-Debug $SecmanApiUri
            $response = Invoke-WebRequest -Uri $SecmanApiUri -Headers $SecmanHeaders -Method $SecmanMethod -Body $SecmanPayload
        }
        "ldap2fa" {
            Write-Debug ($Credentials | ConvertTo-Json)
            $username = $Credentials.username
            $passwd = (New-Object PSCredential 0, ($Credentials.password)).GetNetworkCredential().Password
            $SecmanLdapLoginUri = "/v1/auth/$MountPath/login/$username"
            $SecmanApiUri = "$SecmanUrl$SecmanLdapLoginUri"
            Write-Debug "Secman api uri $SecmanApiUri"
            $SecmanPayload = @{
                "password" = $passwd
            }
            $SecmanMethod = "Post"
            $SecmanHeaders = @{
                'X-Vault-Namespace' = $Namespace;
                'x-vault-mfa' = "ldap_2fa:$secondFactor"
            }
            Write-Debug ($SecmanHeaders | ConvertTo-Json)
            $response = Invoke-WebRequest -Uri $SecmanApiUri -Headers $SecmanHeaders -Method $SecmanMethod -Body $SecmanPayload
        }
        Default {
            throw (New-Object -TypeName System.ArgumentException -ArgumentList "Auth method not implemented");
        }
    }
    
    try {
        Write-Debug $response
        $response = $response | ConvertFrom-Json
        $SecmanAccessToken = $response.auth.client_token
        $SecmanAccessToken
    }
    catch {
        Write-Error "Cannot get vault access token"
    }
}

function Get-SecmanKV {
    param(
        [Parameter(Mandatory, HelpMessage="SecMan Uri")]
        [ValidateNotNullOrEmpty()]
        [string]$SecmanUrl,
        [Parameter(Mandatory=$false, HelpMessage="Namespace")]
        [string]$Namespace,
        [Parameter(Mandatory, HelpMessage="Vault token")]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
        [Parameter(Mandatory, HelpMessage="Path")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    $SecmanGetKV = "/v1/$Namespace/$Path"

    $SecmanRestUri = "$SecmanUrl$SecmanGetKV"
    $SecmanMethod = "Get"
    $SecmanHeaders = @{
        'X-Vault-Namespace' = $Namespace;
        'X-Vault-Token' = $AccessToken;
    }
    Write-Debug $SecmanRestUri
    Write-Debug $SecmanHeaders

    $response = Invoke-WebRequest -Uri $SecmanRestUri -Headers $SecmanHeaders -Method $SecmanMethod
    try {
        Write-Debug $response
        $response = $response | ConvertFrom-Json
        $response
    }
    catch {
        Write-Error "Cannot get vault access token"
    }
}

function Get-SecmanSberCACert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, HelpMessage="SecMan Uri")]
        [ValidateNotNullOrEmpty()]
        [string]$SecmanUrl,
        [Parameter(Mandatory=$false, HelpMessage="Namespace")]
        [string]$Namespace,
        [Parameter(Mandatory, HelpMessage="Vault token")]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,
        [Parameter(Mandatory, HelpMessage="Path")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory, HelpMessage="Role")]
        [ValidateNotNullOrEmpty()]
        [string]$Role,
        [Parameter(Mandatory, HelpMessage="CN")]
        [ValidateNotNullOrEmpty()]
        [string]$CN,
        [Parameter(Mandatory, HelpMessage="key format")]
        [ValidateNotNullOrEmpty()]
        [string]$Format = "pem"
    )

    $SecmanRestUri = "$SecmanUrl/v1/$Namespace/$Path/fetch/$Role"
    $SecmanMethod = "Post"
    $SecmanHeaders = @{
        'X-Vault-Token' = $AccessToken;
    }
    $SecmanPayload = @{
        "common_name" = $CN;
        "format" = $Format;
        "private_key_format" = "pem";
        "alt_names" = $CN
    }
    Write-Debug $SecmanRestUri
    Write-Debug ($SecmanHeaders | ConvertTo-Json)
    Write-Debug ($SecmanPayload | ConvertTo-Json)

    $response = Invoke-WebRequest -Uri $SecmanRestUri -Headers $SecmanHeaders -Method $SecmanMethod -Body $SecmanPayload
    try {
        Write-Debug $response
        $response = $response | ConvertFrom-Json
        $response
    }
    catch {
        Write-Error "Cannot get vault access token"
    }
}

try {
    $username = Read-Host -Prompt "username"
    $password = Read-Host -Prompt "password" -AsSecureString
    $creds = @{
        username = $username;
        password = $password
    }
    $secmanSecondFactor = Read-Host -Prompt "2fa: "
    $SecmanAuthDomain = "ad/" + $AuthDomain + ".sbrf.ru"
    Write-Debug "LDAP Auth domain: $SecmanAuthDomain"
    $token = Set-SecmanLogin -ldap2fa -SecmanUrl $secmanUrl -Namespace $secmanNamespace -Credentials $creds -MountPath $SecmanAuthDomain -secondFactor $secmanSecondFactor
    Write-Host "Login success"
    Write-Host "Fetching approle..." -NoNewline
    $approleCreds = (Get-SecmanKV -SecmanUrl $secmanUrl -Namespace $secmanNamespace -Path $secmanApprolePath -AccessToken $token).data
    Write-Debug ($approleCreds | ConvertTo-Json)
    Write-Host "success"
    
    Write-Host "Logging in with approle creds..." -NoNewline
    $token = Set-SecmanLogin -approle -SecmanUrl $secmanUrl -CredList $approleCreds -Namespace $secmanNamespace
    Write-Host "success"
    
    Write-Host "Fetching client cert with CN=$secmanSberCACN..." -NoNewline
    $response = Get-SecmanSberCACert -SecmanUrl $secmanUrl -AccessToken $token -Namespace $secmanNamespace -Path $secmanSberCAPath -Role $secmanSberCARole -CN $secmanSberCACN -Format $secmanSberCAFormat
    Write-Host "success"

    try {
        if ($secmanSberCAFormat -eq "pkcs12") {
            Write-Host "Rendering certs to the $secmanSberCACN.{p12,passphrase}"
            $P12BinCert = [System.Convert]::FromBase64String($response.data.certificate)

            [IO.File]::WriteAllBytes("$secmanSberCACN.p12", $P12BinCert)
            Write-Information "Certificate saved to the $secmanSberCACN.p12"
            Out-File -Encoding utf8 -FilePath "$secmanSberCACN.passphrase" -InputObject $response.data.passphrase
            Write-Information "Passphrase saved to the $secmanSberCACN.passphrase"
            $ca_cert = ""
            foreach ($cert in $($response.data.ca_chain)) {
                $ca_cert += $cert
            }
            Out-File -Encoding utf8 -FilePath "ca-bundle.crt" -InputObject $ca_cert
        } elseif ($secmanSberCAFormat -eq "pem") {
            Write-Host "Rendering certs to the $secmanSberCACN.{crt,key}"
            Out-File -Encoding utf8 -FilePath "$secmanSberCACN.crt" -InputObject $response.data.certificate
            Write-Information "Certificate saved to the $secmanSberCACN.crt"
            Out-File -Encoding utf8 -FilePath "$secmanSberCACN.key" -InputObject $response.data.private_key
            Write-Information "Certificate saved to the $secmanSberCACN.key"
            $ca_cert = ""
            foreach ($cert in $($response.data.ca_chain)) {
                $ca_cert += $cert
            }
            Out-File -Encoding utf8 -FilePath "ca-bundle.crt" -InputObject $ca_cert
        }
    }
    catch {
        $_
    }
}
catch {
    $_
}

############################################################
