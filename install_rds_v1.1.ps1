$ErrorActionPreference = "Stop"
# FQDN сервера
$name = Get-WmiObject Win32_ComputerSystem
$rdServer = $name.DNSHostName + "." + $name.Domain
#укажите сервера
$ConnectionBroker = $rdserver 
$WebAccessServer = $rdserver 
$SessionHost =  $rdserver 

# укажите AD группу для доступа к коллекции
$UserGroup = "Domain Users"
# укажите Имя коллекции
$CollectionName = "PAM"
# файл установщика
$program = 'CrystalDiskInfo9_3_1.exe'
# аргументы тихой установки
$silentInstallKey = '/VERYSILENT /NORESTART'
#Установщик ПО должен быть в одной папке со скриптом
$installString = $PSScriptRoot + $program + " " + $silentInstallKey
# путь к установленной программе
$pathInstalledProgram = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe"
# отображаемое имя RemoteApp
$displayName = 'CrystalDiskInfo'


$ip = 'localhost'
#подразумевается что на сервере не установлены никаки роли RDS
$roles = @("RDS-RD-SERVER", "RDS-CONNECTION-BROKER", "RDS-WEB-ACCESS")
$result = (Get-WindowsFeature -Name $roles | select Installed).Installed
if (!($result[0])) {
    Install-WindowsFeature -Name $roles -IncludeAllSubFeature -Restart
    Exit
}
#деплой RDS служб
if (!(Get-RDServer)) {
    New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer -SessionHost $SessionHost 
    Write-Host 'RDSessionDeployment installed' -ForegroundColor Green
}  else { Write-Host 'RDSessionDeployment already installed' -ForegroundColor Yellow}
# указание сервера лицензий
if (!((Get-RDLicenseConfiguration).LicenseServer)) {
    Set-RDLicenseConfiguration -LicenseServer $rdserver -Mode PerUser -ConnectionBroker $rdserver -Force
    Write-Host 'License  installed' -ForegroundColor Green
} else { Write-Host 'License already installed' -ForegroundColor Yellow}
#создание коллекции
if (!(Get-RDSessionCollection)){
    New-RDSessionCollection -CollectionName $CollectionName -CollectionDescription "Collection for $CollectionName" -SessionHost $SessionHost -ConnectionBroker $ConnectionBroker -PooledUnmanaged -Verbose
    Write-Host "RDSessionCollection $CollectionName created" -ForegroundColor Green
} else { Write-Host "RDSessionCollection $CollectionName already exist" -ForegroundColor Yellow }
# изменение группы для коллекции
$userGroupState = (Get-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup).UserGroup
if (($userGroupState.split("\")[1] -ne $userGroup)){
	Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup $userGroup
	Write-Host "UserGroup = $userGroup" -ForegroundColor Grenn
} else {Write-Host "UserGroup = $userGroup" -ForegroundColor Yellow}
# установка ПО
if (!(Test-Path $pathInstalledProgram)) { 
Invoke-Expression $installString 
Write-Host "create $pathInstalledProgram istalled" -ForegroundColor Green 
Start-Sleep 5
} else {Write-Host "Program $pathInstalledProgram - already installed " -ForegroundColor Yellow }
#создание RemoteApp
if (!(Get-RDRemoteApp -DisplayName $displayName)){
New-RDRemoteApp -CollectionName "PAM" -DisplayName $displayName -FilePath $pathInstalledProgram
Write-Host "RemoteApp $displayName - installed " -ForegroundColor Green 
} else {Write-Host "RemoteApp $displayName - already installed " -ForegroundColor Yellow }
#создание ссылки на Рабочем столе
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