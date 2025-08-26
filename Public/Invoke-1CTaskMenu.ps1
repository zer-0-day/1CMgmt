function Invoke-1CTaskMenu {
    <#
    .SYNOPSIS
        Дополнительное меню модуля 1C-Server-Management. Создание задач в планировщике
    .DESCRIPTION
        Отображает список задач создания задач в планировщике Windows.
    .EXAMPLE
        Get-TaskMenu
    #>
    
    Clear-Host

    # Определяем разделитель и массив пунктов меню
    $separator = "-----------------------------------------------"
    $menuItems = @(
        @{ Key = "0"; Text = "Создать задачу архивации журналов регистрации. `n    Параметры по умолчанию: `n     -время запуска:05:00; `n     -хранение файлов: 7 дней; `n     -хранение архивов: 90 дней."; Action = { New-1CDefaultCompressTask } },
        @{ Key = "1"; Text = "Создать задачу архивации журналов регистрации со своими параметрами. `n    При запуске требуется ввести: `n     -периорд хранение файлов ЖР (дней); `n     -период хранение архивов ЖР(дней); `n     -время запуска задачи."; Action = { New-1CCustomCompressTask } },
        @{ Key = "r"; Text = "Возврат в основное меню"; Action = { Invoke-1CMenu } },
        @{ Key = "q"; Text = "Exit"; Action = { exit } }
    )

    # Вывод заголовка и пунктов меню
    Write-Host $separator -ForegroundColor Blue
    Write-Host "Список функций модуля 1CMgmt" -ForegroundColor Green
    Write-Host $separator -ForegroundColor Blue

    foreach ($item in $menuItems) {
        Write-Host ("{0}. {1}" -f $item.Key, $item.Text) -ForegroundColor Green
        Write-Host $separator -ForegroundColor Blue
    }
    Write-Host

    # Обработка пользовательского ввода
    while ($true) {
        $choice = Read-Host "Выберите действие"
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
