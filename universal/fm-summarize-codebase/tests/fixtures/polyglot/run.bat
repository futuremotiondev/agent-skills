@echo off
call :greet World
goto :eof

:greet
echo Hello %~1
exit /b 0

:eof
