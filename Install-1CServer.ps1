<#
    .SYNOPSIS
        Вызов функции установки сервера
	    .DESCRIPTION
        Установка сервера 1С
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
function Install-1CServer {
    #вызов функции установки платформы.
    Install-1CPlatform
    # Создать пользователя 1С
    New-1CServiceUser
    $username = $env:computername + '\USR1CV8'
    $usrPass = Get-Content 'c:\passfile.txt' | ConvertTo-SecureString
    #Создать службу и каталог сервера
    $Version = 'Current'
    $ServiceName = "1C:Enterprise 8.3 Server Agent $Version"
    #Запрос номера порта
    $PortNumber = Read-Host 'Ввести первые две цифры порта сервера 1С'
    #Запрос ввода логина и пароля пользователя USR1CV8                      
    $Mycreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $usrPass
    Remove-Item 'c:\passfile.txt' -Recurse -Force   
    $RangePort = $PortNumber + '60' + ':' + $PortNumber + '91'
    $BasePort = $PortNumber + '41'
    $CtrlPort = $PortNumber + '40'
    $SrvCatalog = "C:\Program Files\1cv8\srvinfo"
    $SrvRunCatalog = '"C:\Program Files\1cv8\srvinfo"'
    $RunPath = '"C:\Program Files\1cv8\current\bin\ragent.exe"'
    $DirectoryPath = "C:\Program Files\1cv8\current\bin\"
    $ServicePath = $RunPath + ' ' + '-srvc -agent -regport' + ' ' + $BasePort + ' ' + '-port' + ' ' + $CtrlPort + ' ' + '-range' + ' ' + $RangePort + ' ' + '-debug -d' + ' ' + $SrvRunCatalog
    $comcntrl = $DirectoryPath + 'comcntr.dll'
    $radmin = $DirectoryPath + 'radmin.dll'
    # Создать каталог сервера и дать права пользователю
    if (!(Test-Path -Path $SrvCatalog)) {
            
            New-Item $SrvCatalog -ItemType Directory
        }
    $ACL = Get-Acl $SrvCatalog
    $setting = "$username", "FullControl", "Allow"
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $setting
    $ACL.SetAccessRule($AccessRule)
    $ACL | Set-Acl $SrvCatalog
    $ACL.SetAccessRuleProtection($false, $true)
    #регистрация библиотек
    regsvr32.exe "$comcntrl" -s
    Write-Host 'Библиотека comcntrl зарегистрирована' -BackgroundColor Black -ForegroundColor Green
    regsvr32.exe $radmin -s
    Write-Host 'Библиотека radmin зарегистрирована' -BackgroundColor Black -ForegroundColor Green
    #создать службу
    New-Service -name $ServiceName -binaryPathName $ServicePath -displayName $ServiceName -startupType Automatic -credential $Mycreds
    Start-Service "1C:Enterprise 8.3 Server Agent Current"
    $serviceStatus = Get-Service "1C:Enterprise 8.3 Server Agent Current" |Where-Object Status |Select-Object Status
    Write-Host "Статус службы сервера 1С" $serviceStatus.Status
}
