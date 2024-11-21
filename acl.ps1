# Указываем путь к папке
$Path = "C:\Program Files\EndpointService"

# 1. Отключаем наследование и конвертируем унаследованные права в явные
Write-Output "Disabling inheritance and converting inherited permissions..."
$acl = Get-Acl $Path
$acl.SetAccessRuleProtection($true, $true) # Отключить наследование, сохранить существующие правила
Set-Acl -Path $Path -AclObject $acl

# 2. Удаляем группу Users
Write-Output "Removing 'Users' group permissions..."
$acl = Get-Acl $Path
$acl.Access | Where-Object { $_.IdentityReference -like "*\Users" } | ForEach-Object {
    $acl.RemoveAccessRule($_)
}
Set-Acl -Path $Path -AclObject $acl

# 3. Добавляем права для LOCAL SERVICE
Write-Output "Adding 'LOCAL SERVICE' permissions..."
$acl = Get-Acl $Path
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("LOCAL SERVICE", "Modify, ReadAndExecute, ListDirectory, Read, Write", "ContainerInherit, ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $Path -AclObject $acl

# 4. Применяем права ко всем дочерним объектам
Write-Output "Applying permissions to child objects..."
$acl = Get-Acl $Path
$acl.SetAccessRuleProtection($true, $false) # Заменить разрешения дочерних объектов
Set-Acl -Path $Path -AclObject $acl

Write-Output "Permissions configured successfully."
