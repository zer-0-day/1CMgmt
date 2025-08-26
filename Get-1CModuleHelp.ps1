<#
    .SYNOPSIS
        Описание функций модуля 1CMgmt
	    .DESCRIPTION
        Описание функций модуля 1CMgmt
	    This module is an example of what a well documented function could look.
	    .LINK
       
    #>
function Get-1CModuleHelp {
    Write-Host "Список функций модуля" -ForegroundColor Green -BackgroundColor Black
    Get-Content 'C:\Program Files\WindowsPowerShell\Modules\1CMgmt\0.4\1CMgmt.md' 
    Write-Host "Для получения справки по функции наберите Get-Help <Имя функции>, в отдельном окне Powershell" -ForegroundColor Green -BackgroundColor Black
    
}
