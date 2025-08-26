<#
    .SYNOPSIS
        Подгтовка директории с дистрибутивами
	    .DESCRIPTION
        Подготовка директории с дистрибутивами. Распаковка архивов, перенос в директорию, соответствующую требованиям "номер версии\сервер(клиент)\разрядность"
    #>
function New-1CDistroPackage {
    if (Find-1CDistroFolder) {
        Write-Host "Тестирование предпоготовки дистрибутивов" -ForegroundColor Cyan

        # Получаем основную папку с дистрибутивами (например, X:\1cv8.adm)
        $DistrDirectory = Find-1CDistroFolder
        if (-not (Test-Path $DistrDirectory)) {
            Write-Error "Папка с дистрибутивами не найдена: $DistrDirectory"
            return
        }

        # Получаем все элементы, начинающиеся с "windows" (папки и архивы)
        $distributionItems = Get-ChildItem -Path $DistrDirectory | Where-Object { $_.Name -like "windows*" }

        # Массив для хранения информации по всем обработанным дистрибутивам
        $results = @()

        foreach ($item in $distributionItems) {
            # Определяем имя элемента для парсинга (для файлов берем BaseName, для папок – Name)
            $itemName = if ($item.PSIsContainer) { $item.Name } else { $item.BaseName }

            # Парсим имя: ожидаемые форматы:
            # 64‑бит: windows64full_8_3_22_1709
            # 32‑бит: windows_8_3_22_1709
            if ($itemName -match "^windows(?<arch>64full)?_(?<version>\d+_\d+_\d+_\d+)$") {
                $arch = if ($matches['arch']) { "64" } else { "36" }
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
                Write-Warning "Папка или архив '$itemName' не соответствует ожидаемому формату. Пропускаем."
                continue
            }

            # Формируем целевую структуру внутри основной папки:
            # - Папка с номером версии, внутри которой должна быть папка "Server",
            #   а в ней – подпапка с разрядностью (64 для 64‑бит, 36 для 32‑бит)
            $targetVersionFolder = Join-Path -Path $DistrDirectory -ChildPath ("{0}\Server" -f $versionStr)
            $targetSubFolder     = Join-Path -Path $targetVersionFolder -ChildPath $arch

            # Если каталог назначения не существует, создаём его
            if (-not (Test-Path $targetSubFolder)) {
                New-Item -ItemType Directory -Path $targetSubFolder -Force | Out-Null
            }

            if ($item.PSIsContainer) {
                # Если элемент – папка, используем её содержимое
                $sourceFolder = $item.FullName

                Write-Host "Копирование содержимого папки '$itemName' в '$targetSubFolder'" -ForegroundColor Yellow
                Copy-Item -Path "$sourceFolder\*" -Destination $targetSubFolder -Force -Recurse
            }
            else {
                # Если элемент – файл (архив), проверяем расширение
                if ($item.Extension -ieq ".zip" -or $item.Extension -ieq ".rar") {
                    # Если целевой каталог уже существует и не пуст, пропускаем извлечение
                    $targetNotEmpty = (Test-Path $targetSubFolder) -and ((Get-ChildItem -Path $targetSubFolder -Force | Measure-Object).Count -gt 0)
                    if ($targetNotEmpty) {
                        Write-Host "Каталог '$targetSubFolder' уже существует и содержит файлы. Извлечение архива '$($item.Name)' пропускается." -ForegroundColor DarkYellow
                    }
                    else {
                        if ($item.Extension -ieq ".zip") {
                            Write-Host "Извлекаем ZIP-архив '$($item.Name)' непосредственно в '$targetSubFolder'" -ForegroundColor Yellow
                            Expand-Archive -Path $item.FullName -DestinationPath $targetSubFolder -Force
                        }
                        elseif ($item.Extension -ieq ".rar") {
                            Write-Host "Извлекаем RAR-архив '$($item.Name)' непосредственно в '$targetSubFolder'" -ForegroundColor Yellow
                            $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
                            if (Test-Path $sevenZipPath) {
                                & $sevenZipPath x $item.FullName -o"$targetSubFolder" -y | Out-Null
                            }
                            else {
                                Write-Error "7-Zip не найден по пути '$sevenZipPath'. Невозможно извлечь RAR-архив."
                                continue
                            }
                        }
                    }
                    # После извлечения для архивов считаем, что содержимое находится в $targetSubFolder
                    $sourceFolder = $targetSubFolder
                }
                else {
                    Write-Warning "Файл '$($item.Name)' не является распознаваемым архивом. Пропускаем."
                    continue
                }
            }

            Write-Host "Обработка '$itemName' завершена. Содержимое находится в '$targetSubFolder'" -ForegroundColor Green

            # Сохраняем информацию об обработанном дистрибутиве
            $results += [PSCustomObject]@{
                VersionString = $versionStr
                Version       = $versionObj
                Arch          = $arch
                Path          = $targetSubFolder
            }
        }

        if ($results.Count -eq 0) {
            Write-Error "Не найдено ни одной подходящей папки или архива с дистрибутивами."
            return
        }

        # Выбираем объект с максимальной (последней) версией
        $latest = $results | Sort-Object Version -Descending | Select-Object -First 1

        return $latest
    }
        else {
            throw "Папка с дистрибутивами не найдена"
        }
}
