function Invoke-1CMenu {
    <#
    .SYNOPSIS
        Главное меню модуля 1CMgmt для управления сервером 1С.
    .DESCRIPTION
        Упрощённое главное меню с группировкой по задачам:
        - Установка и обновление
        - Обслуживание
        - Автоматизация
        - Прочее
    .EXAMPLE
        Invoke-1CMenu
    #>

    function Show-MainMenu {
        Clear-Host
        $sep = "=" * 50
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "           1CMgmt — Главное меню" -ForegroundColor Green
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host " УСТАНОВКА И ОБНОВЛЕНИЕ" -ForegroundColor Yellow
        Write-Host "  1. Установить сервер (быстро)" -ForegroundColor White
        Write-Host "  2. Обновить сервер (быстро)" -ForegroundColor White
        Write-Host "  3. Установка с параметрами..." -ForegroundColor White
        Write-Host "  4. Обновление с параметрами..." -ForegroundColor White
        Write-Host ""
        
        Write-Host " ОБСЛУЖИВАНИЕ" -ForegroundColor Yellow
        Write-Host "  5. Сжать журналы регистрации" -ForegroundColor White
        Write-Host "  6. Показать установленные версии" -ForegroundColor White
        Write-Host "  7. Информация о сервере" -ForegroundColor White
        Write-Host ""
        
        Write-Host " АВТОМАТИЗАЦИЯ" -ForegroundColor Yellow
        Write-Host "  8. Настроить автообновление..." -ForegroundColor White
        Write-Host "  9. Настроить архивацию логов..." -ForegroundColor White
        Write-Host ""
        
        Write-Host " ПРОЧЕЕ" -ForegroundColor Yellow
        Write-Host "  h. Справка по модулю" -ForegroundColor White
        Write-Host "  u. Обновить модуль 1CMgmt" -ForegroundColor White
        Write-Host "  q. Выход" -ForegroundColor White
        Write-Host ""
        Write-Host $sep -ForegroundColor Cyan
    }

    function Wait-Continue {
        Write-Host ""
        Read-Host "Нажмите Enter для продолжения" | Out-Null
    }

    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Выберите действие"
        
        try {
            switch ($choice.ToLower()) {
                '1' {
                    Write-Host "`nУстановка сервера с параметрами по умолчанию..." -ForegroundColor Cyan
                    Install-1CServer
                    Wait-Continue
                }
                '2' {
                    Write-Host "`nОбновление сервера current..." -ForegroundColor Cyan
                    Start-1CServerUpgrade
                    Wait-Continue
                }
                '3' {
                    Invoke-InstallMenu
                }
                '4' {
                    Invoke-UpgradeMenu
                }
                '5' {
                    Write-Host "`nСжатие журналов регистрации..." -ForegroundColor Cyan
                    Compress-1Clogs
                    Wait-Continue
                }
                '6' {
                    Write-Host "`nУстановленные версии платформы 1С:" -ForegroundColor Cyan
                    Get-1CInstalledVersion | Format-Table -AutoSize
                    Wait-Continue
                }
                '7' {
                    Write-Host "`nИнформация о сервере 1С:" -ForegroundColor Cyan
                    $info = Get-1C
                    Write-Host "`nПути к srvinfo:" -ForegroundColor Yellow
                    $info.SrvinfoPaths | ForEach-Object { Write-Host "  $_" }
                    if ($info.FileInfoJSON) {
                        Write-Host "`nБазы данных:" -ForegroundColor Yellow
                        $info.FileInfoJSON | ConvertFrom-Json | Format-Table Descr, DB, DBSrvr -AutoSize
                    }
                    Wait-Continue
                }
                '8' {
                    Invoke-AutoUpgradeMenu
                }
                '9' {
                    Invoke-LogArchiveMenu
                }
                'h' {
                    Get-1CModuleHelp
                    Wait-Continue
                }
                'u' {
                    Write-Host "`nОбновление модуля 1CMgmt..." -ForegroundColor Cyan
                    Update-Module1CMgmt
                    Wait-Continue
                }
                'q' {
                    Write-Host "`nДо свидания!" -ForegroundColor Green
                    return
                }
                default {
                    Write-Host "`nНеверный выбор. Попробуйте снова." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-Host "`nОшибка: $_" -ForegroundColor Red
            Wait-Continue
        }
    }
}

function Invoke-InstallMenu {
    <#
    .SYNOPSIS
        Подменю установки сервера с параметрами.
    #>
    
    while ($true) {
        Clear-Host
        $sep = "=" * 50
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "      Установка сервера с параметрами" -ForegroundColor Green
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Параметры установки (все необязательны):" -ForegroundColor Yellow
        Write-Host ""
        
        # Запрос параметров
        Write-Host "SetupPath - путь к дистрибутиву (локальный или UNC)" -ForegroundColor Gray
        $setup = Read-Host "  Enter для пропуска"
        if ($setup -match '^(r|назад|back)$') { return }
        
        Write-Host "`nPortPrefix - префикс портов: 15, 25, 35 и т.д." -ForegroundColor Gray
        $ppInput = Read-Host "  Enter для 15 (current)"
        if ($ppInput -match '^(r|назад|back)$') { return }
        
        Write-Host "`nVersion - версия платформы (например: 8.3.25.1546)" -ForegroundColor Gray
        $ver = Read-Host "  Enter для последней найденной"
        if ($ver -match '^(r|назад|back)$') { return }
        
        # Подтверждение
        Write-Host ""
        Write-Host "Будет выполнено:" -ForegroundColor Yellow
        $cmd = "Install-1CServer"
        if ($setup) { $cmd += " -SetupPath '$setup'" }
        if ($ppInput) { $cmd += " -PortPrefix $ppInput" }
        if ($ver) { $cmd += " -Version '$ver'" }
        Write-Host "  $cmd" -ForegroundColor Cyan
        Write-Host ""
        
        $confirm = Read-Host "Продолжить? (y/n/r-назад)"
        if ($confirm -match '^(r|назад|back)$') { return }
        if ($confirm -ne 'y') { continue }
        
        # Выполнение
        try {
            $splat = @{}
            if ($setup) { $splat.SetupPath = $setup }
            if ($ppInput) { $splat.PortPrefix = $ppInput }
            if ($ver) { $splat.Version = $ver }
            
            Install-1CServer @splat
            Write-Host "`nУстановка завершена!" -ForegroundColor Green
        }
        catch {
            Write-Host "`nОшибка установки: $_" -ForegroundColor Red
        }
        
        Write-Host ""
        $next = Read-Host "Enter-продолжить, r-назад в главное меню"
        if ($next -match '^(r|назад|back)$') { return }
    }
}

function Invoke-UpgradeMenu {
    <#
    .SYNOPSIS
        Подменю обновления сервера с параметрами.
    #>
    
    while ($true) {
        Clear-Host
        $sep = "=" * 50
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "      Обновление сервера с параметрами" -ForegroundColor Green
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Параметры обновления (все необязательны):" -ForegroundColor Yellow
        Write-Host ""
        
        # Запрос параметров
        Write-Host "SetupPath - путь к дистрибутиву (локальный или UNC)" -ForegroundColor Gray
        $setup = Read-Host "  Enter для использования локального кэша"
        if ($setup -match '^(r|назад|back)$') { return }
        
        Write-Host "`nPortPrefix - дополнительные службы для перезапуска" -ForegroundColor Gray
        Write-Host "  (например: 25 или 25,35 для Current25 и Current35)" -ForegroundColor Gray
        $ppInput = Read-Host "  Enter для перезапуска только Current"
        if ($ppInput -match '^(r|назад|back)$') { return }
        
        # Подтверждение
        Write-Host ""
        Write-Host "Будет выполнено:" -ForegroundColor Yellow
        $cmd = "Start-1CServerUpgrade"
        if ($setup) { $cmd += " -SetupPath '$setup'" }
        if ($ppInput) { 
            $ppList = $ppInput -split '\s*,\s*' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            $cmd += " -PortPrefix $($ppList -join ',')" 
        }
        Write-Host "  $cmd" -ForegroundColor Cyan
        Write-Host ""
        
        $confirm = Read-Host "Продолжить? (y/n/r-назад)"
        if ($confirm -match '^(r|назад|back)$') { return }
        if ($confirm -ne 'y') { continue }
        
        # Выполнение
        try {
            $splat = @{}
            if ($setup) { $splat.SetupPath = $setup }
            if ($ppInput) { 
                $ppList = $ppInput -split '\s*,\s*' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                if ($ppList) { $splat.PortPrefix = $ppList }
            }
            
            Start-1CServerUpgrade @splat
            Write-Host "`nОбновление завершено!" -ForegroundColor Green
        }
        catch {
            Write-Host "`nОшибка обновления: $_" -ForegroundColor Red
        }
        
        Write-Host ""
        $next = Read-Host "Enter-продолжить, r-назад в главное меню"
        if ($next -match '^(r|назад|back)$') { return }
    }
}

function Invoke-AutoUpgradeMenu {
    <#
    .SYNOPSIS
        Подменю настройки автоматического обновления.
    #>
    
    while ($true) {
        Clear-Host
        $sep = "=" * 50
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "      Настройка автообновления сервера" -ForegroundColor Green
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Создание задачи в планировщике Windows для" -ForegroundColor Yellow
        Write-Host "автоматического обновления сервера 1С." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Настроить для Current (порты 15xx)" -ForegroundColor White
        Write-Host "  2. Настроить для CurrentXX (другие порты)" -ForegroundColor White
        Write-Host "  r. Назад в главное меню" -ForegroundColor White
        Write-Host ""
        Write-Host $sep -ForegroundColor Cyan
        
        $choice = Read-Host "Выберите действие"
        
        if ($choice -match '^(r|назад|back)$') { return }
        
        switch ($choice) {
            '1' {
                Write-Host "`nНастройка автообновления для Current" -ForegroundColor Cyan
                Write-Host ""
                
                $user = Read-Host "Учётная запись (DOMAIN\user)"
                if ($user -match '^(r|назад|back)$') { continue }
                
                $at = Read-Host "Время запуска (HH:mm) [Enter для 03:30]"
                if ($at -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($at)) { $at = '03:30' }
                
                $setup = Read-Host "Путь к дистрибутивам [Enter для локального кэша]"
                if ($setup -match '^(r|назад|back)$') { continue }
                
                $shell = Read-Host "Оболочка (WindowsPowerShell/PowerShell7) [Enter для WindowsPowerShell]"
                if ($shell -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($shell)) { $shell = 'WindowsPowerShell' }
                
                try {
                    $splat = @{ RunAsUser = $user; At = $at; Shell = $shell }
                    if ($setup) { $splat.SetupPath = $setup }
                    
                    New-1CServerAutoUpgradeTask @splat
                    Write-Host "`nЗадача создана успешно!" -ForegroundColor Green
                }
                catch {
                    Write-Host "`nОшибка: $_" -ForegroundColor Red
                }
                
                Read-Host "`nEnter для продолжения" | Out-Null
            }
            '2' {
                Write-Host "`nНастройка автообновления для CurrentXX" -ForegroundColor Cyan
                Write-Host ""
                
                $ppInput = Read-Host "Префиксы портов через запятую (например: 25,35)"
                if ($ppInput -match '^(r|назад|back)$') { continue }
                
                $ppList = $ppInput -split '\s*,\s*' | Where-Object { $_ -match '^\d{2}$' } | ForEach-Object { [int]$_ }
                if (-not $ppList -or $ppList.Count -eq 0) {
                    Write-Host "Некорректные префиксы портов." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                    continue
                }
                
                $user = Read-Host "Учётная запись (DOMAIN\user)"
                if ($user -match '^(r|назад|back)$') { continue }
                
                $at = Read-Host "Время запуска (HH:mm) [Enter для 03:30]"
                if ($at -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($at)) { $at = '03:30' }
                
                $setup = Read-Host "Путь к дистрибутивам [Enter для локального кэша]"
                if ($setup -match '^(r|назад|back)$') { continue }
                
                $shell = Read-Host "Оболочка (WindowsPowerShell/PowerShell7) [Enter для WindowsPowerShell]"
                if ($shell -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($shell)) { $shell = 'WindowsPowerShell' }
                
                try {
                    $splat = @{ RunAsUser = $user; At = $at; Shell = $shell; PortPrefix = $ppList }
                    if ($setup) { $splat.SetupPath = $setup }
                    
                    New-1CServerAutoUpgradeTask @splat
                    Write-Host "`nЗадачи созданы успешно!" -ForegroundColor Green
                }
                catch {
                    Write-Host "`nОшибка: $_" -ForegroundColor Red
                }
                
                Read-Host "`nEnter для продолжения" | Out-Null
            }
            default {
                Write-Host "`nНеверный выбор." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Invoke-LogArchiveMenu {
    <#
    .SYNOPSIS
        Подменю настройки архивации логов.
    #>
    
    while ($true) {
        Clear-Host
        $sep = "=" * 50
        Write-Host $sep -ForegroundColor Cyan
        Write-Host "      Настройка архивации журналов" -ForegroundColor Green
        Write-Host $sep -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Создание задачи в планировщике Windows для" -ForegroundColor Yellow
        Write-Host "автоматической архивации журналов регистрации." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Быстрая настройка (параметры по умолчанию)" -ForegroundColor White
        Write-Host "     • Время: 05:00" -ForegroundColor Gray
        Write-Host "     • Хранение файлов: 7 дней" -ForegroundColor Gray
        Write-Host "     • Хранение архивов: 90 дней" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Настройка с параметрами" -ForegroundColor White
        Write-Host "  r. Назад в главное меню" -ForegroundColor White
        Write-Host ""
        Write-Host $sep -ForegroundColor Cyan
        
        $choice = Read-Host "Выберите действие"
        
        if ($choice -match '^(r|назад|back)$') { return }
        
        switch ($choice) {
            '1' {
                try {
                    Write-Host "`nСоздание задачи с параметрами по умолчанию..." -ForegroundColor Cyan
                    New-1CDefaultCompressTask
                    Write-Host "`nЗадача создана успешно!" -ForegroundColor Green
                }
                catch {
                    Write-Host "`nОшибка: $_" -ForegroundColor Red
                }
                Read-Host "`nEnter для продолжения" | Out-Null
            }
            '2' {
                Write-Host "`nНастройка параметров архивации" -ForegroundColor Cyan
                Write-Host ""
                
                $fileDays = Read-Host "Хранение файлов (дней) [Enter для 7]"
                if ($fileDays -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($fileDays)) { $fileDays = 7 } else { $fileDays = [int]$fileDays }
                
                $archiveDays = Read-Host "Хранение архивов (дней) [Enter для 90]"
                if ($archiveDays -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($archiveDays)) { $archiveDays = 90 } else { $archiveDays = [int]$archiveDays }
                
                $at = Read-Host "Время запуска (HH:mm) [Enter для 05:00]"
                if ($at -match '^(r|назад|back)$') { continue }
                if ([string]::IsNullOrWhiteSpace($at)) { $at = '05:00' }
                
                try {
                    Write-Host "`nСоздание задачи..." -ForegroundColor Cyan
                    New-1CCustomCompressTask
                    Write-Host "`nЗадача создана успешно!" -ForegroundColor Green
                }
                catch {
                    Write-Host "`nОшибка: $_" -ForegroundColor Red
                }
                Read-Host "`nEnter для продолжения" | Out-Null
            }
            default {
                Write-Host "`nНеверный выбор." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}