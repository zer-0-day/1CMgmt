<#
.SYNOPSIS
    Устанавливает сервер 1С:Предприятия (служба current/currentXX).

.DESCRIPTION
    Если указан -Version, ищет и копирует ТОЛЬКО архив windows64full_<версия>.rar
    (8_3_xx_xxxx) из -SetupPath (локальный/UNC, можно корень с подкаталогами) в 1Cv8.adm,
    распаковывает пакет и проверяет, что распаковалась ИМЕННО эта версия.
    Если версия не совпала — останавливается с ошибкой (не ставим «не ту»).

    Имя службы формируется ТОЛЬКО от PortPrefix:
      - без PortPrefix → current (порты 15*)
      - с PortPrefix=25 → current25 (порты 25*)
      - с PortPrefix=35 → current35 (порты 35*), и т.д.

.PARAMETER SetupPath
    Каталог версии или корень с версиями (локальный/UNC). Можно не указывать.

.PARAMETER Version
    Точная версия, например 8.3.22.1704. ОБЯЗАТЕЛЬНО при желании ставить конкретный билд.

.PARAMETER PortPrefix
    Префикс портов из двух цифр (например 25). Необязателен. Без него — схема 15* (current).

.EXAMPLE
    Install-1CServer -SetupPath "\\server\\distr\\1Cv83" -Version 8.3.22.1704 -PortPrefix 25
#>
function Install-1CServer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SetupPath,
        [string]$Version,
        [ValidatePattern('^[0-9]{2}$')]
        [int]$PortPrefix
    )

    # --- Каталог 1Cv8.adm ---
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        throw "Каталог дистрибутивов 1Cv8.adm не найден."
    }

    # --- Если задана конкретная версия — находим ИМЕННО её архив и копируем в 1Cv8.adm ---
    if ($PSBoundParameters.ContainsKey('Version')) {
        if (-not $Version -or $Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
            throw "Некорректная версия: '$Version'. Ожидается вид 8.3.xx.xxxx"
        }
        $verU = $Version -replace '\.', '_'  # 8.3.22.1704 -> 8_3_22_1704
        $wantedName = "windows64full_${verU}.rar"

        $srcArchive = $null
        if ($SetupPath) {
            if (-not (Test-Path -LiteralPath $SetupPath)) {
                throw "Каталог не найден: $SetupPath"
            }
            # Ищем рекурсивно только нужный архив по точному имени
            $f = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wantedName -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { $srcArchive = $f.FullName }
        } else {
            # Если путь не задан — пробуем, вдруг архив уже есть в 1Cv8.adm
            $f = Get-ChildItem -LiteralPath $admPath -Filter $wantedName -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { $srcArchive = $f.FullName }
        }

        if (-not $srcArchive) {
            throw "Не найден архив '$wantedName' в '$SetupPath'. Укажи корректный -SetupPath или помести архив в $admPath"
        }

        $destArchive = Join-Path $admPath $wantedName
        if ($srcArchive -ne $destArchive) {
            Write-Host "Копирую архив конкретной версии: '$srcArchive' → '$destArchive'"
            Copy-Item -LiteralPath $srcArchive -Destination $destArchive -Force
        } else {
            Write-Host "Архив нужной версии уже находится в 1Cv8.adm: $destArchive"
        }
    }

    # --- Подготовка распаковки дистрибутива ---
    $pkg = New-1CDistroPackage
    if (-not $pkg) { throw "Не удалось подготовить дистрибутив." }

    # Если Version задан — строго проверим, что распаковалась именно она
    if ($PSBoundParameters.ContainsKey('Version')) {
        if ($pkg.VersionString -ne $Version) {
            throw "Обнаружена версия '$($pkg.VersionString)', но запрошена '$Version'. Установка остановлена, чтобы не поставить неверный билд."
        }
    }

    $setupDir = $pkg.Path  # Ожидаем '...\\<версия>\\Server\\64'
    if (-not (Test-Path -LiteralPath $setupDir)) {
        throw "Каталог пакета не найден: $setupDir"
    }

    # --- Имя службы и порты ---
    $svcSuffix = if ($PSBoundParameters.ContainsKey('PortPrefix')) { $PortPrefix } else { $null }
    $serviceMarker = if ($svcSuffix) { "current$svcSuffix" } else { "current" }

    $regPort = if ($svcSuffix) { [int]("$svcSuffix" + "41") } else { 1541 }
    $port    = if ($svcSuffix) { [int]("$svcSuffix" + "40") } else { 1540 }
    $range   = if ($svcSuffix) { "{0}60:{0}91" -f $svcSuffix } else { "1560:1591" }

    # --- Установка MSI серверной части (используем готовый каталог pkg.Path) ---
    Push-Location $setupDir
    try {
        $msi = Join-Path $setupDir '1CEnterprise 8 (x86-64).msi'
        if (-not (Test-Path -LiteralPath $msi)) {
            throw "MSI сервера не найден: $msi"
        }

        # Полный набор свойств MSI — чтобы гарантированно поставить сервер и администрирование
        $admMst = Join-Path $setupDir 'adminstallrelogon.mst'
        $ruMst  = Join-Path $setupDir '1049.mst'
        $trans  = @()
        if (Test-Path -LiteralPath $admMst) { $trans += $admMst }
        if (Test-Path -LiteralPath $ruMst)  { $trans += $ruMst }

        $params = @('/i', $msi, '/qn', '/norestart')
        if ($trans.Count) { $params += "TRANSFORMS=$($trans -join ';')" }
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

        Write-Host "Выполняется установка сервера 1С..." -ForegroundColor Green
        & msiexec.exe @params | Out-Null

        # Создание службы со ссылкой на current
        New-1CCurrentPlatformLink  # формирует C:\\Program Files\\1cv8\\current

        $srvInfo = 'C:\Program Files\1cv8\srvinfo'
        if (-not (Test-Path $srvInfo)) { New-Item -ItemType Directory -Force -Path $srvInfo | Out-Null }

        $ragent = 'C:\Program Files\1cv8\current\bin\ragent.exe'
        if (-not (Test-Path $ragent)) { throw "Не найден ragent.exe по ссылке current: $ragent" }

        $svcName = "1C:Enterprise 8.3 Server Agent $serviceMarker"
        $binPath = "`"$ragent`" -srvc -agent -regport $regPort -port $port -range $range -debug -d `"$srvInfo`""

        Write-Host "Создаю/обновляю службу: $svcName"
        sc.exe create "$svcName" binPath= "$binPath" start= auto DisplayName= "$svcName" | Out-Null 2>$null
        sc.exe config "$svcName" binPath= "$binPath" start= auto | Out-Null

        Write-Host "Служба '$svcName' готова." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}