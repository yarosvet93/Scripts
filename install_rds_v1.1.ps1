# FQDN сервера
$name = Get-WmiObject Win32_ComputerSystem
$rdServer = $name.DNSHostName + "." + $name.Domain


####################### переменные которые можно (нужно) менять #########################
#####
# укажите сервера (если надо)
# если будете ставить Сервер лицензий тут же, то добавьте "RDS-LICENSING" в $roles 
# и расскоментируйте $licenseServer если хотите указать на сервер лицензий
#$licenseServer = $rdserver  
$connectionBroker = $rdserver 
$webAccessServer = $rdserver 
$sessionHost =  $rdserver 
# укажите AD группу для доступа к коллекции
$userGroup = "Domain Users"
# укажите Имя коллекции
$collectionName = "PAM"
# файл установщика
$setupFile = 'CrystalDiskInfo9_3_1.exe'
# аргументы тихой установки
$silentInstallKey = '/VERYSILENT /NORESTART'
# путь к установленной программе (нужен для RemoteApp)
$pathInstalledProgram = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe"
# отображаемое имя RemoteApp
$displayName = 'CrystalDiskInfo'
$IP = 'localhost'
#####
#################################################################################№№№№№№№№

#Установщик ПО должен быть в одной папке со скриптом
$installString = $PSScriptRoot + "\" + $setupFile + " " + $silentInstallKey



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

function Write-Success {
    Write-Host "######### success ########`n" -ForegroundColor Green
}

$multiLineText = @"
####################
####################
####################
####################
####################
####################
####################
####################
####################
####################
####################
####################
####            ####
####   DEPLOY   ####
####    RDS     ####
####  SERVICES  ####
####            ####
####################

"@
#деплой RDS служб

if (!(Get-RDServer -ErrorAction SilentlyContinue)) {
    try {
        Write-Host $multiLineText
        New-RDSessionDeployment `
        -ConnectionBroker $connectionBroker `
        -WebAccessServer $webAccessServer `
        -SessionHost $sessionHost -ErrorAction Stop
    } catch {
	    Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    } 
    Write-Success 
} else { 
    Write-Host "Деплой RDS уже выполенен`n" -ForegroundColor Yellow
}

# указание сервера лицензий
if ((Get-RDLicenseConfiguration).LicenseServer -ne $licenseServer) {
    try {
        Write-Host "Указываем сервер лицензий`n"
        Set-RDLicenseConfiguration -LicenseServer $licenseServer -Mode PerUser -ConnectionBroker $connectionBroker -Force -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Success
} else {
    Write-Host "Сервер лицензий уже указан`n" -ForegroundColor Yellow
}

#создание коллекции
if (!(Get-RDSessionCollection)){
    try {
        Write-Host "Создаем колеекцию `"$collectionName`" `n" 
        New-RDSessionCollection `
        -CollectionName $collectionName `
        -CollectionDescription "Collection for $collectionName" `
        -SessionHost $sessionHost `
        -ConnectionBroker $connectionBroker `
        -PooledUnmanaged -ErrorAction Stop | Out-Null
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Success
} else { 
    Write-Host "Коллекция `"$collectionName`" уже существует`n" -ForegroundColor Yellow 
}

# изменение группы для коллекции
$userGroupState = (Get-RDSessionCollectionConfiguration -CollectionName $collectionName -UserGroup).UserGroup
if (($userGroupState.split("\")[1] -ne $userGroup)){
    try {
        Write-Host "Изменяем группу коллекции на `"$userGroup`" `n" 
	    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -UserGroup $userGroup -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.ScriptStackTrace.split(",")[0]
    }
	Write-Success
} else {
    Write-Host "UserGroup = `"$userGroup`" `n" -ForegroundColor Yellow
}

# установка ПО
$InstalledSoftware = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($obj in $InstalledSoftware) { if ($obj.GetValue('DisplayName') -like "$displayName*" ) {$softName = $displayName} }
if (!($softName)) { 
    try {
        Write-Host "Устанавливаем  `"$displayName`" `n" 
        Invoke-Expression -Command $installString -ErrorAction Stop
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Success
    Start-Sleep 2
} else {
    Write-Host "Программа `"$displayName`" - уже существует`n" -ForegroundColor Yellow 
}

#создание RemoteApp
if (!(Get-RDRemoteApp -DisplayName $displayName)){
    try {
        Write-Host "Создаем RemoteApp приложение: `"$displayName`" `n" 
        New-RDRemoteApp -CollectionName "PAM" -DisplayName $displayName -FilePath $pathInstalledProgram -ErrorAction Stop | Out-Null
    } catch {
        Stop-Install -ErrorMessage $_.Exception.Message -ErrorProgram $_.InvocationInfo.MyCommand.Name
    }
    Write-Success
} else {
    Write-Host "RemoteApp приложение `"$displayName`" - уже существует`n" -ForegroundColor Yellow 
}

#создание ссылки на Рабочем столе
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$targetPath = "https://$IP/RDWeb/Pages/en-US/Default.aspx"
$shortcutPath = Join-Path -Path $desktopPath -ChildPath "RemoteApp.lnk"
if (!(test-path $desktopPath"RemoteApp.lnk")){
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetPath
$shortcut.Save()
}
Write-Host "На рабочем столе создана ссылка RemoteApp.lnk`n" -ForegroundColor Green 
Write-Host "Установка завершена. Нажмите Enter и перезагрузите компьютер"
Read-Host
Restart-Computer -Confirm:$true