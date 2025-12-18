REM ==========================================================
REM  Batch para ejecutar todas las pruebas
REM  Cada escena se ejecuta por TIME segundos y luego se cierra.
REM ==========================================================

@REM Uso:
@REM   programa -scene <ruta_escena>
@REM           [-technique <bpt|nee|bdpt>]
@REM           [-screenshot_time <segundos>]
@REM           [-screenshot_iter <iteraciones>]
@REM           [-auto-exit <num_capturas>]
@REM           [-h | --help]
@REM 
@REM Descripcion de parametros:
@REM   -scene <ruta>              Ruta al archivo .scn de la escena.
@REM   -technique <...>           Tecnica de render: bpt | nee | bdpt.
@REM   -screenshot_time <s>       Toma una captura cada <s> segundos.
@REM   -screenshot_iter <n>       Toma una captura cada <n> iteraciones.
@REM   -screenshot_path <ruta>    Ruta donde se guardan las capturas.
@REM   -auto-exit <k>             Cierra el programa luego de <k> capturas.
@REM   -h, --help                 Muestra esta ayuda.

set EXE_PATH=vk_path_tracer.exe
set SPONZA_PATH=.\scenes\sponza.scn
set SPONZA2_PATH=.\scenes\sponza2.scn
set SPONZA_LUCES_PATH=.\scenes\sponza_luces.scn
set SPONZA2_LUCES_PATH=.\scenes\sponza2_luces.scn
set BEDROOM_PATH=.\scenes\bedroom.scn
set VEACH_PATH=.\scenes\veach_lamps.scn
set CORNELBOX_PATH=.\scenes\cornellbox_sphere.scn
set CORNELBOX_MESH_PATH=.\scenes\cornellbox_sphere_mesh.scn
set SCREENSHOT_TIME=3600
set SCREENSHOT_ITER=10
set AUTO_EXIT_CAPTURES=1


@REM @REM CORNELL BOX - BPT
@REM %EXE_PATH% -scene %CORNELBOX_PATH% -technique bpt -screenshot_time %SCREENSHOT_TIME% -auto-exit 3


@REM :: PRUEBA CORNELL BOX - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %CORNELBOX_MESH_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %CORNELBOX_MESH_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\cornelbox_mesh\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %CORNELBOX_MESH_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\cornelbox_mesh\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

@REM :: PRUEBA SPONZA CON LAMPARAS - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %SPONZA_LUCES_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %SPONZA_LUCES_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza_luces\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %SPONZA_LUCES_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza_luces\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %SPONZA2_LUCES_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %SPONZA2_LUCES_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza2_luces\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %SPONZA2_LUCES_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza2_luces\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

@REM @REM CORNELL BOX - BPT
@REM %EXE_PATH% -scene %CORNELBOX_PATH% -technique bpt -screenshot_time %SCREENSHOT_TIME% -auto-exit 3


@REM :: PRUEBA CORNELL BOX - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %CORNELBOX_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %CORNELBOX_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\cornelbox\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %CORNELBOX_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\cornelbox\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

@REM :: PRUEBA BEDROOM - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %BEDROOM_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %BEDROOM_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\bedroom\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %BEDROOM_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\bedroom\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)


@REM :: PRUEBA VEACH - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %VEACH_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %VEACH_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\veach\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %VEACH_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\veach\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

@REM :: PRUEBA SPONZA - TIME BASED CAPTURES

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %SPONZA_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %SPONZA_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %SPONZA_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

for %%T in (bpt nee bdpt) do (
    echo ----------------------------------------------------
    echo Escena: %SPONZA2_PATH%
    echo Tecnica: %%T
    echo Lanzando: "%EXE_PATH%" -scene %SPONZA2_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza2\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo ----------------------------------------------------
    "%EXE_PATH%" -scene %SPONZA2_PATH% -technique %%T -screenshot_time %SCREENSHOT_TIME% -screenshot_path screenshots\sponza2\%%T -auto-exit %AUTO_EXIT_CAPTURES%
    echo.
)

PAUSE

@REM FIN DEL SCRIPT
