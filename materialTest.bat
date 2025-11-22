@echo off
REM ==========================================================
REM  Batch para ejecutar todas las pruebas de DisneyTest2
REM  Cada escena se ejecuta tomando capturas periódicas hasta
REM  llegar a AUTO_EXIT_CAPTURES y luego se cierra.
REM ==========================================================

@REM Uso del ejecutable actual:
@REM   vk_path_tracer.exe -scene <ruta_escena>
@REM                      [-technique <bpt|nee|bdpt>]
@REM                      [-screenshot_time <segundos>]
@REM                      [-screenshot_iter <iteraciones>]
@REM                      [-screenshot_path <ruta>]
@REM                      [-auto-exit <num_capturas>]

set EXE_PATH=.\bin_x64\Release\vk_path_tracer.exe
set BASE_PATH=.\vk_raytracing\media\scenes\DisneyTest2

REM Tecnica a utilizar
set TECHNIQUE=bpt

REM Configuracion de capturas
set SCREENSHOT_TIME=1000
set AUTO_EXIT_CAPTURES=1

echo ==========================================================
echo Ejecutando pruebas DisneyTest2 con tecnica %TECHNIQUE%
echo SCREENSHOT_TIME=%SCREENSHOT_TIME%  AUTO_EXIT_CAPTURES=%AUTO_EXIT_CAPTURES%
echo ==========================================================
echo.

REM ----------------------------------------------------------
REM SUBSURFACE
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\subsurface\subsurface0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\subsurface\subsurface0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\subsurface\subsurface025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\subsurface\subsurface025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\subsurface\subsurface05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\subsurface\subsurface05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\subsurface\subsurface075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\subsurface\subsurface075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\subsurface\subsurface1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\subsurface\subsurface1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM METALLIC
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\metallic\metallic0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\metallic\metallic0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\metallic\metallic025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\metallic\metallic025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\metallic\metallic05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\metallic\metallic05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\metallic\metallic075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\metallic\metallic075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\metallic\metallic1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\metallic\metallic1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM ROUGHNESS
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\roughness\roughness0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\roughness\roughness0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\roughness\roughness025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\roughness\roughness025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\roughness\roughness05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\roughness\roughness05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\roughness\roughness075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\roughness\roughness075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\roughness\roughness1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\roughness\roughness1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM SPECULAR
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular\specular0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular\specular0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular\specular025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular\specular025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular\specular05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular\specular05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular\specular075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular\specular075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular\specular1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular\specular1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM SPECULAR TINT
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular_tint\specular_tint0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular_tint\specular_tint0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular_tint\specular_tint025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular_tint\specular_tint025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular_tint\specular_tint05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular_tint\specular_tint05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular_tint\specular_tint075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular_tint\specular_tint075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\specular_tint\specular_tint1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\specular_tint\specular_tint1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM ANISOTROPIC
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\anisotropic\anisotropic0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\anisotropic\anisotropic0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\anisotropic\anisotropic025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\anisotropic\anisotropic025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\anisotropic\anisotropic05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\anisotropic\anisotropic05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\anisotropic\anisotropic075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\anisotropic\anisotropic075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\anisotropic\anisotropic1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\anisotropic\anisotropic1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM SHEEN
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen\sheen0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen\sheen0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen\sheen025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen\sheen025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen\sheen05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen\sheen05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen\sheen075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen\sheen075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen\sheen1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen\sheen1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM SHEEN TINT
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen_tint\sheen_tint0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen_tint\sheen_tint0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen_tint\sheen_tint025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen_tint\sheen_tint025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen_tint\sheen_tint05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen_tint\sheen_tint05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen_tint\sheen_tint075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen_tint\sheen_tint075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\sheen_tint\sheen_tint1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\sheen_tint\sheen_tint1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM OPACITY
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\opacity\opacity0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\opacity\opacity0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\opacity\opacity025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\opacity\opacity025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\opacity\opacity05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\opacity\opacity05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\opacity\opacity075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\opacity\opacity075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\opacity\opacity1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\opacity\opacity1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

REM ----------------------------------------------------------
REM IOR
REM ----------------------------------------------------------
"%EXE_PATH%" ^
  -scene "%BASE_PATH%\ior\ior0.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\ior\ior0" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\ior\ior025.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\ior\ior025" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\ior\ior05.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\ior\ior05" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\ior\ior075.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\ior\ior075" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

"%EXE_PATH%" ^
  -scene "%BASE_PATH%\ior\ior1.scn" ^
  -technique %TECHNIQUE% ^
  -screenshot_time %SCREENSHOT_TIME% ^
  -screenshot_path "screenshots\DisneyTest2\ior\ior1" ^
  -auto-exit %AUTO_EXIT_CAPTURES%

echo.
echo ==========================================
echo Todas las escenas de DisneyTest2 fueron procesadas.
echo ==========================================
pause
