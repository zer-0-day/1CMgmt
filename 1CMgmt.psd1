@{
    # Основной файл модуля
    RootModule        = '1CMgmt.psm1'

    # Версия модуля
    ModuleVersion     = '0.8.1'

    # Уникальный идентификатор
    GUID              = 'c70c35ba-027d-4cbd-8998-e8c7215c9af9'

    # Автор и описание
    Author            = 'Dmitriy Chumbaev'
    CompanyName       = ''
    Description       = 'Management module for 1C:Enterprise server'

    # Минимальная версия PowerShell
    PowerShellVersion = '5.1'

    # Требуемые модули
    RequiredModules   = @()

    # Экспортируем всё, пока наводим порядок со структурой
    FunctionsToExport = '*'
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}