@echo off
REM ==========================================================
REM  Batch para ejecutar todas las pruebas de DisneyTest2
REM  Cada escena se ejecuta por 10 segundos y luego se cierra.
REM ==========================================================

set EXE_PATH=.\bin_x64\Release\vk_path_tracer.exe
set BASE_PATH=.\vk_raytracing\media\scenes\DisneyTest2
set TIME=1000

REM ----------------------------------------------------------
REM SUBSURFACE
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\subsurface\subsurface0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\subsurface\subsurface025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\subsurface\subsurface05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\subsurface\subsurface075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\subsurface\subsurface1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM METALLIC
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\metallic\metallic0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\metallic\metallic025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\metallic\metallic05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\metallic\metallic075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\metallic\metallic1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM SPECULAR
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\specular\specular0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular\specular025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular\specular05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular\specular075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular\specular1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM SPECULAR TINT
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\specular_tint\specular_tint0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular_tint\specular_tint025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular_tint\specular_tint05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular_tint\specular_tint075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\specular_tint\specular_tint1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM ANISOTROPIC
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\anisotropic\anisotropic0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\anisotropic\anisotropic025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\anisotropic\anisotropic05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\anisotropic\anisotropic075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\anisotropic\anisotropic1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM SHEEN
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\sheen\sheen0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen\sheen025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen\sheen05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen\sheen075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen\sheen1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM SHEEN TINT
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\sheen_tint\sheen_tint0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen_tint\sheen_tint025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen_tint\sheen_tint05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen_tint\sheen_tint075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\sheen_tint\sheen_tint1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM OPACITY
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\opacity\opacity0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\opacity\opacity025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\opacity\opacity05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\opacity\opacity075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\opacity\opacity1.scn path %TIME% --auto-exit

REM ----------------------------------------------------------
REM IOR
REM ----------------------------------------------------------
%EXE_PATH% %BASE_PATH%\ior\ior0.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\ior\ior025.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\ior\ior05.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\ior\ior075.scn path %TIME% --auto-exit
%EXE_PATH% %BASE_PATH%\ior\ior1.scn path %TIME% --auto-exit

echo.
echo ==========================================
echo Todas las escenas fueron procesadas.
echo ==========================================
pause
