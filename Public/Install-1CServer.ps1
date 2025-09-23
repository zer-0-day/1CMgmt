<#
.SYNOPSIS
    Устанавливает сервер 1С с заданным префиксом портов; поддерживает -SetupPath, -Version и -Credential.

.DESCRIPTION
    1) Ставит/обновляет платформу (Install-1CPlatform).
       • Если -SetupPath указывает на распакованный дистрибутив (есть MSI) — архив НЕ ищется.
       • Если задана -Version — ставится строго этот билд (проверка).
    2) Готовит учётку USR1CV8 (Credential → passfile → интерактив).
    3) Создаёт каталог данных службы srvinfoXX (даже для 15 → srvinfo15).
    4) Регистрирует comcntr.dll и radmin.dll из выбранной папки bin.
    5) Создаёт службу агента.
       Имя службы зависит ТОЛЬКО от PortPrefix:
         15  → '1C:Enterprise 8.3 Server Agent Current'
         25  → '1C:Enterprise 8.3 Server Agent Current25'
         35  → '1C:Enterprise 8.3 Server Agent Current35'
       Путь к ragent.exe зависит от Version:
         Version='current' (или не задан) → ...\current\bin\ragent.exe
         Иная Version (8.3.x.x)           → ...\<Version>\bin\ragent.exe

.PARAMETER PortPrefix
    Первые две цифры портов (15/25/35/...). По умолчанию 15.

.PARAMETER Version
    'current' (по умолчанию) или конкретная версия (напр. '8.3.22.1704').

.PARAMETER SetupPath
    Папка версии (распакованной) или общий корень с архивами (UNC/локальный). Передаётся в Install-1CPlatform.

.PARAMETER Credential
    PSCredential для USR1CV8. Если не задан — будет использован passfile или интерактивный запрос пароля.

.EXAMPLE
    Install-1CServer -PortPrefix 25 -Version 8.3.22.1704 -SetupPath "\\server\\distr"
#>
function Install-1CServer {
    [CmdletBinding()]
    param(
        [ValidatePattern('^\d{2}$')]
        [string]$PortPrefix = '15',

        [ValidateNotNullOrEmpty()]
        [string]$Version = 'current',

        [string]$SetupPath,

        [System.Management.Automation.PSCredential]$Credential
    )

    # Требуются права администратора
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Требуются права администратора."
    }

    # Если задан SetupPath, проверим — это распакованный дистрибутив?
    $ResolvedSetup = $SetupPath
    if ($SetupPath -and (Test-Path -LiteralPath $SetupPath)) {
        $msiName = '1CEnterprise 8 (x86-64).msi'
        $msiProbe = Join-Path $SetupPath $msiName
        if (-not (Test-Path -LiteralPath $msiProbe)) {
            $msiProbe = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $msiName -File -ErrorAction SilentlyContinue |
                        Select-Object -First 1 | ForEach-Object FullName
        }
        if ($msiProbe) {
            # SetupPath указывает на распакованную структуру → использовать её напрямую
            $ResolvedSetup = Split-Path -Path $msiProbe -Parent
            Write-Host "Использую уже распакованный дистрибутив: $ResolvedSetup" -ForegroundColor Cyan
        }
        elseif ($Version -ne 'current') {
            # Если не распаковано, но версия задана — убедимся, что архив нужной версии существует, иначе прервёмся.
            $vU = $Version -replace '\.','_'
            $wanted = "windows64full_$vU.rar"
            $hit = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter $wanted -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $hit) {
                throw "Не найден архив '$wanted' в '$SetupPath'. Установка прервана — версия должна соответствовать -Version."
            }
            # Пусть Install-1CPlatform сам выполнит копирование/распаковку из архива.
        }
    }

    # Платформа (обязательно прокидываем -Version, если он задан)
    if ($ResolvedSetup -and $Version -ne 'current') {
        Install-1CPlatform -SetupPath $ResolvedSetup -Version $Version
    } elseif ($ResolvedSetup) {
        Install-1CPlatform -SetupPath $ResolvedSetup
    } elseif ($SetupPath -and $Version -ne 'current') {
        Install-1CPlatform -SetupPath $SetupPath -Version $Version
    } elseif ($SetupPath) {
        Install-1CPlatform -SetupPath $SetupPath
    } else {
        if ($Version -ne 'current') { Install-1CPlatform -Version $Version } else { Install-1CPlatform }
    }

    # Учётка USR1CV8 и креды
    $machine = $env:COMPUTERNAME
    $userSam = "$machine\USR1CV8"
    $localUser = Get-LocalUser -Name 'USR1CV8' -ErrorAction SilentlyContinue

    if (-not $Credential) {
        if (Test-Path 'C:\passfile.txt') {
            $sec = Get-Content 'C:\passfile.txt' | ConvertTo-SecureString
            $Credential = [pscredential]::new($userSam, $sec)
            Remove-Item 'C:\passfile.txt' -Force -ErrorAction SilentlyContinue
        }
        elseif ($localUser) {
            $sec = Read-Host -Prompt "Введите пароль для $userSam" -AsSecureString
            $Credential = [pscredential]::new($userSam, $sec)
        }
        else {
            New-1CServiceUser
            if (Test-Path 'C:\passfile.txt') {
                $sec = Get-Content 'C:\passfile.txt' | ConvertTo-SecureString
                $Credential = [pscredential]::new($userSam, $sec)
                Remove-Item 'C:\passfile.txt' -Force -ErrorAction SilentlyContinue
            } else {
                $sec = Read-Host -Prompt "Введите пароль для $userSam" -AsSecureString
                $Credential = [pscredential]::new($userSam, $sec)
            }
        }
    }

    # Порты
    $BasePort  = "{0}41" -f $PortPrefix
    $CtrlPort  = "{0}40" -f $PortPrefix
    $RangePort = "{0}60:{0}91" -f $PortPrefix

    # Пути: бинари зависят от Version; каталог данных службы ВСЕГДА с суффиксом PortPrefix (даже для 15 → srvinfo15)
    $pf1c = 'C:\Program Files\1cv8'
    $srvInfoDir = "srvinfo$PortPrefix"
    $SrvCatalog = Join-Path $pf1c $srvInfoDir

    $BinPath =
        if ($Version -and $Version -ne 'current') {
            Join-Path $pf1c (Join-Path $Version 'bin')
        } else {
            Join-Path $pf1c (Join-Path 'current' 'bin')
        }

    $RunExe   = Join-Path $BinPath 'ragent.exe'
    $ComCntrl = Join-Path $BinPath 'comcntr.dll'
    $Radmin   = Join-Path $BinPath 'radmin.dll'

    if (-not (Test-Path -LiteralPath $RunExe)) {
        throw "Не найден ragent.exe: $RunExe. Проверь, что нужная версия установлена."
    }

    # Имя службы зависит только от PortPrefix
    $ServiceName = if ($PortPrefix -eq '15') {
        '1C:Enterprise 8.3 Server Agent Current'
    } else {
        "1C:Enterprise 8.3 Server Agent Current$PortPrefix"
    }

    # Каталог данных и ACL
    if (-not (Test-Path $SrvCatalog)) { New-Item -ItemType Directory -Path $SrvCatalog | Out-Null }
    $acl    = Get-Acl $SrvCatalog
    $access = New-Object System.Security.AccessControl.FileSystemAccessRule($userSam,'FullControl','ContainerInherit, ObjectInherit','None','Allow')
    $acl.SetAccessRule($access)
    $acl.SetAccessRuleProtection($false,$true)
    $acl | Set-Acl $SrvCatalog

    # Регистрация DLL из выбранной bin
    if (Test-Path -LiteralPath $ComCntrl) { & regsvr32.exe "`"$ComCntrl`"" -s }
    if (Test-Path -LiteralPath $Radmin)  { & regsvr32.exe "`"$Radmin`""  -s }

    # Команда агента
    $ServicePath = @(
        "`"$RunExe`""
        '-srvc','-agent'
        '-regport', $BasePort
        '-port',    $CtrlPort
        '-range',   $RangePort
        '-debug'
        '-d',       "`"$SrvCatalog`""
    ) -join ' '

    # Пересоздание службы
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
        sc.exe delete "$ServiceName" | Out-Null
        Start-Sleep -Seconds 1
    }

    New-Service -Name $ServiceName -BinaryPathName $ServicePath -DisplayName $ServiceName -StartupType Automatic -Credential $Credential
    Start-Service -Name $ServiceName

    Write-Host "OK: $ServiceName (bin=$BinPath; data=$SrvCatalog; base=$BasePort ctrl=$CtrlPort range=$RangePort)"
}