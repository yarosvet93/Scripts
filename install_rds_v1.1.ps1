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
$userGroup = "RDS_Users"
# укажите Имя коллекции
$collectionName = "PAM"
$IP = 'localhost'
#папка, где будут лежать все установщики
$pathDistr = 'C:\Distr'
$displayName = "EndpointClient"
$programFolder = 'C:\Program Files\EndpointClient'
$clientpaht = 'C:\Program Files\EndpointClient\'
$pathInstalledProgram = "C:\Program Files\EndpointClient\WorkerEndpointClient.exe"
$sberPath = "C:\Program Files (x86)\SberBrowser\Application"

#################################################################################№№№№№№№№
function Write-Success {
    Write-Host "######### success ########`n" -ForegroundColor Green
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

#################################### установка ПО #################################

$programs = @(
    @{
        Name = "VC_redist.x64";
        Path = "${pathDistr}\VC_redist.x64 2019 (16.9)_14.28.29.exe";
        Args = "/install /quiet"
        Check = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Microsoft Visual C*2019*" }
    },
    @{
        Name = "EndpointService";
        Path = "${pathDistr}\EndpointService.msi";
        Args = "/quiet"
        Check = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "EndpointService" }
    },
    @{
        Name = "EndpointClient";
        Path = "${pathDistr}\EndpointClient.msi";
        Args = "/quiet"
        Check = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "EndpointClient" }
    },
    @{
        Name = "dbeaver-ce-23.3.3-x86_64";
        Path = "${pathDistr}\dbeaver-ce-23.3.3-x86_64-setup.exe";
        Args = "/allusers /S"
        Check = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "DBeaver*" }
    },
    @{
        Name = "SberBrowser-win-x86";
        Path = "${pathDistr}\SberBrowser-win-x86-distrib.exe";
        Args = "-system-level"
        Check = Test-Path "C:\Program Files (x86)\SberBrowser\Application\sberbrowser.exe"
    }
)

foreach ($program in $programs) {
    if (!($programs.Check)){
        try {
            if ($program.Path -match "\.msi$") {
                Write-Host "Установка: $($program.Name)"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($program.Path)`" $($program.Args)" -Wait -ErrorAction Stop
                Write-Success
            } elseif ($program.Path -match "\.exe$") {
                Write-Host "Установка: $($program.Name)"
                Start-Process -FilePath $program.Path -ArgumentList $program.Args -Wait -ErrorAction Stop
                Write-Success
            } else {
                Write-Host "неизвестный установщик: $($program.Name)"
            }
        } catch {
            Write-Host "Failed to install $($program.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Программа: $($program.Name) уже установлена" -ForegroundColor Yellow
    }
}

#чтобы не делать проверки при повторном запуске, просто -Force использую 
try {
    Copy-Item -Path "${pathDistr}\autoit-0.0.11\*" -Destination $clientpaht -Force -ErrorAction Stop
    Write-Host "Файлы из autoit-0.0.11 успешно скопированы в $clientpaht"
    Copy-Item -Path "${sberPath}\*" -Destination $clientpaht -Exclude "sberbrowser.exe"  -Force -Recurse -ErrorAction Stop
    Write-Host "Файлы из ${sberPath} успешно скопированы в $clientpaht"
    Copy-Item -Path "${pathDistr}\sberdriver.exe" -Destination $clientpaht -Force  -ErrorAction Stop
    Write-Host "Файл sberdriver.exe успешно скопирован в $clientpaht" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при копировании: $($_.Exception.Message)" -ForegroundColor Red
}

###################################################################################


################## установка RDS Windows Feature c перезагрузкой ##################
#подразумевается что на сервере не установлены никакие роли RDS
$roles = @("RDS-RD-SERVER", "RDS-CONNECTION-BROKER", "RDS-WEB-ACCESS")
$result = (Get-WindowsFeature -Name $roles | select Installed).Installed
if (!($result[0])) {
    Install-WindowsFeature -Name $roles -IncludeAllSubFeature -Restart
    Exit
}else { 
    Write-Host "Роли RDS уже установлены" -ForegroundColor Green 
}
###################################################################################


$multiLineText = @"
####################
####            ####
####   DEPLOY   ####
####    RDS     ####
####  SERVICES  ####
####            ####
####################

"@

############################### деплой RDS служб ##################################

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

####### указываем сервер лицензий #######
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

###### создаем коллекцию PAM ######
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

####### изменяем группы коллекции на $userGroup #######
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

####### создаем RemoteApp #######
if (!(Get-RDRemoteApp -DisplayName $displayName)){
    try {
        Write-Host "Создаем RemoteApp приложение: `"$displayName`" `n" 
###!!!!!!!!!!!!!! New-RDRemoteApp -CollectionName "PAM" -DisplayName $displayName -FilePath $pathInstalledProgram -ErrorAction Stop | Out-Null
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

######## Настройка Endpoint клиента в реестре ########
$regKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WorkerEndpointClient.exe"
if (-not (Test-Path -Path $regKeyPath)) {
    New-Item -Path $regKeyPath -Force | Out-Null
    Write-Host "Ключ реестра создан: $regKeyPath" -ForegroundColor Green
    Start-Sleep 1
} else {
    Write-Host "Ключ реестра уже существует: $regKeyPath" -ForegroundColor Yellow
    Start-Sleep 1
}

Set-ItemProperty -Path $regKeyPath -Name "(Default)" -Value $pathInstalledProgram
Write-Host "Параметр (Default) установлен: $pathInstalledProgram" -ForegroundColor Green
Start-Sleep 1

Set-ItemProperty -Path $regKeyPath -Name "Path" -Value $programFolder -Type ExpandString
Write-Host "Параметр Path установлен: $programFolder" -ForegroundColor Green
Start-Sleep 1
#######################################################

########### Корретировка групповых политик через реестр ###########
$HKLMPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$HKCUPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $HKLMPath -Name "KeepAliveEnable" -Value 1
Write-Host "KeepAliveEnable = 1" -ForegroundColor Green
Start-Sleep 1
Set-ItemProperty -Path $HKLMPath -Name "KeepAliveInterval" -Value 60
Write-Host "KeepAliveInterval = 60" -ForegroundColor Green
Start-Sleep 1 
Set-ItemProperty -Path $HKLMPath -Name "MaxInstanceCount" -Value 999999
Write-Host "MaxInstanceCount = 999999" -ForegroundColor Green
Start-Sleep 1 
Set-ItemProperty -Path $HKLMPath -Name "fSingleSessionPerUser" -Value 0
Write-Host "fSingleSessionPerUser = 0" -ForegroundColor Green
Start-Sleep 1 
if (!(Test-Path $HKCUPath)){ New-Item -Path $HKCUPath }
Set-ItemProperty -Path $HKCUPath -Name "DisableLockWorkstation" -Value 1
Write-Host "DisableLockWorkstation = 1" -ForegroundColor Green
Start-Sleep 1 
####################################################################



Write-Host "Установка завершена. Нажмите Enter и перезагрузите компьютер"
Read-Host
Restart-Computer -Confirm:$true