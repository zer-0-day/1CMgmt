function New-1CCurrentPlatformLink{

    #удалить существующие ссылки
    if (Test-Path -Path "C:\Program Files (x86)\1cv8\current") {
        Remove-Item "C:\Program Files (x86)\1cv8\current" -Recurse -Force -Confirm:$False
    }
        
    if (Test-Path -Path "C:\Program Files\1cv8\current") { 
        Remove-Item "C:\Program Files\1cv8\current" -Recurse -Force -Confirm:$False
    }
        
                  
    "Создать ссылку на последнюю установленную платформу"
    if ( Test-Path -Path "C:\Program Files (x86)\1cv8") {
        "Создать ссылку на последнюю установленную платформу x86"  
        $version = Get-ChildItem -Directory -Path "C:\Program Files (x86)\1cv8\" |Where-Object {$_.Name -like '8.3.*'} | Sort-Object LastWriteTime -Descending |Select-Object -First 1
        $current = 'C:\Program Files (x86)\1cv8\' + $version.Name
        New-Item -ItemType Junction -Path "C:\Program Files (x86)\1cv8\current" -Target $current
        Write-Host 'Создана ссылка на платформу версии' $version.Name 'Путь' $current
                      
    }
       
    if (Test-Path -Path "C:\Program Files\1cv8") {
        "Создать ссылку на последнюю установленную платформу x64"
        $version = Get-ChildItem -Directory -Path "C:\Program Files\1cv8\" |Where-Object {$_.Name -like '8.3.*'} | Sort-Object LastWriteTime -Descending |Select-Object -First 1
        $current = 'C:\Program Files\1cv8\' + $version.Name
        New-Item -ItemType Junction -Path "C:\Program Files\1cv8\current" -Target $current
        Write-Host 'Создана ссылка на платформу версии' $version.Name 'Путь' $current
    }
    
}