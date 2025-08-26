<#
    .SYNOPSIS
        Обновление модуля 1CMgmt
	    .DESCRIPTION
        Задача автоматического обновления модуля 1CMgmt
    #>
function New-ModuleUpdateTask {
    [CmdletBinding()]
    param(
        [string]$TaskName     = 'Update Module 1CMgmt',
        [string]$Description  = 'Ежедневная проверка обновления модуля 1CMgmt',
        [datetime]$DailyTime  = (Get-Date '01:00')
    )

    # Проверяем модуль ScheduledTasks
    if (-not (Get-Module -ListAvailable -Name ScheduledTasks)) {
        Write-Error 'Модуль ScheduledTasks не найден. Требуется PowerShell 5.1 или выше.'
        return
    }
    Import-Module ScheduledTasks -ErrorAction Stop

    try {
        # Формирование аргументов для запуска PowerShell-скрипта
        $actionArgument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Import-Module 1CMgmt; Update-Module1CMgmt`""
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgument

        # Определение триггера – ежедневный запуск в указанное время
        $trigger = New-ScheduledTaskTrigger -Daily -At $DailyTime

        # Определение принципала для запуска задачи от имени SYSTEM с наивысшими правами
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Description $Description
        
    }
    catch {
        Write-Error "Ошибка при создании задачи: $_"
    }
      
}
