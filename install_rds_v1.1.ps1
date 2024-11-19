$ErrorActionPreference = "Stop"
# FQDN сервера
$name = Get-WmiObject Win32_ComputerSystem
$rdServer = $name.DNSHostName + "." + $name.Domain


####################### переменные которые можно (нужно) менять #########################
#####
# укажите сервера (если надо)
# если будете ставить Сервер лицензий тут же, то добавьте "RDS-LICENSING" в $roles 
$LicenseServer = $rdserver  
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
# путь к установленной программе
$pathInstalledProgram = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe"
# отображаемое имя RemoteApp
$displayName = 'CrystalDiskInfo'
$ip = 'localhost'
#####
#################################################################################№№№№№№№№

#Установщик ПО должен быть в одной папке со скриптом 
#(в путях не должно быть точек, кроме в расширениии файла)
$installString = $PSScriptRoot + "\" + $program + " " + $silentInstallKey
#подразумевается что на сервере не установлены никакие роли RDS
$roles = @("RDS-RD-SERVER", "RDS-CONNECTION-BROKER", "RDS-WEB-ACCESS")
$result = (Get-WindowsFeature -Name $roles | select Installed).Installed
if (!($result[0])) {
    Install-WindowsFeature -Name $roles -IncludeAllSubFeature -Restart
    Exit
}
function Stop-Install{
	param(
		[string]$ErrorMessage,
        [string]$ErrorProgram
	)
Write-Host "Ошибка в команде $ErrorProgram :" -ForegroundColor Red
Write-Host $ErrorMessage -ForegroundColor Red
Write-Host "Нажмите Enter, чтобы выйти!"
Read-Host
Exit
}


#деплой RDS служб
if (!(Get-RDServer)) {
    try {
        New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer -SessionHost $SessionHost -ErrorAction Stop
    } catch {
	    Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Host 'RDSessionDeployment installed' -ForegroundColor Green
} else { 
    Write-Host 'RDSessionDeployment already installed' -ForegroundColor Yellow
}

# указание сервера лицензий
if ((Get-RDLicenseConfiguration).LicenseServer -ne $LicenseServer) {
    try {
        Set-RDLicenseConfiguration -LicenseServer $LicenseServer -Mode PerUser -ConnectionBroker $ConnectionBroker -Force -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Host 'License installed' -ForegroundColor Green
} else {
    Write-Host 'License already installed' -ForegroundColor Yellow
}

#создание коллекции
if (!(Get-RDSessionCollection)){
    try {
        New-RDSessionCollection -CollectionName $CollectionName -CollectionDescription "Collection for $CollectionName" -SessionHost $SessionHost -ConnectionBroker $ConnectionBroker -PooledUnmanaged -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Host "RDSessionCollection `"$CollectionName`" created" -ForegroundColor Green
} else { 
    Write-Host "RDSessionCollection `"$CollectionName`" already exist" -ForegroundColor Yellow 
}

# изменение группы для коллекции
$userGroupState = (Get-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup).UserGroup
if (($userGroupState.split("\")[1] -ne $userGroup)){
    try {
	    Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -UserGroup $userGroup -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
	Write-Host "UserGroup = `"$userGroup`"" -ForegroundColor Grenn
} else {
    Write-Host "UserGroup = `"$userGroup`"" -ForegroundColor Yellow
}

# установка ПО
if (!(Test-Path $pathInstalledProgram)) { 
    try {
        Invoke-Expression -Command $installString -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Host "Программа `"$displayName`" - установлена" -ForegroundColor Green 
    Start-Sleep 2
} else {
    Write-Host "Программа `"$displayName`" - уже существует " -ForegroundColor Yellow 
}

#создание RemoteApp
if (!(Get-RDRemoteApp -DisplayName $displayName)){
    try {
        New-RDRemoteApp -CollectionName "PAM" -DisplayName $displayName -FilePath $pathInstalledProgram
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Host "RemoteApp приложение `"$displayName`" - установлено " -ForegroundColor Green 
} else {
    Write-Host "RemoteApp приложение `"$displayName`" - уже существует " -ForegroundColor Yellow 
}

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