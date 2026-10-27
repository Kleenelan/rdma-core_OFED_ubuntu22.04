#!/bin/bash
# Build rdma-core from MLNX_OFED_SRC in Debug mode for source-level GDB debugging.
# This script only touches a new build directory; it does not modify the original tarball.

set -e

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_TGZ="$WORK_DIR/MLNX_OFED_SRC-24.10-5.1.6.1/SOURCES/rdma-core_2410mlnx54.orig.tar.gz"
# Build into a directory under $PWD by default.  Keep an eye on the absolute
# path length: IN_PLACE builds embed the build directory into IBACM_SERVER_PATH
# and ACM_CONF_DIR, and paths longer than ~108/128 bytes will fail to compile.
BUILD_ROOT="${BUILD_ROOT:-$WORK_DIR/rdma-core-debug-build}"
SRC_DIR="$BUILD_ROOT/rdma-core-2410mlnx54"
BUILD_DIR="$SRC_DIR/build"

# IN_PLACE builds embed the absolute build path into generated config macros.
# ACM stores config/data paths in fixed 128-byte char arrays, so keep the
# resulting paths short enough to fit.  IBACM_SERVER_PATH is forced to /run
# below, so only the config/data path is checked here.
ACM_DATA_PATH="$BUILD_DIR/etc/rdma/ibacm_route.data"
if [ "${#ACM_DATA_PATH}" -gt 120 ]; then
    echo "ERROR: build path is too long for IN_PLACE build." >&2
    echo "       $ACM_DATA_PATH" >&2
    echo "       length=${#ACM_DATA_PATH}, max ~120 to fit ibacm's 128-byte buffer." >&2
    echo "       Use a shorter BUILD_ROOT, e.g. BUILD_ROOT=/tmp/rdma-core-debug-build" >&2
    exit 1
fi

if [ ! -f "$SRC_TGZ" ]; then
    echo "ERROR: tarball not found: $SRC_TGZ" >&2
    exit 1
fi

# Tool detection
if command -v ninja-build >/dev/null 2>&1; then
    NINJA=ninja-build
elif command -v ninja >/dev/null 2>&1; then
    NINJA=ninja
else
    echo "ERROR: ninja/ninja-build not found. Install ninja-build." >&2
    exit 1
fi

# Install build dependencies (re-run apt to make sure)
# Note: the Debian/Ubuntu package is always named 'ninja-build', while the
# binary may be called 'ninja-build' or 'ninja' depending on the distro.
echo "==> Installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake ninja-build pkg-config \
    libnl-3-dev libnl-route-3-dev libnuma-dev libssl-dev libelf-dev \
    libudev-dev libsystemd-dev systemd dh-python python3-dev python3-docutils \
    pandoc valgrind quilt fakeroot

# Clean and extract
echo "==> Extracting rdma-core source..."
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
tar -xzf "$SRC_TGZ" -C "$BUILD_ROOT"

# Configure & build in Debug mode, in-place
echo "==> Configuring (Debug build)..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake -GNinja \
    -DIN_PLACE=1 \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_STATIC=1 \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
    -DCMAKE_INSTALL_RUNDIR=/run \
    ..

echo "==> Building..."
"$NINJA"

echo ""
echo "Build complete: $BUILD_DIR"
echo "  Shared libraries: $BUILD_DIR/lib"
echo "  Binaries:         $BUILD_DIR/bin"
echo "  Provider config:  $BUILD_DIR/etc/libibverbs.d"
echo ""
echo "Example debug session:"
echo "  cd $BUILD_DIR"
echo "  LD_LIBRARY_PATH=$BUILD_DIR/lib gdb <your_app>"
echo ""
echo "If you want to install the debug packages system-wide instead, see README or use:"
echo "  EXTRA_CMAKE_FLAGS='-DCMAKE_BUILD_TYPE=Debug' DEB_BUILD_OPTIONS='nostrip' sudo -E perl install.pl --user-space-only --all"
