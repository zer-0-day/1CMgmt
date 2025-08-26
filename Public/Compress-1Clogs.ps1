<#
.SYNOPSIS
    Архивирует и очищает журналы регистрации (ЖР) 1С в каталогах srvinfo.

.DESCRIPTION
    Для каждого пути srvinfo* из (Get-1C).SrvinfoPaths или одного, указанного через -Path:
      1) Находит подкаталоги reg_*
      2) В каждом reg_* находит подкаталоги по GUID (UUID)
      3) В каждом UUID-подкаталоге заходит в папку 1Cv8Log
      4) Удаляет ZIP-архивы старше ArchiveDays
      5) Архивирует файлы .lgx и .lgp, старше FileDays (один файл -> один ZIP)
      6) Ведёт лог выполнения в C:\ClearCashe1CLog.txt

    Скрипт НЕ меняет структуру каталогов и обрабатывает только файлы логов (.lgx/.lgp) и ZIP-архивы.
    Удаление исходного файла выполняется ТОЛЬКО после успешного создания ZIP.

.PARAMETER FileDays
    Количество дней, спустя которое исходные файлы журналов (.lgx/.lgp) будут заархивированы.
    Значение по умолчанию: 7.

.PARAMETER ArchiveDays
    Количество дней, по истечении которых ZIP-архивы будут удалены.
    Значение по умолчанию: 90.

.PARAMETER Path
    Необязательный. Конкретный путь к каталогу srvinfo (например, 'D:\srvinfo17').
    Если не указан — пути берутся из (Get-1C).SrvinfoPaths.

.INPUTS
    System.Int32, System.String.
    Параметры можно передавать по конвейеру по имени (PS 3.0+ автоматически сопоставляет по именам).

.OUTPUTS
    Нет. Функция пишет прогресс и итоги в консоль/лог, полезные артефакты — ZIP-файлы в каталоге 1Cv8Log.

.EXAMPLE
    PS> Compress-1Clogs
    Выполнит архивацию и очистку ЖР во всех каталогах srvinfo, обнаруженных функцией Get-1C.

.EXAMPLE
    PS> Compress-1Clogs -Path 'D:\srvinfo17'
    Обработает только указанный каталог srvinfo.

.EXAMPLE
    PS> Compress-1Clogs -FileDays 3 -ArchiveDays 30
    Заархивирует файлы логов старше 3 дней, удалит ZIP-архивы старше 30 дней.

.NOTES
    Требования:
      • Windows PowerShell 5.1+ (для Compress-Archive)
      • Доступ на чтение/запись к каталогам srvinfo и к логу C:\ClearCashe1CLog.txt
      • Наличие функции Get-1C (для автопоиска путей srvinfo)

    Лог: C:\ClearCashe1CLog.txt (пересоздаётся, если старше 7 дней).

    Важное:
      • На macOS/Linux функция загрузится, но выполняться не будет из-за Windows-специфичных путей.
      • Для крупных логов архивирование может занять время; используйте планировщик задач для регулярного запуска.

.LINK
    Get-1C
    Get-Help Compress-Archive
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
