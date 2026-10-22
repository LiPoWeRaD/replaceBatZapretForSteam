@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

:: Принудительный переход в папку, где физически находится сам этот bat-файл
cd /d "%~dp0"

echo ====================================================================
echo    ПОЛНОЦЕННЫЙ УСТАНОВЩИК И МОДИФИКАТОР СТРАТЕГИИ ZAPRET
echo ====================================================================
echo:

:: Проверка прав администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ОШИБКА] Пожалуйста, запустите этот скрипт ОТ ИМЕНИ АДМИНИСТРАТОРА.
    echo Нажмите правой кнопкой мыши на файл -> Запуск от имени администратора.
    echo:
    pause
    exit /b
)

:: 1. ЗАПРОС ПУТИ К КАТАЛОГУ ZAPRET
:input_path
echo Шаг 1: Укажите расположение утилиты zapret.
echo (Можно ввести полный путь вручную или просто перетащить папку zapret сюда мышкой)
set /p "ZAPRET_PATH=Путь к папке: "

:: Очистка от случайных кавычек, если путь перетащили мышкой
set "ZAPRET_PATH=%ZAPRET_PATH:"=%"

:: Проверка существования папки
if not exist "%ZAPRET_PATH%\" (
    echo [ОШИБКА] Указанная папка не найдена. Попробуйте еще раз.
    echo:
    goto input_path
)

:: Настройка внутренних путей утилиты
set "LISTS_DIR=%ZAPRET_PATH%\lists"
set "BIN_DIR=%ZAPRET_PATH%\bin"

if not exist "%LISTS_DIR%\" (
    echo [ОШИБКА] В указанной папке отсутствует директория "lists". Проверьте правильность пути.
    echo:
    goto input_path
)

echo [ОК] Путь к утилите успешно подтвержден.
echo:

:: 2. ЗАПРОС ИМЕНИ BAT-ФАЙЛА
:input_bat
echo Шаг 2: Укажите имя bat-файла внутри папки zapret, который вы хотите изменить.
set /p "BAT_NAME=Имя файла (например, alt1.bat или discord.bat): "

set "TARGET_BAT=%ZAPRET_PATH%\%BAT_NAME%"

if not exist "%TARGET_BAT%" (
    echo [ОШИБКА] Файл "%BAT_NAME%" не найден в папке %ZAPRET_PATH%.
    echo Проверьте имя файла и попробуйте снова.
    echo:
    goto input_bat
)

echo [ОК] Целевой файл "%BAT_NAME%" найден. Начинаю процесс установки...
echo:
echo --------------------------------------------------------------------

:: 3. ОБРАБОТКА ПОЛЬЗОВАТЕЛЬСКИХ СПИСКОВ В ПАПКЕ LISTS
echo [1/3] Проверка и синхронизация списков доменов в %LISTS_DIR%...

:: Обработка list-general-user.txt
if exist "list-general-user.txt" (
    if not exist "%LISTS_DIR%\list-general-user.txt" (
        echo   [СОЗДАНИЕ] Файла list-general-user.txt не было в папке lists. Создаю...
        copy /Y "list-general-user.txt" "%LISTS_DIR%\list-general-user.txt" >nul
        echo   [УСПЕХ] Файл успешно создан и заполнен данными.
    ) else (
        echo   [ДОПОЛНЕНИЕ] Файл list-general-user.txt уже существует в папке lists. Дополняю...
        echo: >> "%LISTS_DIR%\list-general-user.txt"
        type "list-general-user.txt" >> "%LISTS_DIR%\list-general-user.txt"
        echo   [УСПЕХ] Новые домены успешно добавлены в конец файла.
    )
) else (
    echo   [ОШИБКА] Локальный файл list-general-user.txt не найден в папке %~dp0
)

echo:

:: Обработка list-exclude-user.txt
if exist "list-exclude-user.txt" (
    if not exist "%LISTS_DIR%\list-exclude-user.txt" (
        echo   [СОЗДАНИЕ] Файла list-exclude-user.txt не было в папке lists. Создаю...
        copy /Y "list-exclude-user.txt" "%LISTS_DIR%\list-exclude-user.txt" >nul
        echo   [УСПЕХ] Файл успешно создан и заполнен данными.
    ) else (
        echo   [ДОПОЛНЕНИЕ] Файл list-exclude-user.txt уже существует в папке lists. Дополняю...
        echo: >> "%LISTS_DIR%\list-exclude-user.txt"
        type "list-exclude-user.txt" >> "%LISTS_DIR%\list-exclude-user.txt"
        echo   [УСПЕХ] Новые домены успешно добавлены в конец файла.
    )
) else (
    echo   [ОШИБКА] Локальный файл list-exclude-user.txt не найден в папке %~dp0
)

echo --------------------------------------------------------------------

:: 4. МОДИФИКАЦИЯ СТРАТЕГИИ В BAT-ФАЙЛЕ
echo [2/3] Обновление стратегий обхода в файле %BAT_NAME%...

set "TEMP_BAT=%TARGET_BAT%.tmp"
if exist "%TEMP_BAT%" del "%TEMP_BAT%"

:: Наша стопроцентно рабочая Ростелеком-стратегия fakedsplit
set "NEW_STRATEGY=--filter-tcp=80,443 --hostlist="%%LISTS%%list-general.txt" --hostlist="%%LISTS%%list-general-user.txt" --hostlist-exclude="%%LISTS%%list-exclude.txt" --hostlist-exclude="%%LISTS%%list-exclude-user.txt" --ipset-exclude="%%LISTS%%ipset-exclude.txt" --ipset-exclude="%%LISTS%%ipset-exclude-user.txt" --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="%%BIN%%stun.bin" --dpi-desync-fake-tls="%%BIN%%tls_clienthello_www_google_com.bin" --dpi-desync-fake-http="%%BIN%%tls_clienthello_www_sferum_ru.bin" --new ^"

:: Чтение bat-файла и замена правила для list-general
for /f "delims=" %%A in ('findstr /n "^" "%TARGET_BAT%"') do (
    set "line=%%A"
    set "line=!line:*:=!"
    
    echo !line! | findstr /c:"list-general.txt" >nul
    if !errorlevel! equ 0 (
        echo !NEW_STRATEGY! >> "%TEMP_BAT%"
        echo   + Старое правило для общего списка заменено на fakedsplit.
    ) else (
        echo !line! >> "%TEMP_BAT%"
    )
)

:: Перезапись оригинального файла собранным результатом
move /y "%TEMP_BAT%" "%TARGET_BAT%" >nul

:: 5. ЗАВЕРШЕНИЕ РАБОТЫ
echo [3/3] Финализация конфигурации...
echo:
echo ====================================================================
echo [УСПЕХ] Настройка структуры списков и скрипта полностью завершена!
echo Изменения внесены в: %TARGET_BAT%
echo Текстовые списки проверены и обновлены в папке: %LISTS_DIR%
echo ====================================================================
echo:
echo Теперь вы можете запустить модифицированный "%BAT_NAME%" от Администратора.
echo:
pause
