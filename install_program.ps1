function Write-Success {
    Write-Host "######### success ########`n" -ForegroundColor Green
}
$pathDistr = 'C:\Distr'

$programs = @(
    @{
        Name = "VC_redist.x64";
        Path = "${pathDistr}\VC_redist.x64 2019 (16.9)_14.28.29.exe";
        Args = "/install /quiet"
        Check = {Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Microsoft Visual C*2019*" }}
    },
    @{
        Name = "EndpointService";
        Path = "${pathDistr}\EndpointService.msi";
        Args = "/quiet"
        Check = {Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "EndpointService" }}
    },
    @{
        Name = "EndpointClient";
        Path = "${pathDistr}\EndpointClient.msi";
        Args = "/quiet"
        Check = {Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "EndpointClient" }}
    },
    @{
        Name = "dbeaver-ce-23.3.3-x86_64";
        Path = "${pathDistr}\dbeaver-ce-23.3.3-x86_64-setup.exe";
        Args = "/allusers /S"
        Check = {Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "DBeaver*" }}
    },
    @{
        Name = "SberBrowser-win-x86";
        Path = "${pathDistr}\SberBrowser-win-x86-distrib.exe";
        Args = "-system-level"
        Check = {Test-Path "C:\Program Files (x86)\SberBrowser\Application\sberbrowser.exe"}
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
$clientpaht = 'C:\Program Files\EndpointClient\'
try {
    Copy-Item -Path "${pathDistr}\autoit-0.0.11\*" -Destination $clientpaht -Force -ErrorAction Stop
    Write-Host "Файлы из autoit-0.0.11 успешно скопированы в $clientpaht"
    Copy-Item -Path "${pathDistr}\sberdriver.exe" -Destination $clientpaht -Force -ErrorAction Stop
    Write-Host "Файл sberdriver.exe успешно скопирован в $clientpaht" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при копировании: $($_.Exception.Message)" -ForegroundColor Red
}


