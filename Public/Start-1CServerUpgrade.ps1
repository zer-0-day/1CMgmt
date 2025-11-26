<#
.SYNOPSIS
    Ищет новую платформу и обновляет её. По умолчанию перезапускает только службу '… Current'.
    При указании -PortPrefix перезапускает также '… Current<PortPrefix>' для каждого переданного префикса.

.DESCRIPTION
    1) Определяет текущую версию по ragent.exe (C:\Program Files\1cv8\current\bin\ragent.exe).
    2) Целевая версия:
       - если -SetupPath → папка версии или общий корень: рекурсивный поиск windows64full_8_3_*.rar;
       - иначе → New-1CDistroPackage (каталог 1Cv8.adm).
    3) Если целевая новее — вызывает Install-1CPlatform (с -SetupPath при наличии).
    4) Перезапускает службы:
       - всегда: '1C:Enterprise 8.3 Server Agent Current';
       - если задан -PortPrefix (может быть массивом: 25,35,…) — дополнительно
         '1C:Enterprise 8.3 Server Agent Current<pp>' для каждого префикса.

.PARAMETER SetupPath
    Папка версии (\\server\...\8.3.xx.xxxx) или общий корень (\\server\distr).

.PARAMETER PortPrefix
    Одно значение или массив (например: 25 или @(25,35)).

.EXAMPLE
    Start-1CServerUpgrade
    # Обновит платформу и перезапустит только '... Current'

.EXAMPLE
    Start-1CServerUpgrade -PortPrefix 25 -SetupPath "\\server\\8.3.25.1577"
    # Обновит платформу из указанного пути, затем перезапустит '... Current' и '... Current25'
#>
function Start-1CServerUpgrade {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SetupPath,
        [int[]]$PortPrefix
    )

    # --- 1) Текущая версия по ragent.exe ---
    $ragent = 'C:\Program Files\1cv8\current\bin\ragent.exe'
    if (-not (Test-Path -LiteralPath $ragent)) {
        Write-Host "Не найден установленный сервер 1С (ragent.exe). Обновлять нечего." -ForegroundColor Yellow
        return
    }

    $currentStr = (Get-Item $ragent).VersionInfo.ProductVersion
    try { $current = [Version]$currentStr } catch {
        Write-Error "Не удалось распарсить текущую версию: '$currentStr'"; return
    }

    # --- 2) Целевая (доступная) версия ---
    $latestStr  = $null
    $latestPath = $null

    if ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
        if (-not (Test-Path -LiteralPath $SetupPath)) {
            Write-Error "Папка не найдена: $SetupPath"; return
        }

        $leaf = Split-Path -Leaf $SetupPath
        if ($leaf -match '^\d+\.\d+\.\d+\.\d+$') {
            # Папка конкретной версии
            $latestStr  = $leaf
            $latestPath = $SetupPath
        }
        else {
            # Общая папка — ищем серверные архивы рекурсивно
            $candidates = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
            if (-not $candidates -or $candidates.Count -eq 0) {
                Write-Error "В '$SetupPath' не найдено серверных архивов формата windows64full_8_3_xx_xxxx.rar."; return
            }

            $parsed = foreach ($f in $candidates) {
                if ($f.BaseName -match '^windows64full_(?<ver>\d+_\d+_\d+_\d+)$') {
                    $verStr = $matches['ver'] -replace '_','.'
                    try {
                        [PSCustomObject]@{
                            Version       = [Version]$verStr
                            VersionString = $verStr
                            Dir           = $f.DirectoryName
                        }
                    } catch { }
                }
            }

            if (-not $parsed -or $parsed.Count -eq 0) {
                Write-Error "Не удалось определить версии по найденным архивам в '$SetupPath'."; return
            }

            $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
            $latestStr  = $best.VersionString
            $latestPath = $best.Dir
        }
    }
    else {
        $pkg = New-1CDistroPackage
        if (-not $pkg) {
            Write-Host "В 1Cv8.adm нет подходящего дистрибутива (windows64full_8_3_xx_xxxx.rar). Обновление не требуется." -ForegroundColor Yellow
            return
        }
        $latestStr  = $pkg.VersionString
        $latestPath = $pkg.Path
    }

    try { $latest = [Version]$latestStr } catch {
        Write-Error "Не удалось распарсить целевую версию: '$latestStr'"; return
    }

    Write-Host "Установлено: $currentStr; Доступно: $latestStr" -ForegroundColor Cyan

    if ($latest -le $current) {
        Write-Host "Новой версии нет (или равна текущей). Ничего не делаем." -ForegroundColor Green
        return
    }

    # --- 3) Обновление до новой версии ---
    $targetLabel = "1C Platform $latestStr"
    if ($PSCmdlet.ShouldProcess($targetLabel, "Установка/обновление")) {
        if ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
            Install-1CPlatform -SetupPath $SetupPath
        } else {
            Install-1CPlatform
        }
    }

    # --- 3.5) Обновление ссылок currentXX для всех служб ---
    Write-Host "`nОбновление ссылок current и currentXX..." -ForegroundColor Cyan
    
    # Найти все службы 1С и извлечь префиксы портов
    $allServices = Get-Service -Name "1C:Enterprise 8.3 Server Agent Current*" -ErrorAction SilentlyContinue
    $additionalPrefixes = @()
    
    foreach ($svc in $allServices) {
        if ($svc.Name -match 'Current(\d{2})$') {
            $pp = [int]$matches[1]
            if ($pp -ne 15) {
                $additionalPrefixes += $pp
            }
        }
    }
    
    # Обновить ссылку current
    New-1CCurrentPlatformLink
    
    # Обновить ссылки currentXX для найденных служб
    if ($additionalPrefixes.Count -gt 0) {
        Write-Host "Обновление ссылок для дополнительных служб: $($additionalPrefixes -join ', ')" -ForegroundColor Cyan
        New-1CCurrentPlatformLink -PortPrefix $additionalPrefixes
    }

    # --- 4) Перезапуск нужных служб ---
    $serviceNames = @('1C:Enterprise 8.3 Server Agent Current')
    if ($PortPrefix) {
        foreach ($pp in $PortPrefix) {
            if ($pp -ne 15) {
                $serviceNames += "1C:Enterprise 8.3 Server Agent Current$pp"
            } else {
                # 15 уже есть в списке
            }
        }
    }

    foreach ($svc in $serviceNames | Sort-Object -Unique) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Write-Host "Перезапуск службы: $svc" -ForegroundColor Cyan
            try {
                Restart-Service -Name $svc -ErrorAction Stop
                Write-Host "Служба $svc перезапущена." -ForegroundColor Green
            } catch {
                Write-Warning "Не удалось перезапустить '$svc': $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Служба не найдена: $svc"
        }
    }

    Write-Host "`nГотово: платформа обновлена до $latestStr, службы перезапущены." -ForegroundColor Green
}