function Invoke-1CMaintenanceMenu {
    <#
    .SYNOPSIS
        Меню обслуживания и установки 1C (1CMgmt).
    .DESCRIPTION
        Интерактивное меню с подменю для:
        • установки сервера 1С (по умолчанию или с параметрами),
        • обновления платформы/сервера (current или с префиксом портов),
        • задач авто-апгрейда,
        • проверки зависимостей и просмотра версий,
        • вспомогательных действий (поиск дистрибутива, создание ссылки),
        • а также вызова справки и обновления модуля.
        Ввод параметров через Read-Host. В подменю всегда можно вернуться
        в основное меню («r» или «назад»).
    .EXAMPLE
        Invoke-1CMaintenanceMenu
    .NOTES
        Требуется PowerShell 5.1/7+, модуль 1CMgmt должен быть загружен.
    #>

    Clear-Host

    function Show-Header([string]$Title) {
        $sep = '-' * 55
        Write-Host $sep -ForegroundColor Blue
        Write-Host $Title -ForegroundColor Green
        Write-Host $sep -ForegroundColor Blue
    }

    function Read-PortPrefixOptional {
        # Enter — использовать порты 15* (служба current)
        $pp = Read-Host "Префикс портов (две цифры, напр. 25). Enter — использовать порты 15* (current)"
        if ([string]::IsNullOrWhiteSpace($pp)) { return $null }
        if ($pp -notmatch '^[0-9]{2}$') {
            Write-Host "Неверный формат. Ожидались две цифры (напр. 25)." -ForegroundColor Yellow
            return $null
        }
        return [int]$pp
    }

    function Wait-Enter($msg = 'Готово. Enter — продолжить') { Read-Host $msg | Out-Null }

    function Is-Back($val) {
        # Совместимо с PowerShell 5.1 (без оператора ??)
        $v = if ($null -eq $val) { '' } else { $val }
        $v = $v.Trim()
        return ($v -match '^(?i:r|назад|back|return)$')
    }

    function Invoke-InstallMenu {
        while ($true) {
            Show-Header "Установка сервера 1С"
            Write-Host "Подсказка: параметры Version и PortPrefix необязательны. Если не указаны — будет использована последняя найденная версия и портовая схема 15* (current)." -ForegroundColor DarkGray
            Write-Host "1. Быстрая установка (последняя версия, порты 15*)" -ForegroundColor Green
            Write-Host "2. Установка с параметрами (SetupPath / PortPrefix / Version)" -ForegroundColor Green
            Write-Host "r. Назад в основное меню" -ForegroundColor Green

            $c = (Read-Host "Выбор").Trim()
            if (Is-Back $c) { break }

            switch ($c) {
                '1' {
                    try {
                        Write-Host "Запуск: Install-1CServer" -ForegroundColor Cyan
                        Install-1CServer
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                '2' {
                    $setup = Read-Host "SetupPath (UNC или локальный). Enter — пропустить"
                    if (Is-Back $setup) { continue }
                    $pp    = Read-PortPrefixOptional
                    $ver   = Read-Host "Version (напр. 8.3.22.1704). Enter — последняя найденная"
                    if (Is-Back $ver) { continue }

                    $splat = @{}
                    if ($setup) { $splat.SetupPath  = $setup }
                    if ($pp)    { $splat.PortPrefix = $pp }
                    if ($ver)   { $splat.Version    = $ver }

                    try {
                        Write-Host ("Install-1CServer {0}" -f ( ($splat.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join ' ' )) -ForegroundColor Cyan
                        Install-1CServer @splat
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                default { Write-Host "Неверный выбор" -ForegroundColor Yellow }
            }
        }
    }

    function Invoke-UpgradeMenu {
        while ($true) {
            Show-Header "Обновление сервера 1С"
            Write-Host "Подсказка: без параметров обновляется служба 'current' (порты 15*). В режиме с параметрами PortPrefix — необязателен." -ForegroundColor DarkGray
            Write-Host "1. Обновить current (порты 15*)" -ForegroundColor Green
            Write-Host "2. Обновить с параметрами (SetupPath / PortPrefix)" -ForegroundColor Green
            Write-Host "r. Назад в основное меню" -ForegroundColor Green

            $c = (Read-Host "Выбор").Trim()
            if (Is-Back $c) { break }

            switch ($c) {
                '1' {
                    try {
                        Write-Host "Запуск: Start-1CServerUpgrade" -ForegroundColor Cyan
                        Start-1CServerUpgrade
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                '2' {
                    $setup = Read-Host "SetupPath (UNC/локальный). Enter — пропустить"
                    if (Is-Back $setup) { continue }
                    $pp    = Read-PortPrefixOptional

                    $splat = @{}
                    if ($setup) { $splat.SetupPath  = $setup }
                    if ($pp)    { $splat.PortPrefix = $pp }

                    try {
                        Write-Host ("Start-1CServerUpgrade {0}" -f ( ($splat.GetEnumerator() | ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join ' ' )) -ForegroundColor Cyan
                        Start-1CServerUpgrade @splat
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                default { Write-Host "Неверный выбор" -ForegroundColor Yellow }
            }
        }
    }

    function Invoke-AutoUpgradeTaskMenu {
        while ($true) {
            Show-Header "Задача авто-апгрейда сервера"
            Write-Host "1. Создать задачу для current" -ForegroundColor Green
            Write-Host "2. Создать задачу для currentXX (по PortPrefix)" -ForegroundColor Green
            Write-Host "r. Назад в основное меню" -ForegroundColor Green

            $c = (Read-Host "Выбор").Trim()
            if (Is-Back $c) { break }

            switch ($c) {
                '1' {
                    try {
                        New-1CServerAutoUpgradeTask
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                '2' {
                    $pp = Read-PortPrefixOptional
                    $splat = @{}
                    if ($pp) { $splat.PortPrefix = $pp }
                    try {
                        New-1CServerAutoUpgradeTask @splat
                        Wait-Enter
                    } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" }
                }
                default { Write-Host "Неверный выбор" -ForegroundColor Yellow }
            }
        }
    }

    function Invoke-HelperMenu {
        while ($true) {
            Show-Header "Вспомогательные действия"
            Write-Host "1. Найти дистрибутив (Find-1CDistroFolder)" -ForegroundColor Green
            Write-Host "2. Создать ссылку на текущую платформу (New-1CCurrentPlatformLink)" -ForegroundColor Green
            Write-Host "r. Назад в основное меню" -ForegroundColor Green

            $c = (Read-Host "Выбор").Trim()
            if (Is-Back $c) { break }

            switch ($c) {
                '1' { try { Find-1CDistroFolder | Out-Host; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" } }
                '2' { try { New-1CCurrentPlatformLink; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red; Wait-Enter "Ошибка. Enter — назад" } }
                default { Write-Host "Неверный выбор" -ForegroundColor Yellow }
            }
        }
    }

    while ($true) {
        Show-Header "Меню обслуживания сервера 1С"
        Write-Host "0. Сжать журналы регистрации" -ForegroundColor Green
        Write-Host "1. Показать установленные версии" -ForegroundColor Green
        Write-Host "2. Проверить зависимости модуля" -ForegroundColor Green
        Write-Host "3. Установка сервера (подменю)" -ForegroundColor Green
        Write-Host "4. Обновление сервера (подменю)" -ForegroundColor Green
        Write-Host "5. Авто-апгрейд (задача)" -ForegroundColor Green
        Write-Host "6. Справка (README)" -ForegroundColor Green
        Write-Host "7. Обновить модуль 1CMgmt" -ForegroundColor Green
        Write-Host "8. Вспомогательные действия (подменю)" -ForegroundColor Green
        Write-Host "q. Выход" -ForegroundColor Green

        $choice = (Read-Host "Выберите действие").Trim()
        if ($choice -match '^(?i:q|quit|exit)$') { return }

        switch ($choice) {
            '0' { try { Compress-1Clogs; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red } }
            '1' { try { Get-1CInstalledVersion | Format-Table -AutoSize | Out-Host; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red } }
            '2' { try { Test-1CModuleDependency | Out-Host; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red } }
            '3' { Invoke-InstallMenu }
            '4' { Invoke-UpgradeMenu }
            '5' { Invoke-AutoUpgradeTaskMenu }
            '6' { try { Get-1CModuleHelp; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red } }
            '7' { try { Update-Module1CMgmt; Wait-Enter } catch { Write-Host $_ -ForegroundColor Red } }
            '8' { Invoke-HelperMenu }
            default { Write-Host "Неверный выбор, попробуйте снова." -ForegroundColor Yellow }
        }
    }
}