<#
    .SYNOPSIS
        Подготовка директории с дистрибутивами

    .DESCRIPTION
        Подготовка директории с дистрибутивами. Распаковка серверных архивов
        формата windows64full_8_3_xx_xxxx.rar (например: windows64full_8_3_22_1704.rar)
        и перенос содержимого в структуру:
            <1cv8.adm>\<версия>\Server\64

        Функция ищет архивы ИСКЛЮЧИТЕЛЬНО серверного формата windows64full_*.rar
        в корне каталога дистрибутивов (Find-1CDistroFolder → обычно 1cv8.adm).
        Клиентские архивы/папки (windows_*) игнорируются.

        На выходе возвращает объект с полями:
          VersionString, Version ([Version]), Arch ('64'), Path (путь к распакованной папке).
#>
function New-1CDistroPackage {
    if (Find-1CDistroFolder) {
        Write-Host "Тестирование предподготовки дистрибутивов" -ForegroundColor Cyan

        # Основная папка с дистрибутивами (например, X:\1cv8.adm)
        $DistrDirectory = Find-1CDistroFolder
        if (-not (Test-Path -LiteralPath $DistrDirectory)) {
            Write-Error "Папка с дистрибутивами не найдена: $DistrDirectory"
            return
        }

        # Ищем ТОЛЬКО серверные архивы .rar вида windows64full_8_3_*.rar
        $distributionItems = Get-ChildItem -LiteralPath $DistrDirectory -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue

        if (-not $distributionItems -or $distributionItems.Count -eq 0) {
            Write-Error "В '$DistrDirectory' не найдено серверных архивов вида windows64full_8_3_xx_xxxx.rar (например: windows64full_8_3_22_1704.rar)."
            return
        }

        $results = @()

        foreach ($item in $distributionItems) {
            # Для архивов берём BaseName без расширения
            $itemName = $item.BaseName

            # Ожидаемый формат имени: windows64full_8_3_22_1704
            if ($itemName -match '^windows64full_(?<version>\d+_\d+_\d+_\d+)$') {
                $arch = '64'  # сервер — всегда 64-бит
                $versionStr = $matches['version'] -replace '_', '.'
                try {
                    $versionObj = [Version]$versionStr
                }
                catch {
                    Write-Warning "Не удалось преобразовать версию '$versionStr' из '$itemName'. Пропускаем."
                    continue
                }
            }
            else {
                Write-Warning "Архив '$itemName' не соответствует ожидаемому формату windows64full_8_3_xx_xxxx. Пропускаем."
                continue
            }

            # Формируем целевую структуру:
            # <1cv8.adm>\<версия>\Server\64
            $targetVersionFolder = Join-Path -Path $DistrDirectory -ChildPath ("{0}\Server" -f $versionStr)
            $targetSubFolder     = Join-Path -Path $targetVersionFolder -ChildPath $arch

            if (-not (Test-Path -LiteralPath $targetSubFolder)) {
                New-Item -ItemType Directory -Path $targetSubFolder -Force | Out-Null
            }

            # Распаковываем RAR (требуется 7-Zip)
            $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
            if (-not (Test-Path -LiteralPath $sevenZipPath)) {
                Write-Error "7-Zip не найден по пути '$sevenZipPath'. Невозможно извлечь RAR-архив."
                continue
            }

            # Если целевой каталог уже не пуст — пропускаем извлечение
            $targetNotEmpty = (Test-Path -LiteralPath $targetSubFolder) -and ((Get-ChildItem -LiteralPath $targetSubFolder -Force | Measure-Object).Count -gt 0)
            if ($targetNotEmpty) {
                Write-Host "Каталог '$targetSubFolder' уже содержит файлы. Извлечение '$($item.Name)' пропускается." -ForegroundColor DarkYellow
            }
            else {
                Write-Host "Извлекаем RAR-архив '$($item.Name)' в '$targetSubFolder'" -ForegroundColor Yellow
                & $sevenZipPath x $item.FullName -o"$targetSubFolder" -y | Out-Null
            }

            Write-Host "Обработка '$itemName' завершена. Содержимое: '$targetSubFolder'" -ForegroundColor Green

            $results += [PSCustomObject]@{
                VersionString = $versionStr
                Version       = $versionObj
                Arch          = $arch
                Path          = $targetSubFolder
            }
        }

        if ($results.Count -eq 0) {
            Write-Error "Не удалось подготовить ни одного серверного дистрибутива."
            return
        }

        # Возвращаем объект с максимальной версией
        $latest = $results | Sort-Object Version -Descending | Select-Object -First 1
        return $latest
    }
    else {
        throw "Папка с дистрибутивами не найдена"
    }
}