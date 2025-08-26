
function New-1CCustomCompressTask{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TaskName = "Compress1CLogsTask",

        [Parameter(Mandatory = $false)]
        [string]$Description = "Ежедневное сжатие файлов журналов регистрации для всех баз",

        [Parameter(Mandatory = $false)]
        [string]$ModuleName = "1CMGmt",

        [Parameter(Mandatory = $false)]
        [string]$FunctionName = "Compress-1CLogs"
        
    )

    # Установить время хранения файлов ЖР и архивов файлов ЖР
    $fileDays = Read-Host "Время хранения файлов ЖР"
    $archiveDays = Read-Host "Время хранения архивов файлов ЖР"
    $DailyTime = Read-Host "Время запуска задачи. в вормате ЧЧ:ММ, например, 05:00"

    # Проверка наличия модуля ScheduledTasks (требуется PowerShell 5.1+)
    if (-not (Get-Module -ListAvailable -Name ScheduledTasks)) {
        Write-Error "Модуль ScheduledTasks не найден. Требуется PowerShell 5.1 или выше."
        return
    }
    Import-Module ScheduledTasks -ErrorAction Stop

    try {
        # Формирование аргументов для запуска PowerShell-скрипта
        $actionArgument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Import-Module $ModuleName; $FunctionName -fileDays  $fileDays -archiveDays  $archiveDays`""
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgument

        # Определение триггера – ежедневный запуск в указанное время
        $trigger = New-ScheduledTaskTrigger -Daily -At $DailyTime

        # Определение принципала для запуска задачи от имени SYSTEM с наивысшими правами
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Если задача с таким именем уже существует, удаляем её
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Write-Verbose "Задача '$TaskName' уже существует. Удаляем старую задачу..."
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        # Регистрация задачи
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Description $Description

        Write-Output "Задача '$TaskName' успешно создана."
    }
    catch {
        Write-Error "Ошибка при создании задачи: $_"
    }
    Invoke-1CTaskMenu
}
