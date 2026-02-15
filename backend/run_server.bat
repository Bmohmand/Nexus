@echo off
REM Run Manifest FastAPI server. Use pip to install deps first (see README.md).
cd /d "%~dp0"
python -m uvicorn server.main:app --reload --port 8000
pause
