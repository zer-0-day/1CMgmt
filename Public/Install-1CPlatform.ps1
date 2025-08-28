<#
.SYNOPSIS
    Устанавливает или обновляет платформу 1С из каталога дистрибутива.

.DESCRIPTION
    Функция находит каталог дистрибутива через -SetupPath или New-1CDistroPackage.
    Если задан -SetupPath (папка версии или корень с подкаталогами версий):
        • ищет архив windows64full_8_3_xx_xxxx.rar (при корне — рекурсивно);
        • копирует найденный архив в 1Cv8.adm.
    Далее через New-1CDistroPackage распаковывает дистрибутив,
    после успешной распаковки удаляет соответствующий архив из 1Cv8.adm.

    Установка MSI выполняется в тихом режиме (/qn, опционально /norestart),
    с применением MST (adminstallrelogon.mst;1049.mst — если присутствуют),
    и с явным перечислением компонентов (SERVER, SERVERCLIENT, и т.д.)
    для гарантированного развёртывания серверной части и средств администрирования.

.PARAMETER SetupPath
    Путь к каталогу/корню с дистрибутивами (можно UNC).
    Если не указан — установка из последнего подготовленного пакета (New-1CDistroPackage).

.PARAMETER Quiet
    Тихая установка (/qn). По умолчанию $true.

.PARAMETER NoRestart
    Без перезагрузки (/norestart). По умолчанию $true.

.NOTES
    • Рекомендуемые MST: adminstallrelogon.mst + 1049.mst (русский язык).  [oai_citation:4‡mihanik.net](https://www.mihanik.net/tihaya-ustanovka-1spredpriyatiya-8-x/?utm_source=chatgpt.com) [oai_citation:5‡Форум ИТ специалистов](https://sysadmins.online/threads/8321/?utm_source=chatgpt.com)
    • Ключи msiexec: /i, /qn, /norestart — см. документацию Microsoft.  [oai_citation:6‡Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/msi/standard-installer-command-line-options?utm_source=chatgpt.com)
#>
function Install-1CPlatform {
    [CmdletBinding()]
    param(
        [string]$SetupPath,
        [bool]$Quiet = $true,
        [bool]$NoRestart = $true
    )

    # --- Путь к 1Cv8.adm ---
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        Write-Host "Каталог дистрибутивов 1Cv8.adm не найден." -ForegroundColor Red
        return
    }

    # --- Если указан SetupPath: найти серверный архив и скопировать в 1Cv8.adm ---
    if ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
        if (-not (Test-Path -LiteralPath $SetupPath)) {
            Write-Host "Каталог не найден: $SetupPath" -ForegroundColor Red
            return
        }

        $archiveFile = $null
        $leaf = Split-Path -Leaf $SetupPath

        if ($leaf -match '^\d+\.\d+\.\d+\.\d+$') {
            # Ветка конкретной версии: пробуем точное имя и общий шаблон
            $verUnderscore = $leaf -replace '\.', '_'
            $expected = Join-Path $SetupPath ("windows64full_{0}.rar" -f $verUnderscore)
            if (Test-Path -LiteralPath $expected) {
                $archiveFile = $expected
            }
            else {
                $c = Get-ChildItem -LiteralPath $SetupPath -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($c) { $archiveFile = $c.FullName }
            }
        }
        else {
            # Корень: ищем рекурсивно и берём самую свежую по номеру версии
            $cands = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
            if ($cands) {
                $parsed = foreach ($f in $cands) {
                    if ($f.BaseName -match '^windows64full_(?<v>\d+_\d+_\d+_\d+)$') {
                        $verStr = $matches['v'] -replace '_', '.'
                        try { [PSCustomObject]@{ Version = [Version]$verStr; File = $f.FullName } } catch {}
                    }
                }
                if ($parsed) {
                    $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
                    $archiveFile = $best.File
                }
            }
        }

        if (-not $archiveFile) {
            Write-Host "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'." -ForegroundColor Red
            return
        }

        $dest = Join-Path $admPath (Split-Path -Leaf $archiveFile)
        if (-not (Test-Path -LiteralPath $dest)) {
            Write-Host "Копирую архив в 1Cv8.adm: '$archiveFile' → '$dest'"
            Copy-Item -LiteralPath $archiveFile -Destination $dest -Force
        }
        else {
            Write-Host "Архив уже есть в 1Cv8.adm: $dest"
        }
    }

    # --- Подготовка распаковки ---
    $pkg = New-1CDistroPackage
    if (-not $pkg) { return }
    $SetupPath = $pkg.Path      # путь к распакованному серверному дистрибутиву
    $pkgVer    = $pkg.VersionString

    # --- Удаление RAR из 1Cv8.adm после успешной распаковки ---
    if ($admPath -and $pkgVer) {
        $verU = $pkgVer -replace '\.', '_'
        $rarMask = "windows64full_${verU}.rar"
        $rarFiles = Get-ChildItem -LiteralPath $admPath -Filter $rarMask -File -ErrorAction SilentlyContinue
        foreach ($rar in $rarFiles) {
            Write-Host "Удаляю архив: $($rar.FullName)"
            Remove-Item -LiteralPath $rar.FullName -Force
        }
    }

    # --- Установка MSI (явные свойства компонентов) ---
    $msi = Join-Path $SetupPath '1CEnterprise 8 (x86-64).msi'
    if (-not (Test-Path -LiteralPath $msi)) {
        Write-Host "MSI не найден: $msi" -ForegroundColor Red
        return
    }

    Push-Location $SetupPath
    try {
        # MST (применяем, если присутствуют)
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

        # ЯВНОЕ перечисление компонентов (важно для сервера и администрирования)
        $props = @(
            'DESIGNERALLCLIENTS=1',     # Конфигуратор + клиенты
            'THICKCLIENT=1',            # Толстый клиент
            'THINCLIENTFILE=1',         # Тонкий (файловый)
            'THINCLIENT=1',             # Тонкий (клиент-сервер)
            'WEBSERVEREXT=1',           # Модули расширения web-сервера
            'SERVER=1',                 # Сервер 1С:Предприятия
            'CONFREPOSSERVER=0',        # Сервер хранилища конфигураций (0 — не ставим)
            'CONVERTER77=0',            # Конвертер 7.7 (0 — не ставим)
            'SERVERCLIENT=1',           # Администрирование сервера
            'LANGUAGES=RU'              # Язык установки — русский
        )
        $params += $props

        Write-Host "Выполняется установка платформы 1С. Ожидайте..." -ForegroundColor Green
        # Для диагностики можно показать состав:
        # $params | ForEach-Object { Write-Host $_ }

        & msiexec.exe @params | Out-Null

        # Регистрация DLL
        $binCurrent = "C:\Program Files\1cv8\current\bin"
        $comcntr = Join-Path $binCurrent 'comcntr.dll'
        $radmin  = Join-Path $binCurrent 'radmin.dll'
        if (Test-Path -LiteralPath $comcntr) {
            regsvr32.exe $comcntr -s
            Write-Host 'Библиотека comcntrl зарегистрирована' -ForegroundColor Green
        }
        if (Test-Path -LiteralPath $radmin) {
            regsvr32.exe $radmin -s
            Write-Host 'Библиотека radmin зарегистрирована' -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }

    # --- Ссылка на current ---
    New-1CCurrentPlatformLink
}