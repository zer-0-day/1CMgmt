function New-1CCurrentPlatformLink {
    <#
    .SYNOPSIS
        Создаёт символические ссылки current и currentXX на последнюю установленную платформу.
    .DESCRIPTION
        Создаёт junction-ссылку 'current' на последнюю установленную версию платформы.
        Если указаны дополнительные префиксы портов, создаёт ссылки currentXX → current.
    .PARAMETER PortPrefix
        Массив дополнительных префиксов портов (25, 35 и т.д.) для создания ссылок currentXX.
    .EXAMPLE
        New-1CCurrentPlatformLink
        # Создаёт только current
    .EXAMPLE
        New-1CCurrentPlatformLink -PortPrefix @(25, 35)
        # Создаёт current, current25, current35
    #>
    [CmdletBinding()]
    param(
        [int[]]$PortPrefix
    )

    # Удалить существующие ссылки current
    if (Test-Path -Path "C:\Program Files (x86)\1cv8\current") {
        Remove-Item "C:\Program Files (x86)\1cv8\current" -Recurse -Force -Confirm:$False
    }
        
    if (Test-Path -Path "C:\Program Files\1cv8\current") { 
        Remove-Item "C:\Program Files\1cv8\current" -Recurse -Force -Confirm:$False
    }
        
    Write-Host "Создание ссылки на последнюю установленную платформу" -ForegroundColor Cyan
    
    # x86 платформа
    if (Test-Path -Path "C:\Program Files (x86)\1cv8") {
        Write-Host "Обработка платформы x86..." -ForegroundColor DarkGray
        $version = Get-ChildItem -Directory -Path "C:\Program Files (x86)\1cv8\" |
                   Where-Object {$_.Name -like '8.3.*'} | 
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1
        
        if ($version) {
            $current = Join-Path "C:\Program Files (x86)\1cv8" $version.Name
            New-Item -ItemType Junction -Path "C:\Program Files (x86)\1cv8\current" -Target $current -Force | Out-Null
            Write-Host "Создана ссылка current → $($version.Name) (x86)" -ForegroundColor Green
            
            # Создать дополнительные ссылки currentXX
            if ($PortPrefix) {
                foreach ($pp in $PortPrefix) {
                    if ($pp -ne 15) {
                        $linkName = "current$pp"
                        $linkPath = "C:\Program Files (x86)\1cv8\$linkName"
                        if (Test-Path $linkPath) {
                            Remove-Item $linkPath -Recurse -Force -Confirm:$False
                        }
                        New-Item -ItemType Junction -Path $linkPath -Target "C:\Program Files (x86)\1cv8\current" -Force | Out-Null
                        Write-Host "Создана ссылка $linkName → current (x86)" -ForegroundColor Green
                    }
                }
            }
        }
    }
       
    # x64 платформа
    if (Test-Path -Path "C:\Program Files\1cv8") {
        Write-Host "Обработка платформы x64..." -ForegroundColor DarkGray
        $version = Get-ChildItem -Directory -Path "C:\Program Files\1cv8\" |
                   Where-Object {$_.Name -like '8.3.*'} | 
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1
        
        if ($version) {
            $current = Join-Path "C:\Program Files\1cv8" $version.Name
            New-Item -ItemType Junction -Path "C:\Program Files\1cv8\current" -Target $current -Force | Out-Null
            Write-Host "Создана ссылка current → $($version.Name) (x64)" -ForegroundColor Green
            
            # Создать дополнительные ссылки currentXX
            if ($PortPrefix) {
                foreach ($pp in $PortPrefix) {
                    if ($pp -ne 15) {
                        $linkName = "current$pp"
                        $linkPath = "C:\Program Files\1cv8\$linkName"
                        if (Test-Path $linkPath) {
                            Remove-Item $linkPath -Recurse -Force -Confirm:$False
                        }
                        New-Item -ItemType Junction -Path $linkPath -Target "C:\Program Files\1cv8\current" -Force | Out-Null
                        Write-Host "Создана ссылка $linkName → current (x64)" -ForegroundColor Green
                    }
                }
            }
        }
    }
}