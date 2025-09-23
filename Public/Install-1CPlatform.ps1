<#
.SYNOPSIS
    Устанавливает/обновляет платформу 1С (включая сервер и администрирование).

.DESCRIPTION
    Поддерживает три сценария источника:
      1) -SetupPath указывает на УЖЕ РАСПАКОВАННЫЙ дистрибутив (внутри есть '1CEnterprise 8 (x86-64).msi'):
         → используем этот каталог напрямую, архивы НЕ ищем и НЕ копируем.
      2) -SetupPath указывает на корень/папку с архивами:
         → (при -Version) ищем ТОЛЬКО 'windows64full_<версия>.rar' рекурсивно; (без -Version) — берём самый новый архив.
         → копируем архив в C:\1Cv8.adm и распаковываем через New-1CDistroPackage.
      3) -SetupPath не задан:
         → используем C:\1Cv8.adm (Find-1CDistroFolder) и распаковку через New-1CDistroPackage.

    При -Version выполняется строгая проверка: установленная/распакованная версия = указанной.
    Порядок: MSI → проверка exit-code → New-1CCurrentPlatformLink → регистрация DLL из current\bin.

.PARAMETER SetupPath
    Папка конкретной версии (распакованной) ИЛИ корень с архивами (UNC/локальный).

.PARAMETER Version
    Точная версия, например 8.3.22.1704. Если задана — ставим ровно этот билд.

.PARAMETER Quiet
    Тихая установка (/qn). По умолчанию $true.

.PARAMETER NoRestart
    Без перезагрузки (/norestart). По умолчанию $true.
#>
function Install-1CPlatform {
    [CmdletBinding()]
    param(
        [string]$SetupPath,
        [string]$Version,
        [bool]$Quiet = $true,
        [bool]$NoRestart = $true
    )

    # Требуются права администратора
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Требуются права администратора."
    }

    # Базовые переменные
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        throw "Каталог дистрибутивов 1Cv8.adm не найден."
    }

    $useExtracted = $false
    $installDir   = $null   # каталог, где лежит MSI (итоговый источник для установки)
    $pkgVer       = $null   # обнаруженная версия
    $msiName      = '1CEnterprise 8 (x86-64).msi'

    # --- ВЕТКА А: SetupPath задан и это уже распакованный дистрибутив (есть MSI) ---
    if ($SetupPath -and (Test-Path -LiteralPath $SetupPath)) {
        $msiProbe = Join-Path $SetupPath $msiName
        if (-not (Test-Path -LiteralPath $msiProbe)) {
            # Может быть, пользователь указал ..\Server\64 или на уровень выше/ниже
            $msiProbe = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $msiName -File -ErrorAction SilentlyContinue |
                        Select-Object -First 1 | ForEach-Object FullName
        }
        if ($msiProbe) {
            # Это уже распакованный дистрибутив
            $useExtracted = $true
            $installDir   = Split-Path -Path $msiProbe -Parent

            # Попробуем извлечь версию из пути: ...\<8.3.xx.xxxx>\Server\64
            $pathParts = $installDir -split '[\\/]'
            $maybeVer  = $pathParts | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -Last 1
            if ($maybeVer) { $pkgVer = $maybeVer }

            Write-Host "Обнаружен уже распакованный дистрибутив: $installDir" -ForegroundColor Cyan

            if ($Version) {
                if ($pkgVer) {
                    if ($pkgVer -ne $Version) {
                        throw "Несовпадение версии: в пути '$pkgVer', ожидается '$Version'. Укажите корректный SetupPath или версию."
                    }
                }
                else {
                    Write-Warning "Не удалось определить версию из пути '$installDir'. Продолжаю без сверки с -Version."
                }
            }
        }
    }

    if (-not $useExtracted) {
        # --- ВЕТКА B/C: требуется работа с архивом и New-1CDistroPackage ---
        # Если задана конкретная версия — найдём ТОЛЬКО соответствующий архив и скопируем в 1Cv8.adm
        if ($PSBoundParameters.ContainsKey('Version')) {
            if (-not ($Version -match '^\d+\.\d+\.\d+\.\d+$')) {
                throw "Некорректная версия: '$Version'. Ожидается формат 8.3.xx.xxxx."
            }
            $verU = $Version -replace '\.', '_'
            $wanted = "windows64full_${verU}.rar"

            $src = $null
            if ($SetupPath) {
                if (-not (Test-Path -LiteralPath $SetupPath)) { throw "Каталог не найден: $SetupPath" }
                $src = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue |
                       Select-Object -First 1 | ForEach-Object FullName
            } else {
                # допускаем, что архив уже лежит в 1Cv8.adm
                $src = Get-ChildItem -LiteralPath $admPath -Filter $wanted -File -ErrorAction SilentlyContinue |
                       Select-Object -First 1 | ForEach-Object FullName
            }
            if (-not $src) { throw "Не найден архив '$wanted' в '$SetupPath'. Поместите архив в $admPath или укажите корректный -SetupPath." }

            $dst = Join-Path $admPath (Split-Path -Leaf $src)
            if ($src -ne $dst) {
                Write-Host "Копирую архив конкретной версии: '$src' → '$dst'" -ForegroundColor Yellow
                Copy-Item -LiteralPath $src -Destination $dst -Force
            } else {
                Write-Host "Архив нужной версии уже в 1Cv8.adm: $dst" -ForegroundColor DarkGray
            }
        }
        elseif ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
            if (-not (Test-Path -LiteralPath $SetupPath)) { throw "Каталог не найден: $SetupPath" }
            $cands = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
            if ($cands) {
                $parsed = foreach ($f in $cands) {
                    if ($f.BaseName -match '^windows64full_(?<v>\d+_\d+_\d+_\d+)$') {
                        $v = $matches['v'] -replace '_','.'
                        try { [pscustomobject]@{ Version=[version]$v; File=$f.FullName } } catch {}
                    }
                }
                if ($parsed) {
                    $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
                    $dst  = Join-Path $admPath (Split-Path -Leaf $best.File)
                    if (-not (Test-Path -LiteralPath $dst)) {
                        Write-Host "Копирую архив: '$($best.File)' → '$dst'" -ForegroundColor Yellow
                        Copy-Item -LiteralPath $best.File -Destination $dst -Force
                    } else {
                        Write-Host "Архив уже есть в 1Cv8.adm: $dst" -ForegroundColor DarkGray
                    }
                } else {
                    throw "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'."
                }
            } else {
                throw "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'."
            }
        }
        else {
            Write-Host "SetupPath не задан — будет использован локальный кэш 1Cv8.adm." -ForegroundColor DarkGray
        }

        # Распаковка/подготовка пакета
        Write-Host "Подготовка дистрибутива (New-1CDistroPackage)..." -ForegroundColor Cyan
        $pkg = New-1CDistroPackage
        if (-not $pkg) { throw "Не удалось подготовить дистрибутив." }

        $installDir = $pkg.Path
        $pkgVer     = $pkg.VersionString
        Write-Host "Обнаружен пакет версии: $pkgVer" -ForegroundColor DarkGray

        if ($Version -and $pkgVer -ne $Version) {
            throw "Распакована версия '$pkgVer', ожидалась '$Version'. Установка остановлена."
        }

        # Удалим архив соответствующей версии из 1Cv8.adm (если остался)
        if ($pkgVer) {
            $verU = $pkgVer -replace '\.', '_'
            Get-ChildItem -LiteralPath $admPath -Filter "windows64full_${verU}.rar" -File -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Write-Host "Удаляю архив: $($_.FullName)" -ForegroundColor DarkGray
                    Remove-Item -LiteralPath $_.FullName -Force
                }
        }
    }

    # --- Установка MSI из $installDir ---
    $msi = Join-Path $installDir $msiName
    if (-not (Test-Path -LiteralPath $msi)) {
        throw "MSI не найден: $msi"
    }

    Push-Location $installDir
    try {
        $admMst = Join-Path $installDir 'adminstallrelogon.mst'
        $ruMst  = Join-Path $installDir '1049.mst'
        $trans  = @()
        if (Test-Path -LiteralPath $admMst) { $trans += $admMst }
        if (Test-Path -LiteralPath $ruMst)  { $trans += $ruMst }

        $params = @('/i', $msi)
        if ($Quiet)     { $params += '/qn' }
        if ($NoRestart) { $params += '/norestart' }
        if ($trans.Count) { $params += "TRANSFORMS=$($trans -join ';')" }

        # Явные свойства — сервер и администрирование точно установятся
        $params += @(
            'DESIGNERALLCLIENTS=1',
            'THICKCLIENT=1',
            'THINCLIENTFILE=1',
            'THINCLIENT=1',
            'WEBSERVEREXT=1',
            'SERVER=1',
            'CONFREPOSSERVER=0',
            'CONVERTER77=0',
            'SERVERCLIENT=1',
            'LANGUAGES=RU'
        )

        Write-Host "Выполняется установка 1С $($pkgVer ?? '(версия не определена)')..." -ForegroundColor Green
        & msiexec.exe @params
        $code = $LASTEXITCODE
        if     ($code -eq 0)    { Write-Host "MSI: успех (0)." -ForegroundColor Green }
        elseif ($code -eq 3010) { Write-Host "MSI: успех, требуется перезагрузка (3010)." -ForegroundColor Yellow }
        else                    { throw "MSI завершился с кодом $code." }
    }
    finally {
        Pop-Location
    }

    # Обновляем ссылку current → затем регистрируем DLL по ссылке current
    New-1CCurrentPlatformLink

    $binCurrent = 'C:\Program Files\1cv8\current\bin'
    $comcntr = Join-Path $binCurrent 'comcntr.dll'
    $radmin  = Join-Path $binCurrent 'radmin.dll'
    foreach ($dll in @($comcntr, $radmin)) {
        if (Test-Path -LiteralPath $dll) {
            & regsvr32.exe "`"$dll`"" -s
        } else {
            Write-Warning "Файл не найден: $dll"
        }
    }
}