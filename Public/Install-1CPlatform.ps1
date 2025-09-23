<#
.SYNOPSIS
    Устанавливает или обновляет платформу 1С из каталога дистрибутива.

.DESCRIPTION
    Ищет дистрибутив по заданному пути (UNC/локальный) или в 1Cv8.adm.
    Если указан -Version — берётся строго соответствующий архив
    windows64full_<версия>.rar (например windows64full_8_3_22_1704.rar).
    Архив из UNC/локального пути копируется в C:\1Cv8.adm, затем выполняется распаковка
    (New-1CDistroPackage) и установка MSI с явными компонентами сервера и администрирования.
    После успешной распаковки соответствующий архив удаляется из 1Cv8.adm.
    В конце создаётся ссылка "current".

.PARAMETER SetupPath
    Корневой путь с версиями или папка конкретной версии (можно UNC).
    При указании — поиск архива ведётся ТОЛЬКО в этом пути (без локальных fallback'ов).

.PARAMETER Version
    Версия в формате 8.3.xx.xxxx (например 8.3.22.1704).
    При указании — ставим только этот билд (строгая проверка).

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

    # --- 1) Определяем каталог 1Cv8.adm ---
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        Write-Host "Каталог 1Cv8.adm не найден." -ForegroundColor Red
        return
    }

    # --- 2) Если передан SetupPath — ищем архив ТОЛЬКО там ---
    $archiveFile = $null
    if ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
        if (-not (Test-Path -LiteralPath $SetupPath)) {
            Write-Host "Каталог не найден: $SetupPath" -ForegroundColor Red
            return
        }

        Write-Host "Ищу архив в указанном пути: $SetupPath" -ForegroundColor Cyan

        if ($Version) {
            # Строгое имя архива по заданной версии
            if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
                Write-Host "Некорректная версия: '$Version' (ожидалось 8.3.xx.xxxx)" -ForegroundColor Red
                return
            }
            $verU = $Version -replace '\.', '_'
            $wanted = "windows64full_${verU}.rar"

            $hit = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { $archiveFile = $hit.FullName }
        }
        else {
            # Без -Version берём последнюю найденную в указанном пути
            $cands = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
            if ($cands) {
                $parsed = foreach ($f in $cands) {
                    if ($f.BaseName -match '^windows64full_(?<v>\d+_\d+_\d+_\d+)$') {
                        $verStr = $matches['v'] -replace '_','.'
                        try { [PSCustomObject]@{ Version=[Version]$verStr; File=$f.FullName } } catch {}
                    }
                }
                if ($parsed) {
                    $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
                    $archiveFile = $best.File
                }
            }
        }

        if (-not $archiveFile) {
            Write-Host "Архив не найден в указанном пути: $SetupPath" -ForegroundColor Red
            return
        }

        $dest = Join-Path $admPath (Split-Path -Leaf $archiveFile)
        if ($archiveFile -ne $dest) {
            Write-Host "Копирую архив в 1Cv8.adm: '$archiveFile' → '$dest'" -ForegroundColor Yellow
            Copy-Item -LiteralPath $archiveFile -Destination $dest -Force
        } else {
            Write-Host "Архив уже находится в 1Cv8.adm: $dest" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "SetupPath не задан — будет использован локальный кэш 1Cv8.adm." -ForegroundColor DarkGray
    }

    # --- 3) Распаковка/подготовка пакета из 1Cv8.adm ---
    Write-Host "Тестирование/подготовка дистрибутива (New-1CDistroPackage)..." -ForegroundColor Cyan
    $pkg = New-1CDistroPackage
    if (-not $pkg) {
        Write-Host "Не удалось подготовить дистрибутив." -ForegroundColor Red
        return
    }

    $SetupPath = $pkg.Path       # путь к распакованному '...\\<версия>\\Server\\64'
    $pkgVer    = $pkg.VersionString
    Write-Host "Обнаружен пакет версии: $pkgVer" -ForegroundColor DarkGray

    if ($Version -and $pkgVer -ne $Version) {
        Write-Host "ОШИБКА: распакована версия $pkgVer, ожидалась $Version. Установка остановлена." -ForegroundColor Red
        return
    }

    # --- 4) Удаляем архив соответствующей версии из 1Cv8.adm (если был) ---
    if ($pkgVer) {
        $verU = $pkgVer -replace '\.', '_'
        $rarMask = "windows64full_${verU}.rar"
        $rarFiles = Get-ChildItem -LiteralPath $admPath -Filter $rarMask -File -ErrorAction SilentlyContinue
        foreach ($rar in $rarFiles) {
            Write-Host "Удаляю архив: $($rar.FullName)" -ForegroundColor DarkGray
            Remove-Item -LiteralPath $rar.FullName -Force
        }
    }

    # --- 5) Установка MSI (явные свойства компонентов) ---
    $msi = Join-Path $SetupPath '1CEnterprise 8 (x86-64).msi'
    if (-not (Test-Path -LiteralPath $msi)) {
        Write-Host "MSI не найден: $msi" -ForegroundColor Red
        return
    }

    Push-Location $SetupPath
    try {
        $admMst = Join-Path $SetupPath 'adminstallrelogon.mst'
        $ruMst  = Join-Path $SetupPath '1049.mst'
        $transforms = @()
        if (Test-Path -LiteralPath $admMst) { $transforms += $admMst }
        if (Test-Path -LiteralPath $ruMst)  { $transforms += $ruMst }

        $params = @('/i', $msi)
        if ($Quiet)     { $params += '/qn' }
        if ($NoRestart) { $params += '/norestart' }
        if ($transforms.Count) {
            $params += "TRANSFORMS=$($transforms -join ';')"
        }

        # ЯВНОЕ перечисление компонентов — чтобы сервер и администрирование точно поставились
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

        Write-Host "Выполняется установка 1С $pkgVer..." -ForegroundColor Green
        & msiexec.exe @params | Out-Null

        # Регистрация DLL (по ссылке 'current')
        $binCurrent = 'C:\Program Files\1cv8\current\bin'
        $comcntr = Join-Path $binCurrent 'comcntr.dll'
        $radmin  = Join-Path $binCurrent 'radmin.dll'
        if (Test-Path -LiteralPath $comcntr) { regsvr32.exe $comcntr -s; Write-Host 'Библиотека comcntrl зарегистрирована' -ForegroundColor Green }
        if (Test-Path -LiteralPath $radmin)  { regsvr32.exe $radmin  -s; Write-Host 'Библиотека radmin зарегистрирована'  -ForegroundColor Green }
    }
    finally {
        Pop-Location
    }

    # --- 6) Обновляем ссылку 'current' ---
    New-1CCurrentPlatformLink
}