<#
.SYNOPSIS
  Создаёт плановую задачу(и) для ночного апгрейда 1С (ветка current) с опц. перезапуском CurrentXX служб.

.DESCRIPTION
  Регистрирует задачу Windows Task Scheduler, которая по расписанию запускает:
    Import-Module 1CMgmt; Start-1CServerUpgrade [-SetupPath ...] [-PortPrefix ...]
  • Если указан -SetupPath, он может быть как папкой версии, так и «корнем» с архивами — апгрейдер сам найдёт свежую.
  • -PortPrefix позволяет дополнительно перезапускать службы вида '... Current25', '... Current35', и т.д. (для current).
  • Задача создаётся с «Run with highest privileges» и от имени указанного пользователя (логон по паролю).

  • Имя задачи формируется автоматически: 
    — для current → "New-1CServerAutoUpgradeTask";
    — для currentXX → "New-1CServerAutoUpgradeTask-XX".
    При передаче нескольких префиксов создаются несколько задач.

.PARAMETER TaskName
  Необязательный. Явно заданное имя задачи. Если не указано — имя формируется автоматически:
  "New-1CServerAutoUpgradeTask" (для current) или "New-1CServerAutoUpgradeTask-XX" (для currentXX).

.PARAMETER At
  Ежедневное время старта в формате HH:mm. По умолчанию '03:30'.

.PARAMETER RunAsUser
  Учётная запись, от имени которой запускать задачу (должны быть права к \\шаре, если -SetupPath указывает на UNC).

.PARAMETER RunAsPassword
  SecureString-пароль для RunAsUser. Если не указан — будет запрошен.

.PARAMETER SetupPath
  Необязательный. Путь к каталогу с дистрибутивами (локальный или UNC).
  Если не указан — при создании задачи будет предложено ввести путь, иначе будет использован локальный кэш “C:\1Cv8.adm”. Значение передаётся в Start-1CServerUpgrade.

.PARAMETER PortPrefix
  Необязательно. Одно значение или массив префиксов (напр. 25 или @(25,35)) — будет передан в Start-1CServerUpgrade.

.PARAMETER Shell
  'WindowsPowerShell' (5.1) или 'PowerShell7' (pwsh.exe). По умолчанию 'WindowsPowerShell'.

.EXAMPLE
  New-1CServerAutoUpgradeTask -RunAsUser 'DOMAIN\svc-1c'
  # Создаст задачу "New-1CServerAutoUpgradeTask" (current).

.EXAMPLE
  New-1CServerAutoUpgradeTask -RunAsUser 'DOMAIN\svc-1c' -SetupPath '\\server\distr' -PortPrefix 25,35 -Shell PowerShell7
  # Создаст две задачи: "New-1CServerAutoUpgradeTask-25" и "New-1CServerAutoUpgradeTask-35".
#>
function New-1CServerAutoUpgradeTask {
    [CmdletBinding()]
    param(
        [string]$TaskName = $null,
        [Parameter()][ValidatePattern('^\d{2}:\d{2}$')]
        [string]$At = '03:30',

        [Parameter(Mandatory)][string]$RunAsUser,
        [System.Security.SecureString]$RunAsPassword,

        [string]$SetupPath,
        [int[]]$PortPrefix,

        [ValidateSet('WindowsPowerShell','PowerShell7')]
        [string]$Shell = 'WindowsPowerShell'
    )

    # Если SetupPath не передан — спросим интерактивно, по умолчанию используем локальный кэш C:\1Cv8.adm
    if (-not $PSBoundParameters.ContainsKey('SetupPath') -or [string]::IsNullOrWhiteSpace($SetupPath)) {
        $defaultSetup = 'C:\1Cv8.adm'
        $inp = Read-Host -Prompt ("Укажите путь к дистрибутивам (Enter — использовать по умолчанию: $defaultSetup)")
        if ([string]::IsNullOrWhiteSpace($inp)) {
            $SetupPath = $defaultSetup
            Write-Host "Путь не указан — будет использован локальный кэш: $SetupPath" -ForegroundColor Yellow
        } else {
            $SetupPath = $inp
        }
    }

    function ConvertFrom-SecureStringPlain {
        param([Parameter(Mandatory)][System.Security.SecureString]$Secure)
        [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
        )
    }

    # 1) Выберем исполняемый файл оболочки
    $exe = if ($Shell -eq 'PowerShell7') {
        # MS Learn: PowerShell 7 ставится в $Env:ProgramFiles\PowerShell\<ver>\pwsh.exe
        Join-Path $Env:ProgramFiles 'PowerShell\7\pwsh.exe'
    } else {
        "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    }

    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Не найден исполняемый файл оболочки: $exe"
    }

    # Подготовим список целевых префиксов: если не задано — только current (15 для именования мы не передаём в апгрейдер)
    $targetPrefixes = @()
    if ($PortPrefix -and $PortPrefix.Count -gt 0) { $targetPrefixes = $PortPrefix } else { $targetPrefixes = @() }  # пустой = только current

    # Пароль спрашиваем один раз (если нужно)
    if (-not $RunAsPassword) {
        $RunAsPassword = Read-Host -Prompt "Введите пароль для $RunAsUser" -AsSecureString
    }
    $plain = ConvertFrom-SecureStringPlain -Secure $RunAsPassword
    $principal = New-ScheduledTaskPrincipal -UserId $RunAsUser -LogonType Password -RunLevel Highest

    # Общее время/триггер
    $time = [DateTime]::ParseExact($At,'HH:mm',$null)
    $trigger = New-ScheduledTaskTrigger -Daily -At $time

    # Если префиксы не заданы — создаём одну задачу для current
    if ($targetPrefixes.Count -eq 0) {
        $autoName = if ($TaskName) { $TaskName } else { 'New-1CServerAutoUpgradeTask' }
        $cmd = 'Import-Module 1CMgmt; Start-1CServerUpgrade'
        if ($SetupPath) { $cmd += " -SetupPath `"$SetupPath`"" }
        # без -PortPrefix: перезапустится только Current
        $args = "-NoProfile -ExecutionPolicy Bypass -NonInteractive -Command `"$cmd`""
        $action = New-ScheduledTaskAction -Execute $exe -Argument $args
        Register-ScheduledTask -TaskName $autoName -Action $action -Trigger $trigger `
            -Principal $principal -Description 'Ночной автоапгрейд 1С (current)' `
            -User $RunAsUser -Password $plain | Out-Null
        Write-Host "Создана задача '$autoName' (ежедневно в $At, оболочка: $Shell, для current)" -ForegroundColor Green
    }
    else {
        foreach ($pp in $targetPrefixes) {
            $suffix  = "New-1CServerAutoUpgradeTask-$pp"
            $autoName = if ($TaskName) { $TaskName } else { $suffix }
            $cmd = 'Import-Module 1CMgmt; Start-1CServerUpgrade'
            if ($SetupPath) { $cmd += " -SetupPath `"$SetupPath`"" }
            $cmd += " -PortPrefix $pp"
            $args = "-NoProfile -ExecutionPolicy Bypass -NonInteractive -Command `"$cmd`""
            $action = New-ScheduledTaskAction -Execute $exe -Argument $args
            Register-ScheduledTask -TaskName $autoName -Action $action -Trigger $trigger `
                -Principal $principal -Description "Ночной автоапгрейд 1С (current$pp)" `
                -User $RunAsUser -Password $plain | Out-Null
            Write-Host "Создана задача '$autoName' (ежедневно в $At, оболочка: $Shell, для current$pp)" -ForegroundColor Green
        }
    }
}