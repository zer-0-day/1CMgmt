<#
    .SYNOPSIS
        Установка платформы
	    .DESCRIPTION
        Подготовка директории с дистрибутивами и дальнейшая установка платформы (сервера)       
        .PARAMETER Path
	    The path that will be searched for a registry key.
	    .EXAMPLE
       
        .INPUTS
	    System.String
	    .OUTPUTS
	    Microsoft.Win32.RegistryKey
	    .NOTES
	    This module is an example of what a well documented function could look.
	    .LINK
       
    #>
function Install-1CPlatform{
     # получение результатов из функции подготовки директории дистрибутивов
     #1CMDistrPrepare
     $getDistrPrepare = New-1CDistroPackage
     $getDistrPrepare
     $SetupPath = $getDistrPrepare.Path
     
     # установка платформы
     $DirectoryPath = "C:\Program Files\1cv8\current\bin\"
     $comcntrl = $DirectoryPath + 'comcntr.dll'
     $radmin = $DirectoryPath + 'radmin.dll'
     if (Test-Path -Path $SetupPath) {
         if (Test-Path -Path "$SetupPath\1CEnterprise 8 (x86-64).msi") {
             # Каталог, где находится установочные файлы
             Set-Location $SetupPath;
             $msiInstallerPath = "$SetupPath\1CEnterprise 8 (x86-64).msi"
             $adminstallrelogonPath = "$SetupPath\adminstallrelogon.mst"
             $lang1049Path = "$SetupPath\1049.mst"
             $DESIGNERALLCLIENTS = 1
             $THICKCLIENT = 1
             $THINCLIENTFILE = 1
             $THINCLIENT = 1
             $WEBSERVEREXT = 1
             $SERVER = 1
             $CONFREPOSSERVER = 0
             $CONVERTER77 = 0
             $SERVERCLIENT = 1
             $LANGUAGES = 'RU'
             $params = '/i', 
             $msiInstallerPath,
             # Тихая установка
             '/qn', 
             # Здесь мы подключаем рекомендованную фирмой 1С трансформацию adminstallrelogon.mst и пакет русского языка 1049.mst
             "TRANSFORMS=$adminstallrelogonPath;$lang1049Path", 
             # Это основные компоненты 1С:Предприятия, включая компоненты для администрирования, конфигуратор и толстый клиент. 
             # Без этого параметра ставится всегда только тонкий клиент, независимо от следующего параметра
             "DESIGNERALLCLIENTS=$DESIGNERALLCLIENTS",
             "THICKCLIENT=$THICKCLIENT", # Толстый клиент
             "THINCLIENTFILE=$THINCLIENTFILE", # Тонкий клиент, файловый вариант
             "THINCLIENT=$THINCLIENT", # Тонкий клиент
             "WEBSERVEREXT=$WEBSERVEREXT", # Модули расширения WEB-сервера
             "SERVER=$SERVER", # Сервер 1С:Предприятия
             "CONFREPOSSERVER=$CONFREPOSSERVER", # Сервер хранилища конфигураций
             "CONVERTER77=$CONVERTER77", # Конвертер баз 1С:Предприятия 7.7
             "SERVERCLIENT=$SERVERCLIENT", # Администрирование сервера
             "LANGUAGES=$LANGUAGES" # Язык установки – русский.
              Write-Host "Выполняется установка. Ожидайте" -BackgroundColor Black -ForegroundColor Green
             $params
            & msiexec.exe @params | Out-Null
             # Регистрация библиотек
             regsvr32.exe "$comcntrl" -s
             Write-Host 'Библиотека comcntrl зарегистрирована' -BackgroundColor Black -ForegroundColor Green
             regsvr32.exe $radmin -s
             Write-Host 'Библиотека radmin зарегистрирована' -BackgroundColor Black -ForegroundColor Green
         }
     }
     #создать ссылки
    New-1CCurrentPlatformLink
}