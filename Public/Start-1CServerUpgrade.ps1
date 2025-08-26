<#
    .SYNOPSIS
        
	    .DESCRIPTION
        Апгрейд сервера 1С
        .PARAMETER Path
	    The path that will be searched for a registry key.
	    .EXAMPLE
        Mgm1CMainMenu
        .INPUTS
	    System.String
	    .OUTPUTS
	    Microsoft.Win32.RegistryKey
	    .NOTES
	    This module is an example of what a well documented function could look.
	    .LINK
       
    #>
function Start-1CServerUpgrade {
    # Проверка существования ragent
    if (Test-Path 'C:\Program Files\1cv8\current\bin\ragent.exe') {
        # получить версию сервера 
       $getServerVersion = Get-ChildItem 'C:\Program Files\1cv8\current\bin\ragent.exe'
       $getServerVersion = $getServerVersion.VersionInfo.ProductVersion
       # проверить последнюю версию в папке дистрибутивов
       $getDistrInfo = New-1CDistroPackage
       $distrVersionInfo = $getDistrInfo.VersionString
       $getUpgradeVersionPath = $getDistrInfo.path
       if ($getServerVersion -eq $distrVersionInfo) {
        throw "Версия сервера $getServerVersion равна версии последнего дистрибутива $distrVersionInfo в папке $getUpgradeVersionPath "
        }
        if ($getServerVersion -lt $DistrVersionInfo) {
            Install-1CPlatform
        }
        else {
            throw  Write-Host "Версия сервера $getServerVersion выше версии последнего дистрибутива $distrVersionInfo в папке $getUpgradeVersionPath"
        }
        
        
    }
    else {
        Write-Host "Не найден установленный сервер 1С. Обратитесь к документации модуля "
    }
    
}