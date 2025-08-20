@echo off
REM VelocityTasks Build and Deploy Script for Windows
REM Usage: build-and-deploy.bat [featherjet-path]

setlocal EnableDelayedExpansion

echo 🚀 VelocityTasks - Build and Deploy Script
echo ==========================================

REM Configuration
set "FEATHERJET_PATH=%~1"
if "%FEATHERJET_PATH%"=="" set "FEATHERJET_PATH=C:\featherjet"
set "APP_NAME=velocity-tasks"
set "BUILD_DIR=target"
set "WAR_FILE=%BUILD_DIR%\%APP_NAME%.war"

echo [INFO] Using FeatherJet path: %FEATHERJET_PATH%

REM Check if Maven is installed
where mvn >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Maven is not installed. Please install Maven first.
    exit /b 1
)

REM Check if Java is installed
where java >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Java is not installed. Please install Java 17+ first.
    exit /b 1
)

echo [INFO] Java and Maven found

REM Clean and build the project
echo [INFO] Cleaning previous build...
call mvn clean

echo [INFO] Building VelocityTasks...
call mvn package -DskipTests=false

REM Check if build was successful
if not exist "%WAR_FILE%" (
    echo [ERROR] Build failed! WAR file not found: %WAR_FILE%
    exit /b 1
)

echo [SUCCESS] Build completed successfully!

REM Check if FeatherJet path exists
if not exist "%FEATHERJET_PATH%" (
    echo [WARNING] FeatherJet directory not found: %FEATHERJET_PATH%
    echo [INFO] Creating FeatherJet directory structure...
    mkdir "%FEATHERJET_PATH%\webapps"
)

REM Deploy to FeatherJet
set "WEBAPP_DIR=%FEATHERJET_PATH%\webapps"
if not exist "%WEBAPP_DIR%" (
    echo [INFO] Creating webapps directory: %WEBAPP_DIR%
    mkdir "%WEBAPP_DIR%"
)

echo [INFO] Deploying to FeatherJet: %WEBAPP_DIR%

REM Deploy WAR file
copy "%WAR_FILE%" "%WEBAPP_DIR%\" >nul
echo [SUCCESS] WAR file deployed: %WEBAPP_DIR%\%APP_NAME%.war

REM Create startup script if it doesn't exist
set "STARTUP_SCRIPT=%FEATHERJET_PATH%\start-velocity-tasks.bat"
if not exist "%STARTUP_SCRIPT%" (
    echo [INFO] Creating startup script: %STARTUP_SCRIPT%
    (
        echo @echo off
        echo REM VelocityTasks Startup Script
        echo cd /d "%%~dp0"
        echo.
        echo echo Starting VelocityTasks on FeatherJet...
        echo echo Access the application at: http://localhost:8080/velocity-tasks/
        echo.
        echo REM Start FeatherJet with optimized settings for VelocityTasks
        echo java -Xms256m -Xmx512m ^
        echo      -XX:+UseG1GC ^
        echo      -XX:MaxGCPauseMillis=200 ^
        echo      -Dfile.encoding=UTF-8 ^
        echo      -jar featherjet-server.jar
        echo.
        echo pause
    ) > "%STARTUP_SCRIPT%"
    echo [SUCCESS] Startup script created
)

REM Check if FeatherJet server JAR exists
set "FEATHERJET_JAR=%FEATHERJET_PATH%\featherjet-server.jar"
if not exist "%FEATHERJET_JAR%" (
    echo [WARNING] FeatherJet server JAR not found: %FEATHERJET_JAR%
    echo [INFO] Please ensure FeatherJet is properly installed in: %FEATHERJET_PATH%
)

REM Print deployment summary
echo.
echo [SUCCESS] 🎉 VelocityTasks deployment completed successfully!
echo.
echo 📋 Deployment Summary:
echo    Application: VelocityTasks v1.0.0
echo    Build file:  %WAR_FILE%
echo    Deploy path: %WEBAPP_DIR%\%APP_NAME%.war
echo    Startup:     %STARTUP_SCRIPT%
echo.
echo 🚀 To start the application:
echo    cd /d "%FEATHERJET_PATH%"
echo    start-velocity-tasks.bat
echo.
echo 🌐 Access URLs:
echo    Application: http://localhost:8080/velocity-tasks/
echo    API:         http://localhost:8080/velocity-tasks/api/tasks
echo    Statistics:  http://localhost:8080/velocity-tasks/api/stats
echo.
echo [INFO] Happy task managing! ⚡

pause
