try {
    Start-Process notepad.exe # -ErrorAction Stop
    Write-Host "Программа установлена успешно." -ForegroundColor Green
} catch {
    Write-Host "Ошибка при установке: $_" -ForegroundColor Red
    Write-Host "нажмите Enter чтобы выйти"
    Read-Host
    exit 1
}