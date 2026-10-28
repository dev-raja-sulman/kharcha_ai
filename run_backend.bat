@echo off
echo ========================================================
echo  Starting KharchaAI FastAPI Backend Server
echo ========================================================
echo Host: 0.0.0.0 (Accepts connections from localhost, Android emulator 10.0.2.2, and local Wi-Fi devices)
echo Port: 8000
echo Swagger Docs: http://127.0.0.1:8000/docs
echo Health Check: http://127.0.0.1:8000/health
echo ========================================================
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
