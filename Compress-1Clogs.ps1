<#
.SYNOPSIS
    Архивация журналов регистрации информационных баз 1С.

.DESCRIPTION
    Для каждого пути srvinfo* из Get-1C.SrvinfoPaths (или одного, указанного через -Path):
    1) Находит подкаталоги reg_*  
    2) В каждом reg_* находит подкаталоги по GUID (UUID)  
    3) В каждом UUID-подкаталоге идет в папку 1Cv8Log  
    4) Удаляет ZIP-архивы старше ArchiveDays  
    5) Архивирует файлы .lgx и .lgp старше FileDays  
    6) Логирует все действия в C:\ClearCashe1CLog.txt

.PARAMETER FileDays
    Дней хранения исходных файлов логов перед архивацией (по умолчанию 7).

.PARAMETER ArchiveDays
    Дней хранения ZIP-архивов перед удалением (по умолчанию 90).

.PARAMETER Path
    (опционально) Конкретный путь srvinfo. Если не указан — берутся все из (Get-1C).SrvinfoPaths.

.EXAMPLE
    # По всем srvinfo*
    Compress-1Clogs

.EXAMPLE
    # Только для D:\srvinfo17
    Compress-1Clogs -Path 'D:\srvinfo17'
#>
function Compress-1Clogs {
    [CmdletBinding()]
    param(
        [int]    $FileDays     = 7,
        [int]    $ArchiveDays  = 90,
        [string] $Path
    )

    # --- Настройки логирования ---
    $LogFile  = 'C:\ClearCashe1CLog.txt'
    $NowStamp = { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }

    # Убедимся, что лог существует и сбросим старый
    if (-not (Test-Path $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    } elseif ((Get-Item $LogFile).CreationTime -lt (Get-Date).AddDays(-7)) {
        Remove-Item $LogFile -Force
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }

    # Собираем корни srvinfo
    try {
        $roots = if ($Path) { @($Path) } else { (Get-1C).SrvinfoPaths }
    }
    catch {
        Write-Error "Не удалось получить список путей srvinfo: $($_.Exception.Message)"
        return
    }

    foreach ($root in $roots) {
        Write-Verbose "Обработка корня: $root"

        # 1) Ищем папки reg_*
        $regDirs = Get-ChildItem -Path $root -Directory -Filter 'reg_*' -ErrorAction SilentlyContinue
        foreach ($reg in $regDirs) {
            # 2) Внутри reg_* ищем UUID-папки
            $uuidDirs = Get-ChildItem -Path $reg.FullName -Directory |
                        Where-Object Name -match '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$'

            foreach ($uuid in $uuidDirs) {
                # 3) Переходим в 1Cv8Log
                $logDir = Join-Path $uuid.FullName '1Cv8Log'
                if (-not (Test-Path $logDir)) {
                    Add-Content $LogFile "$(& $NowStamp)  Пропущено (нет папки): $logDir"
                    continue
                }

                # 4) Удаляем старые ZIP-архивы
                Get-ChildItem -Path $logDir -Recurse -File -Filter '*.zip' |
                  Where-Object LastWriteTime -lt (Get-Date).AddDays(-$ArchiveDays) |
                  ForEach-Object {
                      try {
                          Remove-Item $_.FullName -Force
                          Add-Content $LogFile "$(& $NowStamp)  Удалён архив: $($_.FullName)"
                      }
                      catch {
                          Add-Content $LogFile "$(& $NowStamp)  ОШИБКА удаления архива $($_.FullName): $($_.Exception.Message)"
                      }
                  }

                # 5) Архивируем файлы .lgx и .lgp
                Get-ChildItem -Path $logDir -Recurse -File |
                  Where-Object {
                      ($_.Extension -in '.lgx','.lgp') -and
                      $_.LastWriteTime -lt (Get-Date).AddDays(-$FileDays)
                  } |
                  ForEach-Object {
                      $origFile = $_.FullName
                      $zipName  = "{0}_{1}.zip" -f $_.BaseName, ($_.Extension.TrimStart('.'))
                      $zipPath  = Join-Path $_.DirectoryName $zipName

                      try {
                          Compress-Archive -LiteralPath $origFile `
                                           -DestinationPath $zipPath `
                                           -CompressionLevel Fastest `
                                           -Force
                          Add-Content $LogFile "$(& $NowStamp)  Создан архив: $zipPath из $origFile"

                          # Удаляем исходный только после успешного создания
                          Remove-Item $origFile -Force
                      }
                      catch {
                          Add-Content $LogFile "$(& $NowStamp)  ОШИБКА архивации $origFile $($_.Exception.Message)"
                      }
                  }
            }
        }
    }

    Write-Host "Compress-1Clogs завершён. Подробности в логе: $LogFile"
}
