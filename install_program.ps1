
function Write-Success {
    Write-Host "######### success ########`n" -ForegroundColor Green
}

$programs = @(
    @{
        Name = "VC_redist.x64";
        Path = "C:\Distr\VC_redist.x64 2019 (16.9)_14.28.29.exe";
        Args = "/install /quiet"
    },
    @{
        Name = "EndpointService";
        Path = "C:\Distr\EndpointService.msi";
        Args = "/quiet"
    },
    @{
        Name = "EndpointClient";
        Path = "C:\Distr\EndpointClient.msi";
        Args = "/quiet"
    },
    @{
        Name = "dbeaver-ce-23.3.3-x86_64";
        Path = "C:\Distr\dbeaver-ce-23.3.3-x86_64-setup.exe";
        Args = "/allusers /S"
    },
    @{
        Name = "SberBrowser-win-x86";
        Path = "C:\Distr\SberBrowser-win-x86-distrib.exe";
        Args = "-system-level"
    }
)

foreach ($program in $programs) {
    try {
        if ($program.Path -match "\.msi$") {
            Write-Host "Установка: $($program.Name)"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($program.Path)`" $($program.Args)" -Wait -ErrorAction Stop
            Write-Success
        } elseif ($program.Path -match "\.exe$") {
            Write-Host "Installing: $($program.Name)"
            Start-Process -FilePath $program.Path -ArgumentList $program.Args -Wait -ErrorAction Stop
            Write-Success
        } else {
            Write-Host "Unknown installer type for $($program.Name)"
        }
    } catch {
        Write-Host "Failed to install $($program.Name): $($_.Exception.Message)"
    }
}

#чтобы не делать проверки при повторном запуске, просто -Force использую 
$clientpaht = 'C:\Program Files\EndpointClient\'
try {
    Copy-Item -Path "${path}autoit-0.0.11\*" -Destination $clientpaht -Force
    Write-Host "Файлы из autoit-0.0.11 успешно скопированы в $clientpaht"
    Copy-Item -Path "${path}sberdriver.exe" -Destination $clientpaht -Force
    Write-Host "Файл sberdriver.exe успешно скопирован в $clientpaht"
} catch {
    Write-Host "Ошибка при копировании: $($_.Exception.Message)"
}


