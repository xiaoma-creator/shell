@echo off
echo.
echo.
echo ######################请选择要执行的操作######################
echo --------1、输入数字1并按回车，设置为DHCP----------------------
echo --------2、输入数字2并按回车，设置为192.168.58.58-------------
echo.
echo.
echo 请选择要执行的操作
set /p num=

if "%num%"=="1" (
	netsh interface ip set address name="下" source=dhcp
)

if "%num%"=="2" (
	netsh interface ip set address name="下" static 192.168.58.58 255.255.255.0 192.168.58.1
	echo set "下" to 192.168.58.58
)

@pause