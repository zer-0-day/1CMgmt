# Регистрация обработчиков ошибок
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Импорт функций
Get-ChildItem -Path $PSScriptRoot\*.ps1 | ForEach-Object {
    . $_.FullName
}


