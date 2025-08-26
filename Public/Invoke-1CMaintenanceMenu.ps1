function Invoke-1CMaintenanceMenu {
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
        @{ Key = "0"; Text = "Сжатие журналов регистрации. `n    Параметры по умолчанию: `n     -архивировать файлы старше 7 дней; `n     -удалить архивы старше 90 дней."; Action ={ Compress-1Clogs } },
        @{ Key = "1"; Text = "Установленные версии 1C"; Action = { Get-1CInstalledVersion } },
        @{ Key = "2"; Text = "Проверка зависимостей модуля"; Action = { Test-1CModuleDependency } },
        @{ Key = "3"; Text = "Установка сервера 1C"; Action = { Install-1CServer } },
        @{ Key = "4"; Text = "Обновление сервера 1C"; Action = { Install-1CPlatform} },
        @{ Key = "r"; Text = "Возврат в основное меню"; Action = { Invoke-1CMenu } },
        @{ Key = "q"; Text = "Exit"; Action = { exit } }
    )

    # Вывод заголовка и пунктов меню
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Меню обслуживания сервера 1С" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue

    foreach ($item in $menuItems) {
        Write-Host ("{0}. {1}" -f $item.Key, $item.Text) -ForegroundColor Green
        Write-Host $separator -ForegroundColor Blue
    }
    Write-Host

    # Обработка пользовательского ввода
    while ($true) {
        $choice = Read-Host "Выберите действие (r - возврат в меню)"
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
