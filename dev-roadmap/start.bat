@echo off
cd /d "%~dp0"
echo [start] 启动 Three Against One 开发路线图...
start "" http://localhost:8080
python server.py
pause
