function Get-1CModuleHelp {
    <#
    .SYNOPSIS
        Отображает справку по модулю 1CMgmt.
    .DESCRIPTION
        Выводит содержимое README.md из корня модуля.
        Если файл отсутствует — предлагает воспользоваться Get-Help для отдельных функций.
    #>
    Write-Host "Справка по модулю 1CMgmt" -ForegroundColor Green -BackgroundColor Black

    $moduleBase = $MyInvocation.MyCommand.Module.ModuleBase
    $readmePath = Join-Path $moduleBase 'README.md'

    if (Test-Path $readmePath) {
        Get-Content $readmePath -Raw
    }
    else {
        Write-Host "README.md не найден в каталоге модуля." -ForegroundColor Yellow
    }

    Write-Host "`nДля получения справки по отдельной функции используйте:" -ForegroundColor Green
    Write-Host "Get-Help <Имя функции> -Detailed" -ForegroundColor Green
}