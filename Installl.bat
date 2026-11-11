@echo off
color 0B
echo ===================================================
echo   INICIANDO INSTALACAO DO GLPI AGENT E LINKS UTEIS
echo ===================================================

:: 1. Verifica se ja esta a correr como Administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :admin_ok
) else (
    echo.
    echo Solicitando privilegios de Administrador...
    :: Se nao for admin, reinicia este proprio ficheiro .bat com elevacao (UAC)
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:admin_ok
:: 2. Entra na pasta exata onde este ficheiro .bat esta guardado
cd /d "%~dp0"

echo.
echo Privilegios confirmados. A iniciar o instalador...
echo.

:: 3. Executa o script PowerShell ignorando bloqueios de seguranca
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "ForcarIventarioGLPI.ps1"

exit