function Update-Module1CMgmt {
    [CmdletBinding()]
    param(
       # [Parameter(Mandatory=$true)]
        [string]$ModuleName = "1CMgmt"
    )

    try {
        # Получаем локально установленную версию
        $localModule = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
        $localVersion = if ($localModule) { [version]$localModule.Version } else { [version]"0.0.0" }

        # Получаем последнюю версию из PSGallery
        $repositoryModule = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction Stop
        $latestVersion = [version]$repositoryModule.Version

        if ($latestVersion -gt $localVersion) {
            Write-Output "Обновление модуля '$ModuleName' с версии $localVersion до $latestVersion"
            Update-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Output "Обновление завершено успешно."
        }
        else {
            Write-Output "Модуль '$ModuleName' уже обновлён до версии $localVersion или новее."
        }
    }
    catch {
        Write-Warning "Ошибка при обновлении модуля : $_"
    }
}