function Invoke-1CMaintenanceMenu {
    <#
    .SYNOPSIS
        Меню обслуживания и установки 1C (1CMgmt).
    .DESCRIPTION
        Интерактивное меню с подменю для установки сервера 1С, обновления платформы/сервера,
        задач авто-апгрейда, проверки зависимостей и обслуживания. Ввод параметров делается через Read-Host.
        Используется switch и try/catch для обработки пользовательского ввода и ошибок.
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
        # r / R / русская «к» от раскладки / слова назад/return
        $v = ($val ?? '').Trim()
        return ($v -match '^(?i:r|назад|back|return)$')
    }

    function Invoke-InstallMenu {
        while ($true) {
            Show-Header "Установка сервера 1С"
            Write-Host "Подсказка: параметры Version и PortPrefix необязательны. Если не указаны — будет использована последняя найденная версия и портовая схема 15* (current)." -ForegroundColor DarkGray
            Write-Host "1. Быстрая установка (по умолчанию: последняя версия, порты 15*)" -ForegroundColor Green
            Write-Host "2. Установка с параметрами (SetupPath / PortPrefix / Version; Version/PortPrefix — необяз.)" -ForegroundColor Green
            Write-Host "r. Назад" -ForegroundColor Green

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
                        Write-Host ("Install-1CServer {0}" -f ((($splat.GetEnumerator() | ForEach-Object { "-{0} `"$($splat[$_])`"" -f $_.Key }) -join ' '))) -ForegroundColor Cyan
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
            Write-Host "1. Обновить current (по умолчанию, порты 15*)" -ForegroundColor Green
            Write-Host "2. Обновить с параметрами (SetupPath / PortPrefix; PortPrefix — необяз.)" -ForegroundColor Green
            Write-Host "r. Назад" -ForegroundColor Green

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
                        Write-Host ("Start-1CServerUpgrade {0}" -f ((($splat.GetEnumerator() | ForEach-Object { "-{0} `"$($splat[$_])`"" -f $_.Key }) -join ' '))) -ForegroundColor Cyan
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
            Write-Host "r. Назад" -ForegroundColor Green

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
        Write-Host "q. Выход" -ForegroundColor Green

        $choice = (Read-Host "Выберите действие").Trim()
        if ($choice -match '^(?i:q|quit|exit)$') { return }

        switch ($choice) {
            '0' { try { Compress-1Clogs } catch { Write-Host $_ -ForegroundColor Red } }
            '1' { try { Get-1CInstalledVersion | Format-Table -AutoSize | Out-Host } catch { Write-Host $_ -ForegroundColor Red } }
            '2' { try { Test-1CModuleDependency | Out-Host } catch { Write-Host $_ -ForegroundColor Red } }
            '3' { Invoke-InstallMenu }
            '4' { Invoke-UpgradeMenu }
            '5' { Invoke-AutoUpgradeTaskMenu }
            '6' { try { Get-1CModuleHelp } catch { Write-Host $_ -ForegroundColor Red } }
            '7' { try { Update-Module1CMgmt } catch { Write-Host $_ -ForegroundColor Red } }
            default { Write-Host "Неверный выбор, попробуйте снова." -ForegroundColor Yellow }
        }
    }
}