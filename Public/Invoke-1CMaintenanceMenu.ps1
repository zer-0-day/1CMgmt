# Эта функция больше не используется.
# Весь функционал перенесён в Invoke-1CMenu.
# Файл оставлен для обратной совместимости.

function Invoke-1CMaintenanceMenu {
    <#
    .SYNOPSIS
        Устаревшая функция. Используйте Invoke-1CMenu.
    .DESCRIPTION
        Эта функция больше не используется. Весь функционал перенесён в упрощённое главное меню.
        Вызов перенаправляется на Invoke-1CMenu.
    .EXAMPLE
        Invoke-1CMaintenanceMenu
    #>
    
    Write-Host "Функция Invoke-1CMaintenanceMenu устарела." -ForegroundColor Yellow
    Write-Host "Перенаправление на главное меню..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Invoke-1CMenu
}
