<#
.SYNOPSIS
    Простой установщик сервера 1С с выбором префикса портов. Поддерживает -SetupPath, -Version и -Credential.

.DESCRIPTION
    1) Ставит/обновляет платформу (Install-1CPlatform; при -SetupPath — из указанного каталога/корня, при -Version — строго указанный билд).
    2) Настраивает учётку USR1CV8 (принимает -Credential, иначе: passfile → интерактивный запрос).
    3) Создаёт каталог srvinfo(XX), настраивает ACL.
    4) Регистрирует comcntr.dll и radmin.dll из выбранной папки bin.
    5) Создаёт службу агента с портами на базе префикса.

    ИМЕНА СЛУЖБ (без версий):
      • Имя службы зависит ТОЛЬКО от префикса портов (параметр -PortPrefix). Параметр -Version на имя не влияет.
        PortPrefix 15  → '1C:Enterprise 8.3 Server Agent Current'
        PortPrefix !=15 → '1C:Enterprise 8.3 Server Agent Current<PortPrefix>' (например Current25)

    ПУТЬ К БИНАРНИКАМ
      • Если -Version = 'current' (или не задан), путь службы указывает на '...\\current\\bin'.
      • Если задана конкретная версия (например 8.3.22.1704), путь службы указывает на '...\\8.3.22.1704\\bin'.

.PARAMETER PortPrefix
    Первые две цифры портов (например 15, 25, 35). По умолчанию 15.

.PARAMETER Version
    'current' (по умолчанию) или конкретная версия (например '8.3.22.1704').

.PARAMETER SetupPath
    Папка версии или общий корень с архивами. Передаётся в Install-1CPlatform.

.PARAMETER Credential
    PSCredential для USR1CV8. Если не задан — будет использован passfile или интерактивный запрос пароля.

.EXAMPLE
    Install-1CServer -PortPrefix 25 -Version 8.3.22.1704 -SetupPath "\\server\\distr"
#>
function Install-1CServer {
    param(
        [ValidatePattern('^\d{2}$')]
        [string]$PortPrefix = '15',

        [ValidateNotNullOrEmpty()]
        [string]$Version = 'current',

        [string]$SetupPath,

        [System.Management.Automation.PSCredential]$Credential
    )

    # 0) Если переданы SetupPath + конкретная Version — обязательно найдём нужный архив, иначе прервём установку
    $ResolvedSetupPath = $SetupPath
    if ($SetupPath -and $Version -ne 'current')
    {
        if (-not (Test-Path -LiteralPath $SetupPath)) {
            throw "Каталог не найден: $SetupPath"
        }

        $vU = ($Version -replace '\.','_')
        $wanted = "windows64full_$vU.rar"
        $leaf = Split-Path -Leaf $SetupPath

        $hit = $null
        try {
            if ($leaf -eq $Version) {
                # Ожидаем архив прямо в этой папке
                $hit = Get-ChildItem -LiteralPath $SetupPath -Filter $wanted -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $hit) {
                    # На всякий случай — проверим рекурсивно внутри версии
                    $hit = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue | Select-Object -First 1
                }
            } else {
                # Общий корень — ищем рекурсивно
                $hit = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        } catch {
            throw "Ошибка при поиске архива '$wanted' в '$SetupPath': $($_.Exception.Message)"
        }

        if ($hit) {
            $ResolvedSetupPath = $hit.DirectoryName
            Write-Host "Найдена версия $Version по архиву '$wanted'. Использую каталог: $ResolvedSetupPath" -ForegroundColor Cyan
        } else {
            throw "Не найден архив '$wanted' в '$SetupPath'. Установка прервана по требованию — версия должна соответствовать параметру -Version."
        }
    }

    # 1) Платформа — обязательно прокидываем -Version, если он указан
    if ($ResolvedSetupPath -and $Version -ne 'current') {
        Install-1CPlatform -SetupPath $ResolvedSetupPath -Version $Version
    }
    elseif ($ResolvedSetupPath) {
        Install-1CPlatform -SetupPath $ResolvedSetupPath
    }
    elseif ($SetupPath -and $Version -ne 'current') {
        Install-1CPlatform -SetupPath $SetupPath -Version $Version
    }
    elseif ($SetupPath) {
        Install-1CPlatform -SetupPath $SetupPath
    }
    else {
        if ($Version -ne 'current') {
            Install-1CPlatform -Version $Version
        } else {
            Install-1CPlatform
        }
    }

    # 2) Учётка USR1CV8 и креды
    $username  = "$env:COMPUTERNAME\USR1CV8"
    $localUser = Get-LocalUser -Name 'USR1CV8' -ErrorAction SilentlyContinue

    if (-not $Credential) {
        if (Test-Path 'C:\passfile.txt') {
            $secure = Get-Content 'C:\passfile.txt' | ConvertTo-SecureString
            $Credential = [pscredential]::new($username, $secure)
            Remove-Item 'C:\passfile.txt' -Force -ErrorAction SilentlyContinue
        }
        elseif ($localUser) {
            $secure = Read-Host -Prompt "Введите пароль для $username" -AsSecureString
            $Credential = [pscredential]::new($username, $secure)
        }
        else {
            New-1CServiceUser
            if (Test-Path 'C:\passfile.txt') {
                $secure = Get-Content 'C:\passfile.txt' | ConvertTo-SecureString
                $Credential = [pscredential]::new($username, $secure)
                Remove-Item 'C:\passfile.txt' -Force -ErrorAction SilentlyContinue
            } else {
                $secure = Read-Host -Prompt "Введите пароль для $username" -AsSecureString
                $Credential = [pscredential]::new($username, $secure)
            }
        }
    }

    # 3) Порты
    $BasePort  = "{0}41" -f $PortPrefix
    $CtrlPort  = "{0}40" -f $PortPrefix
    $RangePort = "{0}60:{0}91" -f $PortPrefix

    # 4) Пути и файлы: выбираем bin по Version
    $ProgramFiles1C = 'C:\Program Files\1cv8'
    $BinPath =
        if ($Version -and $Version -ne 'current') {
            Join-Path $ProgramFiles1C (Join-Path $Version 'bin')
        } else {
            Join-Path $ProgramFiles1C (Join-Path 'current' 'bin')
        }

    $RunExe   = Join-Path $BinPath 'ragent.exe'
    $ComCntrl = Join-Path $BinPath 'comcntr.dll'
    $Radmin   = Join-Path $BinPath 'radmin.dll'

    if ($Version -ne 'current' -and -not (Test-Path -LiteralPath $RunExe)) {
        throw "Не найден ragent.exe для версии $Version $RunExe. Проверь, что версия установлена корректно."
    }

    # 5) Имя службы: зависит только от PortPrefix
    if ($PortPrefix -eq '15') {
        $ServiceName = '1C:Enterprise 8.3 Server Agent Current'
        $SrvinfoName = 'srvinfo'
    }
    else {
        $ServiceName = "1C:Enterprise 8.3 Server Agent Current$PortPrefix"
        $SrvinfoName = "srvinfo$PortPrefix"
    }

    # 6) Каталог и ACL
    $SrvCatalog = Join-Path $ProgramFiles1C $SrvinfoName
    if (-not (Test-Path $SrvCatalog)) { New-Item -ItemType Directory -Path $SrvCatalog | Out-Null }
    $acl    = Get-Acl $SrvCatalog
    $access = New-Object System.Security.AccessControl.FileSystemAccessRule($username,'FullControl','ContainerInherit, ObjectInherit','None','Allow')
    $acl.SetAccessRule($access)
    $acl.SetAccessRuleProtection($false,$true)
    $acl | Set-Acl $SrvCatalog

    # 7) Регистрация DLL (тихо) — из выбранной папки bin
    if (Test-Path -LiteralPath $ComCntrl) { regsvr32.exe "`"$ComCntrl`"" -s }
    if (Test-Path -LiteralPath $Radmin)  { regsvr32.exe "`"$Radmin`""  -s }

    # 8) Команда запуска агента
    $ServicePath = @(
        "`"$RunExe`""
        '-srvc','-agent'
        '-regport', $BasePort
        '-port',    $CtrlPort
        '-range',   $RangePort
        '-debug'
        '-d',       "`"$SrvCatalog`""
    ) -join ' '

    # 9) Пересоздание службы
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
        sc.exe delete "$ServiceName" | Out-Null
        Start-Sleep -Seconds 1
    }

    New-Service -Name $ServiceName -BinaryPathName $ServicePath -DisplayName $ServiceName -StartupType Automatic -Credential $Credential
    Start-Service -Name $ServiceName

    Write-Host "OK: $ServiceName (bin=$BinPath; base=$BasePort ctrl=$CtrlPort range=$RangePort)"
}