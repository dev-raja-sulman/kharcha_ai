@echo off
echo ========================================================
echo  Launching KharchaAI Flutter Mobile Application
echo ========================================================
echo Select target:
echo [1] Android Emulator (Auto-connects to 10.0.2.2:8000)
echo [2] Windows Desktop / Chrome Web (Auto-connects to 127.0.0.1:8000)
echo [3] Physical Mobile Device over Wi-Fi (Connects to 192.168.1.13:8000)
echo ========================================================
set /p choice="Enter choice (1, 2, or 3): "

if "%choice%"=="1" (
    echo Running on Android Emulator...
    flutter run
) else if "%choice%"=="2" (
    echo Running on Desktop / Web...
    flutter run -d chrome
) else if "%choice%"=="3" (
    echo Running on Physical Mobile Device pointing to host IP 192.168.1.13:8000...
    flutter run --dart-define=API_URL=http://192.168.1.13:8000
) else (
    flutter run
)
pause
