
# Переменные
$CertPath = "C:\Program Files\EndpointService\fetchCerts\CI04801419PROM_RDS-*.p12" # Путь к p12-файлу
$PasswordPath = "C:\Program Files\EndpointService\fetchCerts\password.txt" # Путь к файлу с паролем
$TrustedRootStore = "Cert:\LocalMachine\Root" # Доверенные корневые центры сертификации
$PersonalStore = "Cert:\LocalMachine\My" # Личное хранилище сертификатов

# Чтение пароля из файла
$Password = Get-Content -Path $PasswordPath | Out-String
$SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

# Установка CA-бандла в Trusted Root Certification Authorities
Write-Output "Installing CA bundle to Trusted Root Certification Authorities..."
Import-Certificate -FilePath "C:\Program Files\EndpointService\ca-bundle.crt" -CertStoreLocation $TrustedRootStore

# Импорт закрытого p12 сертификата в личное хранилище
Write-Output "Importing private p12 certificate into Personal store..."
$PfxCert = Import-PfxCertificate -FilePath $CertPath -CertStoreLocation $PersonalStore -Password $SecurePassword

if ($PfxCert) {
    Write-Output "Certificate imported successfully."
} else {
    Write-Output "Failed to import certificate."
}

# Проверка установки сертификата
Write-Output "Verifying certificates in the Personal store..."
Get-ChildItem -Path $PersonalStore

#CI04801419PROM_RDS-*.p12