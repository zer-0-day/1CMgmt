function Invoke-1CMenu {
    <#
    .SYNOPSIS
        Основное меню модуля 1CMgmt: быстрый доступ к справке, обслуживанию и задачам планировщика.
    .DESCRIPTION
        Лаконичное меню: Справка → Обслуживание → Задачи (ЖР/автоапгрейд) → Выход.
    .EXAMPLE
        Invoke-1CMenu
    #>
    
    Clear-Host

    # Определяем разделитель и массив пунктов меню
    $separator = "-----------------------------------------------"
    $menuItems = @(
        @{ Key = "0"; Text = "Справка по модулю"; Action = { Get-1CModuleHelp } },
        @{ Key = "1"; Text = "Обслуживание сервера 1С"; Action = { Invoke-1CMaintenanceMenu } },
        @{ Key = "2"; Text = "Задачи планировщика (ЖР и автоапгрейд)"; Action = { Invoke-1CTaskMenu } },
        @{ Key = "3"; Text = "Быстрый апгрейд current (запустить сейчас)"; Action = { Start-1CServerUpgrade } },
        @{ Key = "q"; Text = "Выход"; Action = { exit } }
    )

    # Вывод заголовка и пунктов меню
    Write-Host $separator -ForegroundColor Blue
    Write-Host "1CMgmt — основное меню" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Проверка зависимостей..." -NoNewline
    Test-1CModuleDependency | Out-Null
    Write-Host " ok" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue
    
    foreach ($item in $menuItems) {
        Write-Host ("{0}. {1}" -f $item.Key, $item.Text) -ForegroundColor Green
        Write-Host $separator -ForegroundColor Blue
    }
    Write-Host

    # Обработка пользовательского ввода
    while ($true) {
        $choice = Read-Host "Выберите действие (q — выход)"
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