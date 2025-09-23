<#
.SYNOPSIS
    Устанавливает/обновляет платформу 1С (включая сервер и администрирование).

.DESCRIPTION
    При -Version ищется строго архив windows64full_<версия>.rar (8_3_xx_xxxx) в -SetupPath (локальный/UNC, корень допускается).
    Архив копируется в C:\1Cv8.adm, выполняется распаковка (через New-1CDistroPackage) и ПРОВЕРКА,
    что распакована именно требуемая версия. Иначе установка прерывается.

    MSI запускается тихо и с явными свойствами, чтобы гарантированно ставились сервер и администрирование.
    Порядок действий: MSI → проверка кода возврата → New-1CCurrentPlatformLink → регистрация DLL из current\bin.

.PARAMETER SetupPath
    Каталог версии ИЛИ корень с версиями (UNC/локальный). Необязателен.

.PARAMETER Version
    Точная версия, например 8.3.22.1704. Если задана — будет установлен именно этот билд.

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
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        throw "Требуются права администратора."
    }

    # Каталог 1Cv8.adm
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        throw "Каталог дистрибутивов 1Cv8.adm не найден."
    }

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
            $src = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue `
                  | Select-Object -First 1 | ForEach-Object { $_.FullName }
        } else {
            # допускаем, что архив уже лежит в 1Cv8.adm
            $src = Get-ChildItem -LiteralPath $admPath -Filter $wanted -File -ErrorAction SilentlyContinue `
                  | Select-Object -First 1 | ForEach-Object { $_.FullName }
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

        # Без -Version: берём последнюю найденную в указанном пути
        $cands = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
        if ($cands) {
            $parsed = @()
            foreach ($f in $cands) {
                if ($f.BaseName -match '^windows64full_(\d+_\d+_\d+_\d+)$') {
                    $v = $matches[1] -replace '_','.'
                    try {
                        $obj = "" | Select-Object Version, File
                        $obj.Version = [version]$v
                        $obj.File = $f.FullName
                        $parsed += $obj
                    } catch {}
                }
            }
            if ($parsed -and $parsed.Count -gt 0) {
                $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
                $dst = Join-Path $admPath (Split-Path -Leaf $best.File)
                if (-not (Test-Path -LiteralPath $dst)) {
                    Write-Host "Копирую архив: '$($best.File)' → '$dst'" -ForegroundColor Yellow
                    Copy-Item -LiteralPath $best.File -Destination $dst -Force
                } else {
                    Write-Host "Архив уже есть в 1Cv8.adm: $dst" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'." -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "SetupPath не задан — будет использован локальный кэш 1Cv8.adm." -ForegroundColor DarkGray
    }

    # Распаковка/подготовка пакета
    Write-Host "Подготовка дистрибутива (New-1CDistroPackage)..." -ForegroundColor Cyan
    $pkg = New-1CDistroPackage
    if (-not $pkg) { throw "Не удалось подготовить дистрибутив." }

    $SetupPath = $pkg.Path
    $pkgVer    = $pkg.VersionString
    if ($pkgVer) {
        Write-Host ("Обнаружен пакет версии: {0}" -f $pkgVer) -ForegroundColor DarkGray
    } else {
        Write-Host "Обнаружен пакет версии: (версия не определена)" -ForegroundColor DarkGray
    }

    if ($Version -and $pkgVer -ne $Version) {
        throw ("Распакована версия '{0}', ожидалась '{1}'. Установка остановлена." -f $pkgVer, $Version)
    }

    # Установка MSI
    $msi = Join-Path $SetupPath '1CEnterprise 8 (x86-64).msi'
    if (-not (Test-Path -LiteralPath $msi)) { throw "MSI не найден: $msi" }

    Push-Location $SetupPath
    try {
        $admMst = Join-Path $SetupPath 'adminstallrelogon.mst'
        $ruMst  = Join-Path $SetupPath '1049.mst'
        $trans  = @()
        if (Test-Path -LiteralPath $admMst) { $trans += $admMst }
        if (Test-Path -LiteralPath $ruMst)  { $trans += $ruMst }

        $params = @('/i', $msi)
        if ($Quiet)     { $params += '/qn' }
        if ($NoRestart) { $params += '/norestart' }
        if ($trans -and $trans.Count -gt 0) {
            $params += ("TRANSFORMS={0}" -f ($trans -join ';'))
        }

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

        $verText = if ($pkgVer) { $pkgVer } else { '(версия не определена)' }
        Write-Host ("Выполняется установка 1С {0}..." -f $verText) -ForegroundColor Green

        & msiexec.exe @params
        $code = $LASTEXITCODE
        if ($code -eq 3010) {
            Write-Host "MSI: успех, требуется перезагрузка (3010)." -ForegroundColor Yellow
        } elseif ($code -ne 0) {
            throw ("MSI завершился с кодом {0}." -f $code)
        } else {
            Write-Host "MSI: успех (0)." -ForegroundColor Green
        }
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
            & regsvr32.exe ("`"{0}`"" -f $dll) -s
        } else {
            Write-Warning ("Файл не найден: {0}" -f $dll)
        }
    }

    # Удаляем соответствующий архив из 1Cv8.adm (если остался)
    if ($pkgVer) {
        $verU = $pkgVer -replace '\.', '_'
        Get-ChildItem -LiteralPath $admPath -Filter ("windows64full_{0}.rar" -f $verU) -File -ErrorAction SilentlyContinue `
            | ForEach-Object {
                Write-Host ("Удаляю архив: {0}" -f $_.FullName) -ForegroundColor DarkGray
                Remove-Item -LiteralPath $_.FullName -Force
            }
    }
}