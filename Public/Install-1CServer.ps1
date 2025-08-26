<#
.SYNOPSIS
    Простой установщик сервера 1С (первый/второй/третий и т.д.) с выбором префикса портов.

.DESCRIPTION
    Линейная установка без лишней «магии»:
      1) Ставит/обновляет платформу (через Install-1CPlatform).
      2) Создаёт пользователя USR1CV8 и читает пароль из C:\passfile.txt.
      3) Готовит каталог srvinfo(XX) и права.
      4) Регистрирует comcntr.dll и radmin.dll.
      5) Создаёт и запускает службу агента с портами по префиксу.

    Префиксы:
      • 15 → 1540/1541 + диапазон 1560:1591, каталог srvinfo
      • 25 → 2540/2541 + диапазон 2560:2591, каталог srvinfo25
      • 35 → 3540/3541 + диапазон 3560:3591, каталог srvinfo35
      и т.д.

.PARAMETER PortPrefix
    Первые две цифры портов (например 15, 25, 35). По умолчанию 15.

.PARAMETER Version
    Каталог версии платформы в "C:\Program Files\1cv8\<Version>\bin" (например 'current' или '8.3.xx.xxxx').
    По умолчанию: current.

.EXAMPLE
    Install-1CServer
    # Установит «первый» сервер с префиксом 15 (как раньше).

.EXAMPLE
    Install-1CServer -PortPrefix 25
    # Добавит второй сервер на портах 25xx и в каталоге srvinfo25.

.EXAMPLE
    Install-1CServer -PortPrefix 35 -Version '8.3.25.1546'
    # Установит сервер на конкретной версии платформы.
#>
function Install-1CServer {
    param(
        [ValidatePattern('^\d{2}$')]
        [string]$PortPrefix = '15',

        [ValidateNotNullOrEmpty()]
        [string]$Version = 'current'   # каталог в C:\Program Files\1cv8\<Version>\bin
    )

    # 1) Платформа
    Install-1CPlatform

    # 2) Пользователь USR1CV8 и креды
    $username = "$env:COMPUTERNAME\USR1CV8"
    New-1CServiceUser
    if (-not (Test-Path 'C:\passfile.txt')) {
        Write-Host "Не найден C:\passfile.txt (создаётся командой New-1CServiceUser)" -ForegroundColor Red
        return
    }
    $usrPass = Get-Content 'C:\passfile.txt' | ConvertTo-SecureString
    $cred    = New-Object pscredential ($username, $usrPass)
    Remove-Item 'C:\passfile.txt' -Force -ErrorAction SilentlyContinue

    # 3) Порты по префиксу
    $BasePort  = "{0}41" -f $PortPrefix
    $CtrlPort  = "{0}40" -f $PortPrefix
    $RangePort = "{0}60:{0}91" -f $PortPrefix

    # 4) Пути
    $ProgramFiles1C = 'C:\Program Files\1cv8'
    $SrvinfoName    = if ($PortPrefix -eq '15') { 'srvinfo' } else { "srvinfo$PortPrefix" }
    $SrvCatalog     = Join-Path $ProgramFiles1C $SrvinfoName
    $BinPath        = Join-Path $ProgramFiles1C (Join-Path $Version 'bin')
    $RunExe         = Join-Path $BinPath 'ragent.exe'
    $ComCntrl       = Join-Path $BinPath 'comcntr.dll'
    $Radmin         = Join-Path $BinPath 'radmin.dll'

    # 5) Имя службы (для 15 — старое имя, для остальных — с меткой)
    $ServiceName = if ($PortPrefix -eq '15') { '1C:Enterprise 8.3 Server Agent Current' } else { "1C:Enterprise 8.3 Server Agent $Version-$PortPrefix" }

    # 6) Готовим каталог и ACL
    if (-not (Test-Path $SrvCatalog)) { New-Item -ItemType Directory -Path $SrvCatalog | Out-Null }
    $acl    = Get-Acl $SrvCatalog
    $access = New-Object System.Security.AccessControl.FileSystemAccessRule($username,'FullControl','ContainerInherit, ObjectInherit','None','Allow')
    $acl.SetAccessRule($access)
    $acl.SetAccessRuleProtection($false,$true)
    $acl | Set-Acl $SrvCatalog

    # 7) Регистрация DLL
    regsvr32.exe "`"$ComCntrl`"" -s
    Write-Host 'Библиотека comcntr.dll зарегистрирована' -ForegroundColor Green
    regsvr32.exe "`"$Radmin`"" -s
    Write-Host 'Библиотека radmin.dll зарегистрирована' -ForegroundColor Green

    # 8) Команда запуска агента
    $ServicePath = @(
        "`"$RunExe`""
        '-srvc'
        '-agent'
        '-regport', $BasePort
        '-port',    $CtrlPort
        '-range',   $RangePort
        '-debug'
        '-d',       "`"$SrvCatalog`""
    ) -join ' '

    # 9) Создание/пересоздание службы (просто и предсказуемо)
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Служба уже существует: $ServiceName — остановка и переcоздание..." -ForegroundColor Yellow
        Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
        sc.exe delete "$ServiceName" | Out-Null
        Start-Sleep -Seconds 1
    }

    New-Service -Name $ServiceName -BinaryPathName $ServicePath -DisplayName $ServiceName -StartupType Automatic -Credential $cred
    Start-Service -Name $ServiceName
    Write-Host "Служба '$ServiceName' запущена. Порты: base=$BasePort ctrl=$CtrlPort range=$RangePort" -ForegroundColor Green
}