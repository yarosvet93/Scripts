Get-VM pam-rds01 | Stop-VM -TurnOff -Force
Get-VM pam-rds01 | Remove-VM -Force
Remove-Item -Path "C:\HyperV\pam-rds01" -Recurse -Force
Copy-Item -Path "F:\Hyper-V\PAM\pam-rds01" -Destination "C:\HyperV" -Recurse
Import-VM -Path "C:\HyperV\pam-rds01\Virtual Machines\A8AAD80C-DB69-489A-B7A0-5A220B751443.vmcx" -Register
Get-VM pam-rds01 | Start-VM