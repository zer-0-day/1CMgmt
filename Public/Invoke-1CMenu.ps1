function Invoke-1CMenu {
    <#
    .SYNOPSIS
        Основное меню модуля 1C-Server-Management.
    .DESCRIPTION
        Отображает список доступных функций модуля 1CMgmt.
    .EXAMPLE
        Get-1CMenu
    #>
    
    Clear-Host

    # Определяем разделитель и массив пунктов меню
    $separator = "-----------------------------------------------"
    $menuItems = @(
        @{ Key = "0"; Text = "Функции модуля 1CMgmt"; Action = { Get-1CModuleHelp } },
        @{ Key = "1"; Text = "Меню обслуживания сервера 1С"; Action = { Invoke-1CMaintenanceMenu} },
        @{ Key = "t"; Text = "Меню управления задачами в планировщике Windows"; Action = { Invoke-1CTaskMenu } },
        @{ Key = "r"; Text = "Возврат в меню"; Action = { Invoke-1CMenu } },
        @{ Key = "q"; Text = "Exit"; Action = { exit } }
    )

    # Вывод заголовка и пунктов меню
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Модуль 1CMgmt" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Проверка зависимостей модуля"
    Test-1CModuleDependency
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Проверка завершена"
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Основное меню модуля 1CMgmt" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue
    
    foreach ($item in $menuItems) {
        Write-Host ("{0}. {1}" -f $item.Key, $item.Text) -ForegroundColor Green
        Write-Host $separator -ForegroundColor Blue
    }
    Write-Host

    # Обработка пользовательского ввода
    while ($true) {
        $choice = Read-Host "Выберите действие (r - возврат в основное меню, q - выход)"
        $selected = $menuItems | Where-Object { $_.Key -eq $choice }
        if ($selected) {
            # Выполнение ассоциированного блока
            & $selected.Action
        }
        else {
            Write-Host "Неверный выбор, попробуйте снова." -ForegroundColor Red
        }
    }
    
}
