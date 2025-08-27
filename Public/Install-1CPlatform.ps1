<#
.SYNOPSIS
    Устанавливает или обновляет платформу 1С из каталога дистрибутива.

.DESCRIPTION
    Функция находит каталог дистрибутива через -SetupPath или New-1CDistroPackage.
    Если задан -SetupPath (папка или корень):
        • находит архив windows64full_8_3_xx_xxxx.rar (рекурсивно при корне);
        • копирует архив в 1Cv8.adm.
    Далее: через New-1CDistroPackage распаковывает, затем удаляет архив из 1Cv8.adm.
    Потом установка MSI (/qn, /norestart), MST-применение, регистрация DLL, обновление current.

.PARAMETER SetupPath
    См. описание выше.

.PARAMETER Quiet
    Тихая установка (/qn). По умолчанию $true.

.PARAMETER NoRestart
    Без перезагрузки (/norestart). По умолчанию $true.

.NOTES
    • После подготовки дистрибутива удаляем архив из 1Cv8.adm (Remove-Item).  
      (Remove-Item надёжно удаляет файл — после выполнения распаковки архив необязателен.)  [oai_citation:0‡reddit.com](https://www.reddit.com/r/PowerShell/comments/181kh0a/moveitem_makes_copies_and_removeitem_doesnt_work/?utm_source=chatgpt.com) [oai_citation:1‡learn.microsoft.com](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-7.5&utm_source=chatgpt.com)
#>
function Install-1CPlatform {
    [CmdletBinding()]
    param(
        [string]$SetupPath,
        [bool]$Quiet = $true,
        [bool]$NoRestart = $true
    )

    # --- Путь к 1Cv8.adm ---
    $admPath = Find-1CDistroFolder
    if (-not $admPath -or -not (Test-Path -LiteralPath $admPath)) {
        Write-Host "Каталог дистрибутивов 1Cv8.adm не найден." -ForegroundColor Red
        return
    }

    # --- SetupPath обработка, архив копируется в 1Cv8.adm ---
    if ($PSBoundParameters.ContainsKey('SetupPath') -and $SetupPath) {
        if (-not (Test-Path -LiteralPath $SetupPath)) {
            Write-Host "Каталог не найден: $SetupPath" -ForegroundColor Red
            return
        }
        $leaf = Split-Path -Leaf $SetupPath
        $archiveFile = $null

        if ($leaf -match '^\d+\.\d+\.\d+\.\d+$') {
            $verUnderscore = $leaf -replace '\.', '_'
            $expected = Join-Path $SetupPath ("windows64full_{0}.rar" -f $verUnderscore)
            if (Test-Path -LiteralPath $expected) {
                $archiveFile = $expected
            }
            else {
                $c = Get-ChildItem -LiteralPath $SetupPath -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($c) { $archiveFile = $c.FullName }
            }
        }
        else {
            $cands = Get-ChildItem -LiteralPath $SetupPath -Recurse -Filter 'windows64full_8_3_*.rar' -File -ErrorAction SilentlyContinue
            if ($cands) {
                $parsed = foreach ($f in $cands) {
                    if ($f.BaseName -match '^windows64full_(?<v>\d+_\d+_\d+_\d+)$') {
                        $verStr = $matches['v'] -replace '_', '.'
                        try { [PSCustomObject]@{ Version = [Version]$verStr; File = $f.FullName } } catch {}
                    }
                }
                if ($parsed) {
                    $best = $parsed | Sort-Object Version -Descending | Select-Object -First 1
                    $archiveFile = $best.File
                }
            }
        }

        if (-not $archiveFile) {
            Write-Host "Не найден серверный архив windows64full_8_3_xx_xxxx.rar в '$SetupPath'." -ForegroundColor Red
            return
        }

        $dest = Join-Path $admPath (Split-Path -Leaf $archiveFile)
        if (-not (Test-Path -LiteralPath $dest)) {
            Write-Host "Копирую архив в 1Cv8.adm: '$archiveFile' → '$dest'"
            Copy-Item -LiteralPath $archiveFile -Destination $dest -Force
        }
        else {
            Write-Host "Архив уже есть в 1Cv8.adm: $dest"
        }
    }

    # --- Распаковка дистрибутива ---
    # --- Распаковка дистрибутива ---
    $pkg = New-1CDistroPackage
    if (-not $pkg) { return }
    $SetupPath = $pkg.Path
    $admPath = Find-1CDistroFolder

    # --- Удаление RAR из 1Cv8.adm после успешной распаковки ---
    if ($admPath -and $pkg.VersionString) {
        $verU = $pkg.VersionString -replace '\.', '_'
        $rarMask = "windows64full_${verU}.rar"

        $rarFiles = Get-ChildItem -LiteralPath $admPath -Filter $rarMask -File -ErrorAction SilentlyContinue
        foreach ($rar in $rarFiles) {
            Write-Host "Удаляю архив: $($rar.FullName)"
            Remove-Item -LiteralPath $rar.FullName -Force   # удаляем аккуратно, штатным cmdlet.  [oai_citation:0‡Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-7.5&utm_source=chatgpt.com)
        }
    }

    # --- Установка MSI ---
    $bin = Join-Path $SetupPath '1CEnterprise 8 (x86-64).msi'
    if (Test-Path -LiteralPath $bin) {
        Set-Location $SetupPath
        $params = @('/i', $bin)
        if ($Quiet) { $params += '/qn' }
        if ($NoRestart) { $params += '/norestart' }

        $admMst = Join-Path $SetupPath 'adminstallrelogon.mst'
        $ruMst = Join-Path $SetupPath '1049.mst'
        $transforms = @()
        if (Test-Path -LiteralPath $admMst) { $transforms += $admMst }
        if (Test-Path -LiteralPath $ruMst) { $transforms += $ruMst }
        if ($transforms.Count) {
            $params += "TRANSFORMS=$($transforms -join ';')"
        }

        Write-Host "Установка платформы 1С — ожидайте..." -ForegroundColor Green
        & msiexec.exe @params | Out-Null

        # регистрация DLL
        $dir = "C:\Program Files\1cv8\current\bin"
        regsvr32.exe (Join-Path $dir 'comcntr.dll') -s
        Write-Host 'comcntr.dll зарегистрирован' -ForegroundColor Green
        regsvr32.exe (Join-Path $dir 'radmin.dll') -s
        Write-Host 'radmin.dll зарегистрирован' -ForegroundColor Green
    }

    # --- Обновление ссылки current ---
    New-1CCurrentPlatformLink
}