#!/bin/bash

# ReHLDS-M Build Script
# Provides convenient build and test commands for the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BUILD_TYPE="Release"
BUILD_TESTS=0
RUN_TESTS=0
CLEAN_BUILD=0
VERBOSE=0
PARALLEL_JOBS=""
PRESET=""
ACTION="build"

# Detect OS and set default preset
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DEFAULT_PRESET="ninja-clang-linux"
    TEST_PRESET="ninja-clang-linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    DEFAULT_PRESET="ninja-msvc-windows"
    TEST_PRESET="ninja-msvc-windows"
else
    DEFAULT_PRESET="ninja-clang-linux"
    TEST_PRESET="ninja-clang-linux"
fi

PRESET="$DEFAULT_PRESET"

print_usage() {
    cat << EOF
ReHLDS-M Build Script

Usage: ./build.sh [COMMAND] [OPTIONS]

COMMANDS:
  build       Build the project (default)
  test        Build and run unit tests
  clean       Remove build directory
  analyze     Run static analysis (clang-tidy)
  help        Show this help message

OPTIONS:
  --release   Build in Release mode (default)
  --debug     Build in Debug mode
  --preset PRESET
              Use specific CMake preset (e.g., ninja-clang-linux, ninja-gcc-linux, ninja-msvc-windows)
  --tests     Include unit tests in build
  --run-tests Run tests after building
  --jobs N    Number of parallel build jobs (default: auto-detect)
  --verbose   Verbose output
  --clean     Clean before building

EXAMPLES:
  # Build in Release mode (default)
  ./build.sh build

  # Build in Debug mode with tests and run them
  ./build.sh test --debug

  # Clean everything
  ./build.sh clean

  # Run static analysis with clang-tidy
  ./build.sh analyze

  # Build with 4 parallel jobs
  ./build.sh build --jobs 4

EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if CMake is available
check_cmake() {
    if ! command -v cmake &> /dev/null; then
        log_error "CMake is not installed. Please install CMake 3.21 or higher."
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            build)
                ACTION="build"
                shift
                ;;
            test)
                ACTION="test"
                BUILD_TESTS=1
                RUN_TESTS=1
                shift
                ;;
            clean)
                ACTION="clean"
                shift
                ;;
            analyze)
                ACTION="analyze"
                shift
                ;;
            help)
                print_usage
                exit 0
                ;;
            --release)
                BUILD_TYPE="Release"
                shift
                ;;
            --debug)
                BUILD_TYPE="Debug"
                shift
                ;;
            --tests)
                BUILD_TESTS=1
                shift
                ;;
            --run-tests)
                RUN_TESTS=1
                shift
                ;;
            --preset)
                PRESET="$2"
                shift 2
                ;;
            --jobs)
                PARALLEL_JOBS="--parallel $2"
                shift 2
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

configure_project() {
    local config_preset=$1

    if [[ $BUILD_TESTS -eq 1 ]]; then
        # Modify preset name to include unittest variant
        config_preset="${config_preset/ninja-clang-linux/unittest-ninja-gcc-linux}"
        config_preset="${config_preset/ninja-gcc-linux/unittest-ninja-gcc-linux}"
        config_preset="${config_preset/ninja-msvc-windows/unittest-ninja-msvc-windows}"
    fi

    log_info "Configuring with preset: $config_preset"
    cmake --preset "$config_preset"
}

build_project() {
    local config_preset=$1
    local build_type=$2
    local jobs=$3

    if [[ $BUILD_TESTS -eq 1 ]]; then
        config_preset="${config_preset/ninja-clang-linux/unittest-ninja-gcc-linux}"
        config_preset="${config_preset/ninja-gcc-linux/unittest-ninja-gcc-linux}"
        config_preset="${config_preset/ninja-msvc-windows/unittest-ninja-msvc-windows}"
    fi

    log_info "Building project with preset: $config_preset (configuration: $build_type)"
    cmake --build "build/$config_preset" --config "$build_type" $jobs
    log_info "Build completed successfully"
}

run_unit_tests() {
    local test_preset=$1
    local jobs=$2

    test_preset="${test_preset/ninja-clang-linux/ninja-clang-linux}"
    test_preset="${test_preset/ninja-gcc-linux/ninja-gcc-linux}"
    test_preset="${test_preset/ninja-msvc-windows/ninja-msvc-windows}"

    log_info "Running unit tests"
    ctest --preset "$test_preset" $jobs --output-on-failure
    log_info "All tests passed"
}

clean_build() {
    if [[ -d "build" ]]; then
        log_info "Removing build directory"
        rm -rf build
        log_info "Clean completed"
    else
        log_warn "Build directory does not exist"
    fi
}

run_static_analysis() {
    local analysis_preset="clang-tidy-ninja-linux"

    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        analysis_preset="clang-tidy-ninja-windows"
    fi

    log_info "Running Clang-Tidy static analysis (preset: $analysis_preset)"
    cmake --preset "$analysis_preset"
    cmake --build "build/$analysis_preset"
    log_info "Static analysis completed"
}

main() {
    parse_args "$@"
    check_cmake

    case $ACTION in
        build)
            if [[ $CLEAN_BUILD -eq 1 ]]; then
                clean_build
            fi
            configure_project "$PRESET"
            build_project "$PRESET" "$BUILD_TYPE" "$PARALLEL_JOBS"
            ;;
        test)
            if [[ $CLEAN_BUILD -eq 1 ]]; then
                clean_build
            fi
            configure_project "$PRESET"
            build_project "$PRESET" "$BUILD_TYPE" "$PARALLEL_JOBS"
            if [[ $RUN_TESTS -eq 1 ]]; then
                run_unit_tests "$PRESET" "$PARALLEL_JOBS"
            fi
            ;;
        clean)
            clean_build
            ;;
        analyze)
            if [[ $CLEAN_BUILD -eq 1 ]]; then
                clean_build
            fi
            run_static_analysis
            ;;
        *)
            log_error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
}

main "$@"
