<#
.SYNOPSIS
    Поиск каталога дистрибутивов 1С (1Cv8.adm) в корне дисков.

.DESCRIPTION
    Функция выполняет поиск папки `1Cv8.adm` в корне всех доступных логических дисков.
    Возвращает путь к найденному каталогу.

    Этот каталог используется для хранения дистрибутивов платформы 1С.
    В него копируются исходные серверные архивы формата:
        windows64full_8_3_xx_xxxx.rar
    (например: windows64full_8_3_22_1704.rar)

    Другие функции модуля (например, New-1CDistroPackage и Install-1CPlatform)
    работают именно с этим каталогом.

.EXAMPLE
    Find-1CDistroFolder
    # Вернёт путь к каталогу, например: D:\1Cv8.adm

.EXAMPLE
    $path = Find-1CDistroFolder
    if ($path) { Write-Host "Каталог найден: $path" }
    else { Write-Host "Каталог не найден" }

.NOTES
    • Ищет только в корне дисков (C:\, D:\, E:\ ...).
    • Если каталог не найден — возвращает $null и выводит предупреждение.
#>
function Find-1CDistroFolder {
    $getPartitions = (Get-Volume).DriveLetter
    foreach ($drv in $getPartitions) {
        if ($drv -match '^[A-Z]$') {
            $admFolder = "$drv`:\1Cv8.adm"
            if (Test-Path -LiteralPath $admFolder) {
                return $admFolder
            }
        }
    }
    Write-Warning "Каталог 1Cv8.adm не найден ни в одном из корневых дисков."
    return $null
}