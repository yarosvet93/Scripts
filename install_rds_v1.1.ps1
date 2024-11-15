#Укажите группу для доступа к коллекции
$UserGroup = "Domain Users"

#Установщик ПО должен быть в одной папке со скриптом
$path = $PSScriptRoot

#имя файла установщика
$program = 'CrystalDiskInfo9_3_1.exe'

#путь к установленной программе
$pathInstalledProgram = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe"
$displayName = 'CrystalDiskInfo'
$silentInstallKey = '/VERYSILENT /NORESTART'

#$DOMAIN = $env:USERDOMAIN
$fullDomain =(Get-WmiObject Win32_ComputerSystem).Domain
$DomainParts = $fullDomain.Split(".")
$DN = ($DomainParts | % {"DC=$_"}) -join ","
$LDAPPath = "LDAP://$DN"
$dirSearch = New-Object System.DirectoryServices.DirectorySearcher
$dirSearch.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$dirSearch.Filter = "(CN=Domain Users)"
$dirSearch.PropertiesToLoad.Add("CN")
$dirSearch.PropertiesToLoad.Add("sAMAccountName")
$dirSearch.PropertiesToLoad.Add("description")
$resultSearch = $dirSearch.FindOne()
$SAN = $resultSearch.Properties.sAMAccountName
$CN = $resultSearch.Properties.CN
if($true){}
$rdServer = [System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName
$CollectionName = "PAM"

$installString = $path + $program + " " + $silentInstallKey
$ip = 'localhost'
$roles = @("RDS-RD-SERVER", "RDS-CONNECTION-BROKER", "RDS-WEB-ACCESS")
$result = (Get-WindowsFeature -Name $roles | select Installed).Installed
if (!($result[0])) {
    Install-WindowsFeature -Name $roles -IncludeAllSubFeature -Restart
    Exit
}

New-RDSessionDeployment -ConnectionBroker $rdserver  -WebAccessServer $rdserver  -SessionHost $rdserver 
if ($Error[0]) {
    if ($Error[0].ToString() -eq 'A session-based desktop deployment is already present.'){
        Write-Host 'RDSessionDeployment installed' -ForegroundColor Yellow
    }
}

if ((Get-RDLicenseConfiguration).LicenseServer -ne $rdServer ){
    Set-RDLicenseConfiguration -LicenseServer $rdserver -Mode PerUser -ConnectionBroker $rdserver -Force
    Write-Host 'License  installed' -ForegroundColor Green
} else { Write-Host 'License already installed' -ForegroundColor Yellow}

if (!(Get-RDSessionCollection)){
    New-RDSessionCollection -CollectionName $CollectionName -CollectionDescription "Collection for $CollectionName" -SessionHost $rdserver -ConnectionBroker $rdserver -PooledUnmanaged -Verbose
    Write-Host "RDSessionCollection $CollectionName create" -ForegroundColor Green
} else { Write-Host "RDSessionCollection $CollectionName already exist" -ForegroundColor Yellow }

$userGroupState = (Get-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup).UserGroup

if (($userGroupState.split("\")[1] -ne $userGroup)){
	Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup $userGroup
	Write-Host "UserGroup = $userGroup" -ForegroundColor Grenn
} else {Write-Host "UserGroup = $userGroup" -ForegroundColor Yellow}


if (!(Test-Path $pathInstalledProgram)) { 
Invoke-Expression $installString 
Write-Host "create $pathInstalledProgram istalled" -ForegroundColor Green 
Start-Sleep 5
} else {Write-Host "Program $pathInstalledProgram - already installed " -ForegroundColor Yellow }

if (!(Get-RDRemoteApp -DisplayName $displayName)){
New-RDRemoteApp -CollectionName "PAM" -DisplayName $displayName -FilePath $pathInstalledProgram
Write-Host "RemoteApp $displayName - installed " -ForegroundColor Green 
} else {Write-Host "RemoteApp $displayName - already installed " -ForegroundColor Yellow }

$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$targetPath = "https://$ip/RDWeb/Pages/en-US/Default.aspx"
$shortcutPath = Join-Path -Path $desktopPath -ChildPath "RemoteApp.lnk"
if (!(test-path $desktopPath"RemoteApp.lnk")){
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetPath
$shortcut.Save()
}

Write-Host "Установка завершена. Нажмите Enter и перезагрузите компьютер"
Read-Host
Restart-Computer -Confirm:$true