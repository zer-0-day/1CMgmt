function Invoke-1CTaskMenu {
    <#
    .SYNOPSIS
        Дополнительное меню модуля 1CMgmt. Создание задач в планировщике: архивация ЖР и автоапгрейд current/CurrentXX.
    .DESCRIPTION
        Отображает список действий по созданию задач в Планировщике Windows: архивация журналов регистрации и автоапгрейд сервера 1С (ветка current и инстансы CurrentXX).
    .EXAMPLE
        Invoke-1CTaskMenu
    #>

    Clear-Host

    # Определяем разделитель и массив пунктов меню
    $separator = "-----------------------------------------------"
    $menuItems = @(
        @{ Key = "0"; Text = "Создать задачу архивации журналов регистрации. `n    Параметры по умолчанию: `n     -время запуска:05:00; `n     -хранение файлов: 7 дней; `n     -хранение архивов: 90 дней."; Action = { New-1CDefaultCompressTask } },
        @{ Key = "1"; Text = "Создать задачу архивации журналов регистрации со своими параметрами. `n    При запуске требуется ввести: `n     -периорд хранение файлов ЖР (дней); `n     -период хранение архивов ЖР(дней); `n     -время запуска задачи."; Action = { New-1CCustomCompressTask } },
        @{ Key = "2"; Text = "Создать задачу автоапгрейда current. `n    Будет выполнено: Start-1CServerUpgrade (перезапуск только 'Current'). `n    При запуске потребуется ввести: `n     -учётную запись (DOMAIN\\user); `n     -время запуска (HH:mm, по умолчанию 03:30); `n     -необязательный путь -SetupPath (папка версии или общий корень с архивами); `n     -оболочку (WindowsPowerShell/PowerShell7, по умолчанию WindowsPowerShell)."; Action = {
                $at    = Read-Host "Время запуска (HH:mm) [по умолчанию 03:30]"
                if ([string]::IsNullOrWhiteSpace($at)) { $at = '03:30' }
                $user  = Read-Host "Учётная запись (DOMAIN\\user)"
                $setup = Read-Host "Путь к дистрибутивам (опционально, можно оставить пусто)"
                $shell = Read-Host "Оболочка (WindowsPowerShell/PowerShell7) [по умолчанию WindowsPowerShell]"
                if ([string]::IsNullOrWhiteSpace($shell)) { $shell = 'WindowsPowerShell' }

                if ([string]::IsNullOrWhiteSpace($user)) {
                    Write-Host "Учётная запись не указана." -ForegroundColor Red
                }
                else {
                    if ([string]::IsNullOrWhiteSpace($setup)) {
                        New-1CServerAutoUpgradeTask -RunAsUser $user -At $at -Shell $shell
                    } else {
                        New-1CServerAutoUpgradeTask -RunAsUser $user -At $at -Shell $shell -SetupPath $setup
                    }
                }
            } },
        @{ Key = "3"; Text = "Создать задачи автоапгрейда CurrentXX (например current25/current35). `n    Будет выполнено: Start-1CServerUpgrade -PortPrefix <XX> (перезапуск 'CurrentXX'). `n    При запуске потребуется ввести: `n     -список префиксов портов (через запятую, например: 25,35); `n     -учётную запись (DOMAIN\\user); `n     -время запуска (HH:mm, по умолчанию 03:30); `n     -необязательный путь -SetupPath (папка версии или общий корень с архивами); `n     -оболочку (WindowsPowerShell/PowerShell7, по умолчанию WindowsPowerShell)."; Action = {
                $ppRaw = Read-Host "Введите префиксы портов (через запятую, напр.: 25,35)"
                $ppList = $ppRaw -split '\s*,\s*' | Where-Object { $_ -match '^\d{2}$' } | ForEach-Object { [int]$_ }
                if (-not $ppList -or $ppList.Count -eq 0) {
                    Write-Host "Не указаны корректные префиксы портов." -ForegroundColor Red
                    return
                }

                $at    = Read-Host "Время запуска (HH:mm) [по умолчанию 03:30]"
                if ([string]::IsNullOrWhiteSpace($at)) { $at = '03:30' }
                $user  = Read-Host "Учётная запись (DOMAIN\\user)"
                $setup = Read-Host "Путь к дистрибутивам (опционально, можно оставить пусто)"
                $shell = Read-Host "Оболочка (WindowsPowerShell/PowerShell7) [по умолчанию WindowsPowerShell]"
                if ([string]::IsNullOrWhiteSpace($shell)) { $shell = 'WindowsPowerShell' }

                if ([string]::IsNullOrWhiteSpace($user)) {
                    Write-Host "Учётная запись не указана." -ForegroundColor Red
                }
                else {
                    if ([string]::IsNullOrWhiteSpace($setup)) {
                        New-1CServerAutoUpgradeTask -RunAsUser $user -At $at -Shell $shell -PortPrefix $ppList
                    } else {
                        New-1CServerAutoUpgradeTask -RunAsUser $user -At $at -Shell $shell -SetupPath $setup -PortPrefix $ppList
                    }
                }
            } },
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
            & $selected.Action
        }
        else {
            Write-Host "Неверный выбор, попробуйте снова." -ForegroundColor Red
        }
    }
}