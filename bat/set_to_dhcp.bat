@echo off
echo.
echo.
echo ######################��ѡ��Ҫִ�еĲ���######################
echo --------1����������1�����س�������ΪDHCP----------------------
echo --------2����������2�����س�������Ϊ192.168.58.58-------------
echo.
echo.
echo ��ѡ��Ҫִ�еĲ���
set /p num=

if "%num%"=="1" (
	netsh interface ip set address name="��" source=dhcp
)

if "%num%"=="2" (
	netsh interface ip set address name="��" static 192.168.58.58 255.255.255.0 192.168.58.1
	echo set "��" to 192.168.58.58
)

@pause