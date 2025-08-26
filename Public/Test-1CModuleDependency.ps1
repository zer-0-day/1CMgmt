<#
.SYNOPSIS
Проверка зависимостей для корректной работы модуля
.DESCRIPTION
Подробное описание
.PARAMETER Name
Описание параметра
.EXAMPLE
Пример использования
#>
function Test-1CModuleDependency{
   
    [CmdletBinding()]
    param(
        [switch]$RequireAdmin
    )
    Write-Host "Проверка версии Powershell"
    # Проверка версии PowerShell
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "Требуется PowerShell 5.1 или выше"
    }
    else {
        Write-Host "Версия Powershell соответствует требованиям" -ForegroundColor Green
    }
    
    # Проверка прав администратора
    Write-Host "Проверка прав пользователя"
    if ($RequireAdmin -and (-not ([Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        throw "Требуются права администратора"
    }
    else {
        Write-Host "Запущено с правами администратора" -ForegroundColor Green
    }
    
    # Проверка наличия .NET Framework
    Write-Host "Проверка версии Net.Framework"
    if (-not (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
        Get-ItemProperty -Name Version -EA SilentlyContinue |
        Where-Object { $_.Version -match '^4\.' })) {
        throw "Требуется .NET Framework 4.x"
    }
    else {
        Write-Host "Версия Net.Framework соответствует требованиям" -ForegroundColor Green
    }

    # Проверка линка и дистибутивов
    Write-Host "Проверка наличия директории с дистрибутивами"
    $searchDistrFolder = Find-1CDistroFolder

    if ($searchDistrFolder) {
        Write-Host "Директория с дистрибутивами: $searchDistrFolder" -ForegroundColor Green
    } else {
        Write-Host "Директория 1cv8.adm с дистрибутивами не найдена!" -ForegroundColor Red
        # Если критично, можно вызвать throw или выполнить альтернативные действия
    }

    # Проверка наличия 7-zip
    Write-Host "Проверка установки 7-Zip"
    $SevenZip     = 'C:\Program Files\7-Zip\7z.exe'
    if (-not (Test-Path $SevenZip)) {
        throw "7-Zip не найден по пути: $SevenZip"
    }else {
        Write-Host "7-Zip установлен" -ForegroundColor Green
    }

    # Проверка задачи обновления модуля 1CMgmt
    if ( -not(Get-ScheduledTask -TaskName "Update Module 1CMgmt" -ErrorAction SilentlyContinue)) {
        Write-Host "Не найдена задача обновления модуля! `nСоздаю задачу обновления модуля в планировщике Windows" -ForegroundColor Red
        New-ModuleUpdateTask
    }
    else {Write-Host "Задача обновления модуля найдена в плнировщике Windows" -ForegroundColor Green}
}