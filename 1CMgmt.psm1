# Минимальный загрузчик функций для 1CMgmt

# (Опционально) делаем явной остановку по ошибкам dot-sourcing
$ErrorActionPreference = 'Stop'

# Пути к папкам с функциями
$publicPath  = Join-Path $PSScriptRoot 'Public'
$privatePath = Join-Path $PSScriptRoot 'Private'

# Подключаем PUBLIC/*.ps1
if (Test-Path -LiteralPath $publicPath) {
    foreach ($f in (Get-ChildItem -LiteralPath $publicPath -Filter *.ps1 -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })) {
        . $f.FullName
    }
}

# Подключаем PRIVATE/*.ps1 (хелперы)
if (Test-Path -LiteralPath $privatePath) {
    foreach ($f in (Get-ChildItem -LiteralPath $privatePath -Filter *.ps1 -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })) {
        . $f.FullName
    }
}

# Экспортируем всё, что определили как функции и алиасы
Export-ModuleMember -Function * -Alias *