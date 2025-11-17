# 1CMgmt

> PowerShell-модуль для автоматизации установки, обновления и администрирования серверов 1С:Предприятие

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/1CMgmt)](https://www.powershellgallery.com/packages/1CMgmt)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Что это?

**1CMgmt** автоматизирует рутинные задачи администрирования 1С:
- ✅ Установка и обновление платформы и серверов
- ✅ Управление несколькими инстансами (current, current25, current35...)
- ✅ Архивация журналов регистрации
- ✅ Автоматическое обновление через планировщик Windows
- ✅ Удобное интерактивное меню

---

## Быстрый старт

```powershell
# 1. Установите модуль
Install-Module -Name 1CMgmt -Scope CurrentUser -Force

# 2. Запустите главное меню
Import-Module 1CMgmt
Invoke-1CMenu
```

Готово! Используйте меню для всех операций.

---

## Содержание

- [Установка](#установка)
- [Использование](#использование)
  - [Через меню (рекомендуется)](#через-меню-рекомендуется)
  - [Через команды](#через-команды)
- [Типовые сценарии](#типовые-сценарии)
- [FAQ](#faq)
- [Справочник команд](#справочник-команд)

---

## Установка

### Требования
- Windows Server 2012 R2 или новее
- PowerShell 5.1 или выше
- Права администратора
- Доступ к PowerShell Gallery

### Установка модуля

**1. Откройте PowerShell от администратора**

**2. Разрешите выполнение скриптов (если требуется)**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**3. Установите модуль**
```powershell
Install-Module -Name 1CMgmt -Scope CurrentUser -Force
```

**4. Проверьте установку**
```powershell
Import-Module 1CMgmt
Get-Command -Module 1CMgmt
```

### Обновление
```powershell
Update-Module -Name 1CMgmt
```

### Удаление
```powershell
Uninstall-Module -Name 1CMgmt
```

---

## Использование

### Через меню (рекомендуется)

Самый простой способ — использовать интерактивное меню:

```powershell
Invoke-1CMenu
```

**Структура меню:**
```
УСТАНОВКА И ОБНОВЛЕНИЕ
  1. Установить сервер (быстро)
  2. Обновить сервер (быстро)
  3. Установка с параметрами...
  4. Обновление с параметрами...

ОБСЛУЖИВАНИЕ
  5. Сжать журналы регистрации
  6. Показать установленные версии
  7. Информация о сервере

АВТОМАТИЗАЦИЯ
  8. Настроить автообновление...
  9. Настроить архивацию логов...

ПРОЧЕЕ
  h. Справка
  u. Обновить модуль
  q. Выход
```

**Навигация:**
- `Enter` — подтвердить / продолжить
- `r` — вернуться в главное меню
- `q` — выход

### Через команды

Для автоматизации и скриптов используйте команды напрямую:

```powershell
# Установка сервера
Install-1CServer

# Обновление сервера
Start-1CServerUpgrade

# Архивация логов
Compress-1Clogs

# Информация о сервере
Get-1C
```

---

## Типовые сценарии

### 1. Первая установка сервера 1С

**Подготовка:**
1. Создайте папку `C:\1Cv8.adm` (или на другом диске)
2. Скопируйте туда архив `windows64full_8_3_xx_xxxx.rar`

**Установка:**
```powershell
# Через меню
Invoke-1CMenu → 1

# Или командой
Install-1CServer
```

Модуль автоматически:
- Установит платформу 1С
- Создаст пользователя `USR1CV8`
- Создаст службу `1C:Enterprise 8.3 Server Agent Current`
- Настроит порты 1541, 1540, 1560-1591

### 2. Установка второго сервера (другие порты)

```powershell
# Второй сервер на портах 25xx
Install-1CServer -PortPrefix 25

# Третий сервер на портах 35xx
Install-1CServer -PortPrefix 35
```

Создаются службы: `Current25`, `Current35` и т.д.

### 3. Обновление сервера

```powershell
# Из локального кэша
Start-1CServerUpgrade

# Из сетевой папки
Start-1CServerUpgrade -SetupPath '\\server\distr\8.3.25.1704'

# С перезапуском дополнительных служб
Start-1CServerUpgrade -PortPrefix 25,35
```

### 4. Настройка автоматического обновления

```powershell
# Через меню (рекомендуется)
Invoke-1CMenu → 8 → 1

# Или командой
New-1CServerAutoUpgradeTask -RunAsUser 'DOMAIN\svc-1c' -At '03:00'
```

Создаётся задача в планировщике Windows для ночного обновления.

### 5. Архивация журналов регистрации

```powershell
# Разовая архивация
Compress-1Clogs

# С параметрами
Compress-1Clogs -FileDays 14 -ArchiveDays 60

# Настройка автоматической архивации
Invoke-1CMenu → 9 → 1
```

---

## FAQ

### Функции модуля не видны после установки

Импортируйте модуль в текущую сессию:
```powershell
Import-Module 1CMgmt
```

Для автоматической загрузки добавьте эту команду в профиль PowerShell.

### Ошибка "Выполнение скриптов отключено"

Разрешите выполнение скриптов:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Где хранятся дистрибутивы?

Модуль ищет архивы в папке `1Cv8.adm` в корне любого диска (C:\, D:\, и т.д.).

Формат архива: `windows64full_8_3_xx_xxxx.rar`

### Как работает установка из сетевой папки?

При указании UNC-пути (`\\server\share\...`) модуль:
1. Копирует архив в локальную папку `C:\1Cv8.adm`
2. Распаковывает его
3. Выполняет установку
4. Удаляет архив после успешной установки

### MSI вернул код 3010 — это ошибка?

Нет, код 3010 означает "успешная установка, требуется перезагрузка". Это нормальное поведение.

### Как установить несколько серверов на одной машине?

Используйте параметр `-PortPrefix`:
```powershell
Install-1CServer -PortPrefix 15  # Current (порты 15xx)
Install-1CServer -PortPrefix 25  # Current25 (порты 25xx)
Install-1CServer -PortPrefix 35  # Current35 (порты 35xx)
```

### Требуется ли 7-Zip?

Да, для распаковки RAR-архивов требуется 7-Zip, установленный по пути:
```
C:\Program Files\7-Zip\7z.exe
```

---

## Справочник команд

### Основные команды

| Команда | Описание |
|---------|----------|
| `Invoke-1CMenu` | Главное интерактивное меню |
| `Install-1CServer` | Установка сервера 1С |
| `Start-1CServerUpgrade` | Обновление сервера |
| `Install-1CPlatform` | Установка/обновление платформы |
| `Compress-1Clogs` | Архивация журналов регистрации |

### Информационные команды

| Команда | Описание |
|---------|----------|
| `Get-1C` | Информация о сервере и базах |
| `Get-1CInstalledVersion` | Список установленных версий |
| `Find-1CDistroFolder` | Поиск папки с дистрибутивами |

### Автоматизация

| Команда | Описание |
|---------|----------|
| `New-1CServerAutoUpgradeTask` | Создать задачу автообновления |
| `New-1CDefaultCompressTask` | Создать задачу архивации (по умолчанию) |
| `New-1CCustomCompressTask` | Создать задачу архивации (с параметрами) |

### Служебные команды

| Команда | Описание |
|---------|----------|
| `New-1CCurrentPlatformLink` | Создать ссылку на текущую платформу |
| `New-1CDistroPackage` | Распаковать дистрибутив |
| `New-1CServiceUser` | Создать служебного пользователя |
| `Update-Module1CMgmt` | Обновить модуль 1CMgmt |

### Параметры команд

**Install-1CServer**
```powershell
Install-1CServer [-PortPrefix <int>] [-Version <string>] [-SetupPath <string>] [-Credential <PSCredential>]
```
- `-PortPrefix` — префикс портов (15, 25, 35...). По умолчанию: 15
- `-Version` — версия платформы (например, '8.3.25.1546'). По умолчанию: последняя
- `-SetupPath` — путь к дистрибутиву (локальный или UNC)
- `-Credential` — учётные данные для USR1CV8

**Start-1CServerUpgrade**
```powershell
Start-1CServerUpgrade [-SetupPath <string>] [-PortPrefix <int[]>]
```
- `-SetupPath` — путь к дистрибутиву
- `-PortPrefix` — дополнительные службы для перезапуска (25, 35...)

**Compress-1Clogs**
```powershell
Compress-1Clogs [-FileDays <int>] [-ArchiveDays <int>] [-Path <string>]
```
- `-FileDays` — дней до архивации. По умолчанию: 7
- `-ArchiveDays` — дней хранения архивов. По умолчанию: 90
- `-Path` — путь к srvinfo (опционально)

**New-1CServerAutoUpgradeTask**
```powershell
New-1CServerAutoUpgradeTask -RunAsUser <string> [-At <string>] [-SetupPath <string>] [-PortPrefix <int[]>] [-Shell <string>]
```
- `-RunAsUser` — учётная запись (обязательно)
- `-At` — время запуска (HH:mm). По умолчанию: 03:30
- `-SetupPath` — путь к дистрибутивам
- `-PortPrefix` — префиксы портов для CurrentXX
- `-Shell` — WindowsPowerShell или PowerShell7

---

## Дополнительная информация

### Структура каталогов

```
C:\Program Files\1cv8\
├── 8.3.25.1546\          # Установленная версия
│   └── bin\              # Исполняемые файлы
├── current\              # Символическая ссылка на активную версию
└── srvinfo15\            # Данные службы Current
    └── reg_*\            # Кластеры
        └── <UUID>\       # Базы данных
            └── 1Cv8Log\  # Журналы регистрации

C:\1Cv8.adm\              # Кэш дистрибутивов
└── 8.3.25.1546\
    └── Server\64\        # Распакованный дистрибутив
```

### Порты по умолчанию

| Префикс | Служба | Порты |
|---------|--------|-------|
| 15 | Current | 1541 (reg), 1540 (ctrl), 1560-1591 (range) |
| 25 | Current25 | 2541 (reg), 2540 (ctrl), 2560-2591 (range) |
| 35 | Current35 | 3541 (reg), 3540 (ctrl), 3560-3591 (range) |

### Лицензия

MIT License

### Поддержка

- **Issues**: [GitHub Issues](https://github.com/yourusername/1CMgmt/issues)
- **PowerShell Gallery**: [1CMgmt](https://www.powershellgallery.com/packages/1CMgmt)

---
