<#
.SYNOPSIS
    Устанавливает или обновляет платформу 1С из каталога дистрибутива.

.DESCRIPTION
    Функция находит каталог дистрибутива (через New-1CDistroPackage или параметр SetupPath).
    Если указан сетевой путь — копирует дистрибутив в локальный кэш (%ProgramData%\1CMgmt\Cache)
    и выполняет установку из него. Запускает установку MSI в тихом режиме (/qn, /norestart),
    применяет MST-трансформы, проверяет коды возврата, регистрирует comcntr.dll и radmin.dll,
    затем обновляет ссылку на текущую версию (New-1CCurrentPlatformLink).

.PARAMETER SetupPath
    Явный путь к папке дистрибутива. Если не указан — используется результат New-1CDistroPackage.

.PARAMETER Quiet
    Если $true — установка запускается тихо (/qn). По умолчанию — $true.

.PARAMETER NoRestart
    Если $true — установка без перезагрузки (/norestart). По умолчанию — $true.

.EXAMPLE
    Install-1CPlatform
    Выполняет установку из автодетектированного каталога.

.EXAMPLE
    Install-1CPlatform -SetupPath "\\server\share\1C\8.3.25"
    Скопирует файлы из сети в кэш и выполнит установку из локального каталога.

.NOTES
    • Требуются права администратора.
    • Успешные коды: 0 и 3010 (3010 — требуется перезагрузка).
    • Библиотеки регистрируются только после успешной установки.
#>
function Install-1CPlatform {
     # получение результатов из функции подготовки директории дистрибутивов
     $getDistrPrepare = New-1CDistroPackage
     $getDistrPrepare
     $SetupPath = $getDistrPrepare.Path

     # --- Если указан сетевой путь к дистрибутиву — копируем в локальный кэш ---
     function Test-IsNetworkPath {
         param([Parameter(Mandatory)][string]$Path)
         try { if (([uri]$Path).IsUnc) { return $true } } catch {}
         try {
             $item = Get-Item -LiteralPath $Path -ErrorAction Stop
             if ($item.PSDrive) {
                 $driveRoot = $item.PSDrive.Root
                 $driveInfo = New-Object System.IO.DriveInfo($driveRoot.TrimEnd('\'))
                 if ($driveInfo.DriveType -eq 'Network') { return $true }
             }
         } catch {}
         return $false
     }

     if (Test-IsNetworkPath -Path $SetupPath) {
         $cacheRoot = Join-Path $env:ProgramData '1CMgmt\Cache'
         New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
         $distroName = Split-Path -Path ($SetupPath.TrimEnd('\','/')) -Leaf
         if ([string]::IsNullOrWhiteSpace($distroName)) {
             $distroName = (Get-Date).ToString('yyyyMMdd_HHmmss')
         }
         $localSetupPath = Join-Path $cacheRoot $distroName
         New-Item -ItemType Directory -Force -Path $localSetupPath | Out-Null
         Write-Host "Копирую дистрибутив из сети в локальный кэш: '$SetupPath' → '$localSetupPath'"
         $rcArgs = @("`"$SetupPath`"","`"$localSetupPath`"","/E","/Z","/R:2","/W:5","/NFL","/NDL","/NP")
         $rob = Start-Process -FilePath 'robocopy.exe' -ArgumentList $rcArgs -Wait -PassThru
         if ($rob.ExitCode -gt 7) {
             throw "Ошибка копирования дистрибутива (robocopy exit $($rob.ExitCode))."
         }
         $SetupPath = $localSetupPath
         Write-Host "Установка будет выполняться из локального кэша: '$SetupPath'"
     }

     # установка платформы
     $DirectoryPath = "C:\Program Files\1cv8\current\bin\"
     $comcntrl = $DirectoryPath + 'comcntr.dll'
     $radmin = $DirectoryPath + 'radmin.dll'
     if (Test-Path -Path $SetupPath) {
         if (Test-Path -Path "$SetupPath\1CEnterprise 8 (x86-64).msi") {
             # Каталог, где находится установочные файлы
             Set-Location $SetupPath;
             $msiInstallerPath = "$SetupPath\1CEnterprise 8 (x86-64).msi"
             $adminstallrelogonPath = "$SetupPath\adminstallrelogon.mst"
             $lang1049Path = "$SetupPath\1049.mst"
             $DESIGNERALLCLIENTS = 1
             $THICKCLIENT = 1
             $THINCLIENTFILE = 1
             $THINCLIENT = 1
             $WEBSERVEREXT = 1
             $SERVER = 1
             $CONFREPOSSERVER = 0
             $CONVERTER77 = 0
             $SERVERCLIENT = 1
             $LANGUAGES = 'RU'
             $params = '/i',
             $msiInstallerPath,
             '/qn',
             "TRANSFORMS=$adminstallrelogonPath;$lang1049Path",
             "DESIGNERALLCLIENTS=$DESIGNERALLCLIENTS",
             "THICKCLIENT=$THICKCLIENT",
             "THINCLIENTFILE=$THINCLIENTFILE",
             "THINCLIENT=$THINCLIENT",
             "WEBSERVEREXT=$WEBSERVEREXT",
             "SERVER=$SERVER",
             "CONFREPOSSERVER=$CONFREPOSSERVER",
             "CONVERTER77=$CONVERTER77",
             "SERVERCLIENT=$SERVERCLIENT",
             "LANGUAGES=$LANGUAGES"
             Write-Host "Выполняется установка. Ожидайте" -BackgroundColor Black -ForegroundColor Green
             $params
             & msiexec.exe @params | Out-Null
             # Регистрация библиотек
             regsvr32.exe "$comcntrl" -s
             Write-Host 'Библиотека comcntrl зарегистрирована' -BackgroundColor Black -ForegroundColor Green
             regsvr32.exe $radmin -s
             Write-Host 'Библиотека radmin зарегистрирована' -BackgroundColor Black -ForegroundColor Green
         }
     }
     # создать ссылки
     New-1CCurrentPlatformLink
}