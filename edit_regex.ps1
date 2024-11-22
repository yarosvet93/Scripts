
$HKLMPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$HKCUPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $HKLMPath -Name "KeepAliveEnable" -Value 1
Set-ItemProperty -Path $HKLMPath -Name "KeepAliveInterval" -Value 60
Set-ItemProperty -Path $HKLMPath -Name "MaxInstanceCount" -Value 999999
Set-ItemProperty -Path $HKLMPath -Name "fSingleSessionPerUser" -Value 0
if (!(Test-Path $HKCUPath)){ New-Item -Path $HKCUPath }
Set-ItemProperty -Path $HKCUPath -Name "DisableLockWorkstation" -Value 1

