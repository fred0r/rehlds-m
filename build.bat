@echo off
REM ReHLDS-M Build Script for Windows
REM Provides convenient build and test commands for the project

setlocal enabledelayedexpansion

REM Default values
set "BUILD_TYPE=Release"
set "BUILD_TESTS=0"
set "RUN_TESTS=0"
set "CLEAN_BUILD=0"
set "PRESET=ninja-msvc-windows"
set "ACTION=build"
set "PARALLEL_JOBS="

REM Parse command line arguments
if "%1"=="" (
    set "ACTION=build"
) else if "%1"=="build" (
    set "ACTION=build"
    shift
) else if "%1"=="test" (
    set "ACTION=test"
    set "BUILD_TESTS=1"
    set "RUN_TESTS=1"
    shift
) else if "%1"=="clean" (
    set "ACTION=clean"
    shift
) else if "%1"=="analyze" (
    set "ACTION=analyze"
    shift
) else if "%1"=="help" (
    call :print_usage
    exit /b 0
) else (
    echo [ERROR] Unknown command: %1
    call :print_usage
    exit /b 1
)

REM Parse options after command
:parse_options
if not "%1"=="" (
    if "%1"=="--release" (
        set "BUILD_TYPE=Release"
        shift
        goto parse_options
    ) else if "%1"=="--debug" (
        set "BUILD_TYPE=Debug"
        shift
        goto parse_options
    ) else if "%1"=="--tests" (
        set "BUILD_TESTS=1"
        shift
        goto parse_options
    ) else if "%1"=="--run-tests" (
        set "RUN_TESTS=1"
        shift
        goto parse_options
    ) else if "%1"=="--preset" (
        set "PRESET=%2"
        shift
        shift
        goto parse_options
    ) else if "%1"=="--jobs" (
        set "PARALLEL_JOBS=--parallel %2"
        shift
        shift
        goto parse_options
    ) else if "%1"=="--clean" (
        set "CLEAN_BUILD=1"
        shift
        goto parse_options
    ) else (
        echo [ERROR] Unknown option: %1
        call :print_usage
        exit /b 1
    )
)

REM Check if CMake is available
where cmake >nul 2>nul
if errorlevel 1 (
    echo [ERROR] CMake is not installed. Please install CMake 3.21 or higher.
    exit /b 1
)

REM Execute action
if "!ACTION!"=="build" (
    if "!CLEAN_BUILD!"=="1" call :clean_build
    call :configure_project "!PRESET!"
    call :build_project "!PRESET!" "!BUILD_TYPE!" "!PARALLEL_JOBS!"
) else if "!ACTION!"=="test" (
    if "!CLEAN_BUILD!"=="1" call :clean_build
    call :configure_project "!PRESET!"
    call :build_project "!PRESET!" "!BUILD_TYPE!" "!PARALLEL_JOBS!"
    if "!RUN_TESTS!"=="1" call :run_unit_tests "!PRESET!" "!PARALLEL_JOBS!"
) else if "!ACTION!"=="clean" (
    call :clean_build
) else if "!ACTION!"=="analyze" (
    if "!CLEAN_BUILD!"=="1" call :clean_build
    call :run_static_analysis
)

exit /b 0

REM ============================================================================
REM Functions
REM ============================================================================

:print_usage
echo ReHLDS-M Build Script
echo.
echo Usage: build.bat [COMMAND] [OPTIONS]
echo.
echo COMMANDS:
echo   build       Build the project (default)
echo   test        Build and run unit tests
echo   clean       Remove build directory
echo   analyze     Run static analysis (clang-tidy)
echo   help        Show this help message
echo.
echo OPTIONS:
echo   --release   Build in Release mode (default)
echo   --debug     Build in Debug mode
echo   --preset PRESET
echo               Use specific CMake preset
echo               (e.g., ninja-msvc-windows, vs2022-msvc-windows)
echo   --tests     Include unit tests in build
echo   --run-tests Run tests after building
echo   --jobs N    Number of parallel build jobs
echo   --clean     Clean before building
echo.
echo EXAMPLES:
echo   REM Build in Release mode (default)
echo   build.bat build
echo.
echo   REM Build in Debug mode with tests and run them
echo   build.bat test --debug
echo.
echo   REM Clean everything
echo   build.bat clean
echo.
echo   REM Run static analysis
echo   build.bat analyze
echo.
goto :eof

:configure_project
setlocal enabledelayedexpansion
set "config_preset=%~1"

if "!BUILD_TESTS!"=="1" (
    set "config_preset=!config_preset:ninja-msvc-windows=unittest-ninja-msvc-windows!"
    set "config_preset=!config_preset:vs2022-msvc-windows=vs2022-msvc-windows!"
)

echo [INFO] Configuring with preset: !config_preset!
cmake --preset "!config_preset!"
if errorlevel 1 (
    echo [ERROR] Configuration failed
    exit /b 1
)
endlocal
goto :eof

:build_project
setlocal enabledelayedexpansion
set "config_preset=%~1"
set "build_type=%~2"
set "parallel_jobs=%~3"

if "!BUILD_TESTS!"=="1" (
    set "config_preset=!config_preset:ninja-msvc-windows=unittest-ninja-msvc-windows!"
)

echo [INFO] Building project with preset: !config_preset! (configuration: !build_type!)
cmake --build "build\!config_preset!" --config "!build_type!" !parallel_jobs!
if errorlevel 1 (
    echo [ERROR] Build failed
    exit /b 1
)
echo [INFO] Build completed successfully
endlocal
goto :eof

:run_unit_tests
setlocal enabledelayedexpansion
set "test_preset=%~1"
set "parallel_jobs=%~2"

echo [INFO] Running unit tests
ctest --preset "!test_preset!" !parallel_jobs! --output-on-failure
if errorlevel 1 (
    echo [ERROR] Tests failed
    exit /b 1
)
echo [INFO] All tests passed
endlocal
goto :eof

:clean_build
if exist build (
    echo [INFO] Removing build directory
    rmdir /s /q build
    echo [INFO] Clean completed
) else (
    echo [WARN] Build directory does not exist
)
goto :eof

:run_static_analysis
setlocal enabledelayedexpansion
set "analysis_preset=clang-tidy-ninja-msvc-windows"

echo [INFO] Running Clang-Tidy static analysis (preset: !analysis_preset!)
cmake --preset "!analysis_preset!"
if errorlevel 1 (
    echo [ERROR] Configuration failed
    exit /b 1
)
cmake --build "build\!analysis_preset!"
if errorlevel 1 (
    echo [ERROR] Static analysis build failed
    exit /b 1
)
echo [INFO] Static analysis completed
endlocal
goto :eof
