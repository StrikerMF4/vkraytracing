@echo off
REM ==========================================================
REM  Batch para ejecutar todas las pruebas de DisneyTest2
REM  Cada escena se ejecuta tomando capturas periódicas hasta
REM  llegar a AUTO_EXIT_CAPTURES y luego se cierra.
REM ==========================================================

setlocal enabledelayedexpansion

@REM Uso del ejecutable actual:
@REM   vk_path_tracer.exe -scene <ruta_escena>
@REM                      [-technique <bpt|nee|bdpt>]
@REM                      [-screenshot_time <segundos>]
@REM                      [-screenshot_iter <iteraciones>]
@REM                      [-screenshot_path <ruta>]
@REM                      [-auto-exit <num_capturas>]

set EXE_PATH=.\bin_x64\Release\vk_path_tracer.exe
set BASE_PATH=.\vk_raytracing\media\scenes\Bidirectional\

REM Tecnica a utilizar
set TECHNIQUE=bdpt

REM Configuracion de capturas
set SCREENSHOT_TIME=300
set AUTO_EXIT_CAPTURES=1

echo ==========================================================
echo Ejecutando pruebas Piramide de Veach con:
echo SCREENSHOT_TIME=%SCREENSHOT_TIME%  AUTO_EXIT_CAPTURES=%AUTO_EXIT_CAPTURES%
echo k entre 2 y 5, sin t=0
echo ==========================================================
echo.

REM s de 0 a 5, t de 1 a 5 (t=0 nunca aparece)
for /L %%S in (0,1,5) do (
  for /L %%T in (1,1,5) do (
    set /A K=%%S+%%T-1

    REM Solo ejecutamos si 2 <= k <= 5
    if !K! GEQ 2 if !K! LEQ 5 (
      echo Ejecutando k=!K!, s=%%S, t=%%T

      "%EXE_PATH%" ^
        -scene "%BASE_PATH%veach_lamps_piramide.scn" ^
        -technique %TECHNIQUE% ^
        -screenshot_time %SCREENSHOT_TIME% ^
        -screenshot_path "screenshots\veach_lamps_piramide" ^
        -debug_technique_s %%S ^
        -debug_technique_t %%T ^
        -auto-exit %AUTO_EXIT_CAPTURES%
    )
  )
)

endlocal
