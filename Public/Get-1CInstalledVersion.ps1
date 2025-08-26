<#
    .SYNOPSIS
        Возвращает список установленных версий 1С
	    .DESCRIPTION
        Функция для запроса версий 1С
        Пример:
            Get-1CInstalledVersion
            Пример вывода:
            Запрос установленных версий 1С
            Последняя установленная версия платформы 1С
            8.3.25.1374
            Все установленные платформы 1С:
            8.3.25.1374
            8.3.25.1286
            8.3.23.1997
            8.3.23.1739
            8.3.23.1739
            8.3.23.1739
        .PARAMETER Path
	    The path that will be searched for a registry key.
	    .EXAMPLE
        Get-1CInstalledVersion
        Пример вывода:
        Запрос установленных версий 1С
        Последняя установленная
        версия платформы 1С
        8.3.25.1374
        Все установленные платформы 1С:
        8.3.25.1374
        8.3.25.1286
        8.3.23.1997
        8.3.23.1739
        8.3.23.1739
        8.3.23.1739
        .INPUTS
	    System.String
	    .OUTPUTS
	    Microsoft.Win32.RegistryKey
	    .NOTES
	    This module is an example of what a well documented function could look.
	    .LINK
       
    #>
function Get-1CInstalledVersion {
    
    Write-Host "HostName: " $env:COMPUTERNAME -ForegroundColor Green
    Write-Host "Запрос установленных версий 1С" -ForegroundColor Yellow
    $install1CVersion = (Get-Package |  Where-Object { $_.Name -like '1С:Предприятие*' -and $_.Name -notlike '*Designer*' }).Version
    $LastVersion = $install1CVersion | Sort-Object -Descending | Select-Object -First 1
    "Последняя установленная версия платформы 1С:" 
    $LastVersion
    "Все установленные платформы 1С: "
    $install1CVersion | Sort-Object -Descending
}
