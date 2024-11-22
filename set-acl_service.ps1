$Path = "C:\Program Files\EndpointService"

# Отключаем наследование и сохраняем существующие правила
Write-Output "Disabling inheritance and converting inherited permissions..."
$acl = Get-Acl $Path
$acl.SetAccessRuleProtection($true, $true)
Set-Acl -Path $Path -AclObject $acl

# Удаляем группу Users
Write-Output "Removing 'Users' group permissions..."
$acl = Get-Acl $Path
$acl.Access | Where-Object { $_.IdentityReference -like "*\Users" } | ForEach-Object {
    $acl.RemoveAccessRule($_)
}
Set-Acl -Path $Path -AclObject $acl

# Добавляем права для LOCAL SERVICE
Write-Output "Adding 'LOCAL SERVICE' permissions..."
$acl = Get-Acl $Path
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("LOCAL SERVICE", "Modify, ReadAndExecute, ListDirectory, Read, Write", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $Path -AclObject $acl

# Применяем права ко всем дочерним объектам
Write-Output "Applying permissions to child objects..."
$acl = Get-Acl $Path
$acl.SetAccessRuleProtection($true, $false) # Заменить разрешения дочерних объектов
Set-Acl -Path $Path -AclObject $acl

Write-Output "Permissions configured successfully."
