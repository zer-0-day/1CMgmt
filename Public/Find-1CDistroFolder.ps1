<#
.SYNOPSIS
Проверка наличия папки 1cv8.adm в корне логических дисков
Подготовка диреткории с дистрибутивами и дистрибутивов, для утсановки. 
.DESCRIPTION
Выполняется поиск папки 1cv8.adm. Если директория найдена происходит переименование и сортировка версий дистрибутивов.
.PARAMETER Name
Описание параметра
.EXAMPLE
Пример использования
#>
function Find-1CDistroFolder {
    $found = $false
    $getPartitions = (Get-Volume).DriveLetter
    foreach ($drv in $getPartitions) {
        if ($drv -match '^[a-z]') {
            $admFolder = $drv  + ":\1cv8.adm"
            if (Test-Path $admFolder) {
#                Write-Host ✅ "Проверка пройдена успешно. Найдена папка 1cv8.adm. Расположение: $admFolder" -ForegroundColor Green
                $found = $true
                return $admFolder
            }
            else {
                
            }
        }
    }
    if (-not $found) {
        Write-Host "Не найдено"
         return $null
    }
}

