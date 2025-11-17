# Эта функция больше не используется.
# Весь функционал перенесён в Invoke-1CMenu.
# Файл оставлен для обратной совместимости.

function Invoke-1CTaskMenu {
    <#
    .SYNOPSIS
        Устаревшая функция. Используйте Invoke-1CMenu.
    .DESCRIPTION
        Эта функция больше не используется. Весь функционал перенесён в упрощённое главное меню.
        Вызов перенаправляется на Invoke-1CMenu.
    .EXAMPLE
        Invoke-1CTaskMenu
    #>
    
    Write-Host "Функция Invoke-1CTaskMenu устарела." -ForegroundColor Yellow
    Write-Host "Перенаправление на главное меню..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Invoke-1CMenu
}
