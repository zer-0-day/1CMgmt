function Test-1CPortAvailable {
    <#
    .SYNOPSIS
        Проверяет доступность портов для сервера 1С.
    .DESCRIPTION
        Проверяет, не заняты ли порты, которые будет использовать сервер 1С
        с указанным префиксом портов.
    .PARAMETER PortPrefix
        Префикс портов (15, 25, 35 и т.д.)
    .EXAMPLE
        Test-1CPortAvailable -PortPrefix 25
    #>
    [CmdletBinding()]
    param(
        [ValidatePattern('^\d{2}$')]
        [string]$PortPrefix = '15'
    )

    $BasePort = [int]("{0}41" -f $PortPrefix)
    $CtrlPort = [int]("{0}40" -f $PortPrefix)
    $RangeStart = [int]("{0}60" -f $PortPrefix)
    $RangeEnd = [int]("{0}91" -f $PortPrefix)

    try {
        $listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
        
        # Проверяем основные порты
        $occupiedPorts = $listeners | Where-Object { 
            $_.LocalPort -eq $BasePort -or 
            $_.LocalPort -eq $CtrlPort -or
            ($_.LocalPort -ge $RangeStart -and $_.LocalPort -le $RangeEnd)
        }

        if ($occupiedPorts) {
            $portList = ($occupiedPorts | Select-Object -ExpandProperty LocalPort -Unique | Sort-Object) -join ', '
            Write-Warning "Следующие порты уже заняты: $portList"
            return $false
        }

        return $true
    }
    catch {
        Write-Warning "Не удалось проверить доступность портов: $_"
        return $true  # Продолжаем установку, если проверка не удалась
    }
}
