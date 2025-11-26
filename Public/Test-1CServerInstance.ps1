function Test-1CServerInstance {
    <#
    .SYNOPSIS
        Проверяет конфигурацию экземпляра сервера 1С.
    .DESCRIPTION
        Проверяет все аспекты конфигурации сервера 1С для указанного префикса портов:
        - Существование службы и её статус
        - Наличие каталога данных srvinfo
        - Наличие ссылки current/currentXX
        - Права доступа USR1CV8 на каталог данных
        - Доступность портов
        - Наличие исполняемых файлов
    .PARAMETER PortPrefix
        Префикс портов (15, 25, 35 и т.д.). По умолчанию 15.
    .EXAMPLE
        Test-1CServerInstance -PortPrefix 25
    .EXAMPLE
        Test-1CServerInstance
        # Проверит экземпляр Current (порты 15xx)
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^\d{2}$')]
        [string]$PortPrefix = '15'
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Проверка экземпляра сервера 1С" -ForegroundColor Cyan
    Write-Host "Префикс портов: $PortPrefix" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $issues = @()
    $warnings = @()

    # 1. Проверка службы
    Write-Host "1. Проверка службы..." -ForegroundColor Yellow
    $ServiceName = if ($PortPrefix -eq '15') {
        '1C:Enterprise 8.3 Server Agent Current'
    } else {
        "1C:Enterprise 8.3 Server Agent Current$PortPrefix"
    }

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "   ✓ Служба найдена: $ServiceName" -ForegroundColor Green
        Write-Host "     Статус: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
        Write-Host "     Тип запуска: $($service.StartType)" -ForegroundColor DarkGray
        
        if ($service.Status -ne 'Running') {
            $warnings += "Служба не запущена (статус: $($service.Status))"
        }
    } else {
        Write-Host "   ✗ Служба не найдена: $ServiceName" -ForegroundColor Red
        $issues += "Служба не существует"
    }

    # 2. Проверка каталога данных
    Write-Host "`n2. Проверка каталога данных..." -ForegroundColor Yellow
    $pf1c = 'C:\Program Files\1cv8'
    $srvInfoDir = "srvinfo$PortPrefix"
    $SrvCatalog = Join-Path $pf1c $srvInfoDir

    if (Test-Path $SrvCatalog) {
        Write-Host "   ✓ Каталог найден: $SrvCatalog" -ForegroundColor Green
        
        # Проверка прав доступа
        $machine = $env:COMPUTERNAME
        $userSam = "$machine\USR1CV8"
        
        try {
            $acl = Get-Acl $SrvCatalog
            $userAccess = $acl.Access | Where-Object { $_.IdentityReference -eq $userSam }
            
            if ($userAccess) {
                $hasFullControl = $userAccess | Where-Object { $_.FileSystemRights -match 'FullControl' }
                if ($hasFullControl) {
                    Write-Host "   ✓ Права доступа для ${userSam}: FullControl" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠ Права доступа для ${userSam}: $($userAccess.FileSystemRights)" -ForegroundColor Yellow
                    $warnings += "У пользователя $userSam нет полного доступа к $SrvCatalog"
                }
            } else {
                Write-Host "   ✗ Права доступа для $userSam не установлены" -ForegroundColor Red
                $issues += "Отсутствуют права доступа для $userSam"
            }
        }
        catch {
            Write-Host "   ⚠ Не удалось проверить права доступа: $_" -ForegroundColor Yellow
            $warnings += "Ошибка проверки прав доступа"
        }
    } else {
        Write-Host "   ✗ Каталог не найден: $SrvCatalog" -ForegroundColor Red
        $issues += "Каталог данных не существует"
    }

    # 3. Проверка ссылки current/currentXX
    Write-Host "`n3. Проверка ссылки на платформу..." -ForegroundColor Yellow
    $linkName = if ($PortPrefix -eq '15') { 'current' } else { "current$PortPrefix" }
    $linkPath = Join-Path $pf1c $linkName

    if (Test-Path $linkPath) {
        $target = (Get-Item $linkPath).Target
        if ($target) {
            Write-Host "   ✓ Ссылка найдена: $linkName → $target" -ForegroundColor Green
        } else {
            Write-Host "   ✓ Каталог найден: $linkName (не junction)" -ForegroundColor Green
        }
    } else {
        Write-Host "   ✗ Ссылка не найдена: $linkPath" -ForegroundColor Red
        $issues += "Ссылка $linkName не существует"
    }

    # 4. Проверка исполняемых файлов
    Write-Host "`n4. Проверка исполняемых файлов..." -ForegroundColor Yellow
    $binPath = Join-Path $linkPath 'bin'
    $ragentPath = Join-Path $binPath 'ragent.exe'

    if (Test-Path $ragentPath) {
        $version = (Get-Item $ragentPath).VersionInfo.ProductVersion
        Write-Host "   ✓ ragent.exe найден" -ForegroundColor Green
        Write-Host "     Версия: $version" -ForegroundColor DarkGray
        Write-Host "     Путь: $ragentPath" -ForegroundColor DarkGray
    } else {
        Write-Host "   ✗ ragent.exe не найден: $ragentPath" -ForegroundColor Red
        $issues += "Исполняемый файл ragent.exe не найден"
    }

    # 5. Проверка портов
    Write-Host "`n5. Проверка портов..." -ForegroundColor Yellow
    $BasePort = [int]("{0}41" -f $PortPrefix)
    $CtrlPort = [int]("{0}40" -f $PortPrefix)
    $RangeStart = [int]("{0}60" -f $PortPrefix)
    $RangeEnd = [int]("{0}91" -f $PortPrefix)

    Write-Host "   Порты: base=$BasePort, ctrl=$CtrlPort, range=$RangeStart-$RangeEnd" -ForegroundColor DarkGray

    try {
        $listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
        
        $basePortUsed = $listeners | Where-Object { $_.LocalPort -eq $BasePort }
        $ctrlPortUsed = $listeners | Where-Object { $_.LocalPort -eq $CtrlPort }
        
        if ($basePortUsed) {
            Write-Host "   ✓ Порт $BasePort (base) прослушивается" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Порт $BasePort (base) не прослушивается" -ForegroundColor Yellow
            if ($service -and $service.Status -eq 'Running') {
                $warnings += "Служба запущена, но порт $BasePort не прослушивается"
            }
        }
        
        if ($ctrlPortUsed) {
            Write-Host "   ✓ Порт $CtrlPort (ctrl) прослушивается" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ Порт $CtrlPort (ctrl) не прослушивается" -ForegroundColor Yellow
            if ($service -and $service.Status -eq 'Running') {
                $warnings += "Служба запущена, но порт $CtrlPort не прослушивается"
            }
        }
    }
    catch {
        Write-Host "   ⚠ Не удалось проверить порты: $_" -ForegroundColor Yellow
        $warnings += "Ошибка проверки портов"
    }

    # 6. Проверка пользователя USR1CV8
    Write-Host "`n6. Проверка пользователя службы..." -ForegroundColor Yellow
    $localUser = Get-LocalUser -Name 'USR1CV8' -ErrorAction SilentlyContinue
    if ($localUser) {
        Write-Host "   ✓ Пользователь USR1CV8 существует" -ForegroundColor Green
        Write-Host "     Включен: $($localUser.Enabled)" -ForegroundColor DarkGray
        
        if (-not $localUser.Enabled) {
            $warnings += "Пользователь USR1CV8 отключен"
        }
    } else {
        Write-Host "   ✗ Пользователь USR1CV8 не найден" -ForegroundColor Red
        $issues += "Пользователь USR1CV8 не существует"
    }

    # Итоговый отчёт
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Результаты проверки" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "✓ Все проверки пройдены успешно!" -ForegroundColor Green
        return $true
    }

    if ($issues.Count -gt 0) {
        Write-Host "`nКритические проблемы:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Red
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Host "`nПредупреждения:" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "  • $warning" -ForegroundColor Yellow
        }
    }

    Write-Host "`n========================================`n" -ForegroundColor Cyan

    return ($issues.Count -eq 0)
}
