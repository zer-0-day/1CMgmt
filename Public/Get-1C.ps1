<#
    .SYNOPSIS
        
	    .DESCRIPTION
        Получение информации о сервере 1С:
         -пути к файлам ЖР
         -размер директорий файлов ЖР для каждой базы 
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
function Get-1C{
    param(
        [string]$BaseRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services",
        [string]$SearchPattern = "1C:Enterprise*"
    )

    # Получаем пути к srvinfo из реестра
    $srvinfoPaths = @()
    if (Test-Path $BaseRegPath) {
        $serverKeys = Get-ChildItem -Path $BaseRegPath | Where-Object { $_.PSChildName -like $SearchPattern }
        foreach ($serverKey in $serverKeys) {
            $regValues = Get-ItemProperty -Path $serverKey.PSPath
            foreach ($property in $regValues.PSObject.Properties) {
                if ($property.Value -match '-d\s+"([^"]*srvinfo[^"]*)"') {
                    $srvinfoPaths += $matches[1]
                }
            }
        }
    }
    else {
        Write-Host "Ключ реестра $BaseRegPath не найден."
    }
    
    if ($srvinfoPaths.Count -eq 0) {
        Write-Host "Не удалось найти пути к директориям srvinfo в реестре."
    }
    
    # Массив для итоговых данных из файлов
    $jsonArray = @()
    
    # Поиск файлов 1CV8Clst.lst в найденных директориях
    foreach ($path in $srvinfoPaths) {
        $files = Get-ChildItem -Path $path -Filter "1CV8Clst.lst" -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $content = Get-Content $file.FullName
            foreach ($line in $content) {
                # Инициализируем объект с предопределёнными свойствами
                $jsonObject = [ordered]@{
                    Descr         = ""
                    DescrState    = 1
                    Ref           = $null
                    DB            = $null
                    DBSrvr        = $null
                    DBID          = $null
                    DBCacheSize   = 0
                    FilePath      = ""
                }

                # Поиск параметра Descr
                if ($line -match 'Descr\s*=\s*""([^""]*)""') {
                    $descrValue = $matches[1].Trim() -replace '\\', ''
                    $jsonObject.Descr = $descrValue
                    $jsonObject.DescrState = if ($descrValue -eq "" -or $descrValue -eq ";") { 1 } else { 0 }
                }
                
                # Поиск остальных параметров
                if ($line -match 'Ref\s*=\s*([^;]+)') {
                    $jsonObject.Ref = $matches[1]
                }
                if ($line -match '\bDB=([^;]+)') {
                    $jsonObject.DB = $matches[1]
                }
                if ($line -match 'DBSrvr\s*=\s*([^;]+)') {
                    $jsonObject.DBSrvr = $matches[1]
                }
                if ($line -match '^{?([0-9a-fA-F-]{36})') {
                    $jsonObject.DBID = $matches[1].Trim('{')
                    
                    # Определяем путь к папке по DBID и вычисляем её размер
                    $basePath = [System.IO.Path]::GetDirectoryName($file.FullName)
                    $dbFolderPath = Join-Path -Path $basePath -ChildPath $jsonObject.DBID
                    if (Test-Path $dbFolderPath) {
                        $folderSize = (Get-ChildItem -Path $dbFolderPath -Recurse -Force | Measure-Object -Property Length -Sum).Sum
                        $jsonObject.DBCacheSize = $folderSize
                    }
                }
                # Добавляем путь к файлу (одинарные слеши)
                $jsonObject.FilePath = $file.FullName -replace '\\\\', '\'
                
                # Если найдены значения Ref и DB, добавляем объект в массив
                if ($jsonObject.Ref -and $jsonObject.DB) {
                    $jsonArray += $jsonObject
                }
            }
        }
    }
    
    $finalJSON = $null
    if ($jsonArray.Count -gt 0) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $finalJSON = $jsonArray | ConvertTo-Json -Depth 4
    }
    
    # Возвращаем объект с двумя свойствами:
    # SrvinfoPaths - массив путей из реестра
    # FileInfoJSON - JSON с данными из файлов
    return [pscustomobject]@{
        SrvinfoPaths = $srvinfoPaths
        FileInfoJSON = $finalJSON
    }
}
<#
# Пример вызова функции
$result = Get-1CV8ClstInfo
if ($result) {
    Write-Host "Найденные пути (SrvinfoPaths):"
    $result.SrvinfoPaths | ForEach-Object { Write-Host $_ }
    Write-Host "`nДанные из файлов (FileInfoJSON):"
    Write-Host $result.FileInfoJSON
}
#>