
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
            Write-Host "Installing MSI: $($program.Name)"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($program.Path)`" $($program.Args)" -Wait -ErrorAction Stop
        } elseif ($program.Path -match "\.exe$") {
            Write-Host "Installing EXE: $($program.Name)"
            Start-Process -FilePath $program.Path -ArgumentList $program.Args -Wait -ErrorAction Stop
        } else {
            Write-Host "Unknown installer type for $($program.Name)"
        }
    } catch {
        Write-Host "Failed to install $($program.Name): $($_.Exception.Message)"
    }
}

Copy-Item C:\Distr\autoit-0.0.11\* 'C:\Program Files\EndpointClient\'
Copy-Item C:\Distr\sberdriver.exe 'C:\Program Files\EndpointClient\'