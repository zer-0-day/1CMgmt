<#
.SYNOPSIS
    Устанавливает сервер 1С с заданным префиксом портов; поддерживает -SetupPath, -Version и -Credential.

.DESCRIPTION
    1) Проверяет доступность портов и существование службы.
    2) Если платформа уже установлена и служба не существует — создаёт только службу (без установки MSI).
    3) Если платформа не установлена — выполняет полную установку через Install-1CPlatform.
    4) Готовит учётку USR1CV8 (Credential → passfile → интерактив).
    5) Создаёт каталог данных службы srvinfoXX (даже для 15 → srvinfo15).
    6) Создаёт ссылку currentXX для нестандартных портов.
    7) Регистрирует comcntr.dll и radmin.dll из выбранной папки bin.
    8) Создаёт службу агента.
       Имя службы зависит ТОЛЬКО от PortPrefix:
         15  → '1C:Enterprise 8.3 Server Agent Current'
         25  → '1C:Enterprise 8.3 Server Agent Current25'
         35  → '1C:Enterprise 8.3 Server Agent Current35'
       Путь к ragent.exe зависит от Version:
         Version='current' (или не задан) → ...\current\bin\ragent.exe
         Иная Version (8.3.x.x)           → ...\<Version>\bin\ragent.exe
    9) Создаёт лог-файл установки в C:\1Cv8.adm\logs\

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
    
.EXAMPLE
    Install-1CServer -PortPrefix 35
    # Создаст службу Current35 на уже установленной платформе
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

    # Валидация версии
    if ($Version -and $Version -ne 'current') {
        if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
            throw "Некорректный формат версии: '$Version'. Ожидается формат 8.3.xx.xxxx"
        }
    }

    # Создание лог-файла
    $logDir = 'C:\1Cv8.adm\logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logPath = Join-Path $logDir "install_${PortPrefix}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $logPath -Append

    try {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Установка сервера 1С" -ForegroundColor Cyan
        Write-Host "Префикс портов: $PortPrefix" -ForegroundColor Cyan
        Write-Host "Версия: $Version" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan

        # Проверка доступности портов
        Write-Host "Проверка доступности портов..." -ForegroundColor Yellow
        if (-not (Test-1CPortAvailable -PortPrefix $PortPrefix)) {
            $confirm = Read-Host "Некоторые порты заняты. Продолжить установку? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "Установка отменена пользователем." -ForegroundColor Yellow
                return
            }
        } else {
            Write-Host "Порты свободны." -ForegroundColor Green
        }

        # Проверка существующей службы
        $ServiceName = if ($PortPrefix -eq '15') {
            '1C:Enterprise 8.3 Server Agent Current'
        } else {
            "1C:Enterprise 8.3 Server Agent Current$PortPrefix"
        }

        $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Host "Служба '$ServiceName' уже существует (статус: $($existingService.Status))" -ForegroundColor Yellow
            $confirm = Read-Host "Пересоздать службу? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "Установка отменена пользователем." -ForegroundColor Yellow
                return
            }
        }

        # Определяем путь к нужной версии
        $pf1c = 'C:\Program Files\1cv8'
        $versionPath = if ($Version -and $Version -ne 'current') {
            Join-Path $pf1c $Version
        } else {
            Join-Path $pf1c 'current'
        }

        # Проверяем, установлена ли уже нужная версия платформы
        $ragentPath = Join-Path $versionPath 'bin\ragent.exe'
        $platformInstalled = Test-Path $ragentPath

        # Определяем, нужно ли устанавливать платформу
        $skipPlatformInstall = $platformInstalled -and (-not $existingService)

        if ($skipPlatformInstall) {
            Write-Host "`nПлатформа версии '$Version' уже установлена." -ForegroundColor Green
            Write-Host "Создание службы для портов ${PortPrefix}xx без переустановки платформы..." -ForegroundColor Cyan
        } else {
            Write-Host "`nУстановка/обновление платформы..." -ForegroundColor Cyan
        }

        # Установка платформы (если требуется)
        if (-not $skipPlatformInstall) {
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
        }

        # Создание ссылки currentXX для нестандартных портов
        if ($PortPrefix -ne '15') {
            Write-Host "`nСоздание ссылки current${PortPrefix}..." -ForegroundColor Cyan
            New-1CCurrentPlatformLink -PortPrefix @([int]$PortPrefix)
        }

        # Учётка USR1CV8 и креды
        Write-Host "`nПодготовка учётной записи USR1CV8..." -ForegroundColor Cyan
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

        # Каталог данных и ACL
        Write-Host "`nСоздание каталога данных службы: $SrvCatalog" -ForegroundColor Cyan
        if (-not (Test-Path $SrvCatalog)) { 
            New-Item -ItemType Directory -Path $SrvCatalog | Out-Null 
            Write-Host "Каталог создан." -ForegroundColor Green
        } else {
            Write-Host "Каталог уже существует." -ForegroundColor DarkGray
        }

        Write-Host "Установка прав доступа для $userSam..." -ForegroundColor Cyan
        $acl    = Get-Acl $SrvCatalog
        $access = New-Object System.Security.AccessControl.FileSystemAccessRule($userSam,'FullControl','ContainerInherit, ObjectInherit','None','Allow')
        $acl.SetAccessRule($access)
        $acl.SetAccessRuleProtection($false,$true)
        $acl | Set-Acl $SrvCatalog
        Write-Host "Права установлены." -ForegroundColor Green

        # Регистрация DLL из выбранной bin (только если не пропускали установку платформы)
        if (-not $skipPlatformInstall) {
            Write-Host "`nРегистрация COM-компонентов..." -ForegroundColor Cyan
            if (Test-Path -LiteralPath $ComCntrl) { 
                & regsvr32.exe "`"$ComCntrl`"" -s 
                Write-Host "comcntr.dll зарегистрирован." -ForegroundColor Green
            }
            if (Test-Path -LiteralPath $Radmin) { 
                & regsvr32.exe "`"$Radmin`"" -s 
                Write-Host "radmin.dll зарегистрирован." -ForegroundColor Green
            }
        }

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
        Write-Host "`nСоздание службы $ServiceName..." -ForegroundColor Cyan
        $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Остановка существующей службы..." -ForegroundColor Yellow
            Stop-Service -Name $ServiceName -ErrorAction SilentlyContinue
            Write-Host "Удаление существующей службы..." -ForegroundColor Yellow
            sc.exe delete "$ServiceName" | Out-Null
            Start-Sleep -Seconds 1
        }

        New-Service -Name $ServiceName -BinaryPathName $ServicePath -DisplayName $ServiceName -StartupType Automatic -Credential $Credential
        Write-Host "Служба создана." -ForegroundColor Green
        
        Write-Host "Запуск службы..." -ForegroundColor Cyan
        Start-Service -Name $ServiceName
        Write-Host "Служба запущена." -ForegroundColor Green

        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Установка завершена успешно!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Служба:    $ServiceName" -ForegroundColor White
        Write-Host "Бинарники: $BinPath" -ForegroundColor White
        Write-Host "Данные:    $SrvCatalog" -ForegroundColor White
        Write-Host "Порты:     base=$BasePort, ctrl=$CtrlPort, range=$RangePort" -ForegroundColor White
        Write-Host "Лог:       $logPath" -ForegroundColor White
        Write-Host "========================================`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "ОШИБКА УСТАНОВКИ" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Лог: $logPath" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Red
        throw
    }
    finally {
        Stop-Transcript
    }
}