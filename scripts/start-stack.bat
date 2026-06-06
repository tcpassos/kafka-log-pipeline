@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0.."

call :run "Kafka cluster" "%ROOT%\kafka-cluster" "docker compose up -d"
if errorlevel 1 goto :error

call :run "Consumer stack" "%ROOT%\logs-siger-consumer-es" "docker compose up -d"
if errorlevel 1 goto :error

call :run "Producer stack" "%ROOT%\logs-siger-producer-filebeat" "docker compose up -d"
if errorlevel 1 goto :error

echo.
echo All services started successfully.
goto :eof

:run
set "NAME=%~1"
set "DIR=%~2"
set "CMD=%~3"
echo [!NAME!] %CMD%
pushd "%DIR%" >nul 2>&1
if errorlevel 1 (
    echo Failed to enter directory %DIR%
    exit /b 1
)
%CMD%
set "RC=%ERRORLEVEL%"
popd >nul
if not "%RC%"=="0" (
    echo [!NAME!] command failed with exit code %RC%
    exit /b %RC%
)
exit /b 0

:error
echo.
echo Stack startup aborted due to previous errors.
exit /b 1
