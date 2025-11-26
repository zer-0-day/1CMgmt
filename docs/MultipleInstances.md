# Работа с несколькими экземплярами сервера 1С

## Обзор

Начиная с версии 1.3.0, модуль 1CMgmt поддерживает создание нескольких экземпляров сервера 1С на одной машине, работающих на разных портах, без необходимости переустановки платформы.

## Концепция

Каждый экземпляр сервера характеризуется:
- **Префиксом портов** (15, 25, 35 и т.д.)
- **Именем службы** (`Current`, `Current25`, `Current35`)
- **Каталогом данных** (`srvinfo15`, `srvinfo25`, `srvinfo35`)
- **Ссылкой на платформу** (`current`, `current25`, `current35`)

Все экземпляры используют одну и ту же установленную версию платформы.

## Установка первого экземпляра (Current)

```powershell
# Установка с параметрами по умолчанию (порты 15xx)
Install-1CServer

# Или с указанием версии
Install-1CServer -Version 8.3.25.1577 -SetupPath "\\server\distr"
```

Это создаст:
- Службу: `1C:Enterprise 8.3 Server Agent Current`
- Каталог данных: `C:\Program Files\1cv8\srvinfo15`
- Ссылку: `C:\Program Files\1cv8\current` → версия платформы
- Порты: 1540, 1541, 1560-1591

## Добавление дополнительных экземпляров

```powershell
# Создание экземпляра на портах 25xx
Install-1CServer -PortPrefix 25

# Создание экземпляра на портах 35xx
Install-1CServer -PortPrefix 35
```

Модуль автоматически:
1. Обнаружит, что платформа уже установлена
2. Пропустит установку MSI
3. Создаст ссылку `current25` → `current`
4. Создаст каталог `srvinfo25` с правами для USR1CV8
5. Создаст и запустит службу `Current25`

## Структура после установки

```
C:\Program Files\1cv8\
├── 8.3.25.1577\              # Установленная версия платформы
│   └── bin\
│       ├── ragent.exe
│       ├── comcntr.dll
│       └── radmin.dll
│
├── current → 8.3.25.1577     # Junction для Current (15xx)
├── current25 → current       # Junction для Current25 (25xx)
├── current35 → current       # Junction для Current35 (35xx)
│
├── srvinfo15\                # Данные службы Current
│   ├── reg_1541\
│   └── 1CV8Clst.lst
│
├── srvinfo25\                # Данные службы Current25
│   ├── reg_2541\
│   └── 1CV8Clst.lst
│
└── srvinfo35\                # Данные службы Current35
    ├── reg_3541\
    └── 1CV8Clst.lst
```

## Службы Windows

После установки трёх экземпляров:

| Служба | Порты | Каталог данных | Исполняемый файл |
|--------|-------|----------------|------------------|
| `1C:Enterprise 8.3 Server Agent Current` | 1540, 1541, 1560-1591 | `srvinfo15` | `current\bin\ragent.exe` |
| `1C:Enterprise 8.3 Server Agent Current25` | 2540, 2541, 2560-2591 | `srvinfo25` | `current25\bin\ragent.exe` |
| `1C:Enterprise 8.3 Server Agent Current35` | 3540, 3541, 3560-3591 | `srvinfo35` | `current35\bin\ragent.exe` |

## Обновление платформы

При обновлении платформы все экземпляры обновляются автоматически:

```powershell
# Обновление платформы
Start-1CServerUpgrade

# Или с указанием конкретных служб для перезапуска
Start-1CServerUpgrade -PortPrefix @(25, 35)
```

Модуль автоматически:
1. Установит новую версию платформы
2. Обновит ссылку `current` на новую версию
3. Обновит все ссылки `currentXX` → `current`
4. Перезапустит указанные службы

## Проверка конфигурации экземпляра

```powershell
# Проверка экземпляра Current
Test-1CServerInstance

# Проверка экземпляра Current25
Test-1CServerInstance -PortPrefix 25
```

Функция проверяет:
- ✓ Существование и статус службы
- ✓ Наличие каталога данных
- ✓ Права доступа USR1CV8
- ✓ Наличие ссылки current/currentXX
- ✓ Наличие исполняемых файлов
- ✓ Прослушивание портов
- ✓ Существование пользователя USR1CV8

## Логи установки

Все операции установки логируются в:
```
C:\1Cv8.adm\logs\install_<PortPrefix>_<timestamp>.log
```

Пример:
```
C:\1Cv8.adm\logs\install_25_20251126_143022.log
```

## Типичные сценарии использования

### Разделение нагрузки

Создайте несколько экземпляров для распределения баз данных:
- Current (15xx) - производственные базы
- Current25 (25xx) - тестовые базы
- Current35 (35xx) - базы разработки

### Миграция между версиями

1. Установите новую версию на других портах:
   ```powershell
   Install-1CServer -PortPrefix 25 -Version 8.3.26.1200
   ```

2. Протестируйте работу на новой версии

3. Переключите производственные базы на новую версию

4. Удалите старый экземпляр

### Изоляция клиентов

Создайте отдельные экземпляры для разных клиентов с независимыми настройками и ресурсами.

## Удаление экземпляра

```powershell
# Остановка службы
Stop-Service "1C:Enterprise 8.3 Server Agent Current25"

# Удаление службы
sc.exe delete "1C:Enterprise 8.3 Server Agent Current25"

# Удаление каталога данных
Remove-Item "C:\Program Files\1cv8\srvinfo25" -Recurse -Force

# Удаление ссылки
Remove-Item "C:\Program Files\1cv8\current25" -Force
```

## Ограничения

- Все экземпляры используют одного пользователя службы (USR1CV8)
- Все экземпляры используют одну версию платформы
- Префикс портов должен быть двузначным числом (15, 25, 35 и т.д.)
- Порты должны быть свободны перед установкой

## Устранение проблем

### Служба не запускается

```powershell
# Проверьте конфигурацию
Test-1CServerInstance -PortPrefix 25

# Проверьте логи Windows
Get-EventLog -LogName Application -Source "1CV8*" -Newest 10
```

### Порты заняты

```powershell
# Проверьте, какие порты заняты
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -like "25*" }
```

### Проблемы с правами доступа

```powershell
# Проверьте права на каталог
Get-Acl "C:\Program Files\1cv8\srvinfo25" | Format-List

# Установите права вручную
$acl = Get-Acl "C:\Program Files\1cv8\srvinfo25"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "$env:COMPUTERNAME\USR1CV8", "FullControl", 
    "ContainerInherit, ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl "C:\Program Files\1cv8\srvinfo25" $acl
```
