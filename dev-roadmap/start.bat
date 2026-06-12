@echo off
cd /d "%~dp0"
echo [start] 启动 Three Against One 开发路线图...
start "" http://localhost:8080
"C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe" server.py
pause
