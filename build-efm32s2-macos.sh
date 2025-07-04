#!/bin/bash
set -euo pipefail

# Config 
OPENOCD_REPO_URL="https://github.com/loopj/openocd-efm32s2.git"
OPENOCD_BRANCH="efm32s2"
SRC_DIR="$(pwd)/openocd-src"
BUILD_DIR="$(pwd)/build"
PREFIX="$BUILD_DIR/openocd"
DEPENDENCIES=(libusb hidapi)

# Ensure Homebrew dependencies
echo "Installing Homebrew dependencies..."
for pkg in "${DEPENDENCIES[@]}"; do
    if ! brew list --versions "$pkg" >/dev/null; then
        echo "Installing $pkg..."
        brew install "$pkg"
    else
        echo "$pkg already installed."
    fi
done

# Environment setup
BREW_PREFIX="$(brew --prefix)"
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig"
export CPPFLAGS="-I$BREW_PREFIX/include"
export LDFLAGS="-L$BREW_PREFIX/lib"

# Clone OpenOCD repo
echo "Cloning OpenOCD EFM32S2 fork..."
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$OPENOCD_BRANCH" "$OPENOCD_REPO_URL" "$SRC_DIR"

# Clean and prepare build dir
echo "Cleaning old build..."
rm -rf "$BUILD_DIR"
mkdir -p "$PREFIX"

# Build OpenOCD
echo "Building OpenOCD..."
cd "$SRC_DIR"
./bootstrap
./configure --prefix="$PREFIX" --disable-doxygen-html --enable-remote-bitbang
make -j"$(sysctl -n hw.ncpu)"
make install-strip

# Bundle dylibs
echo "Bundling shared libraries..."
BIN="$PREFIX/bin/openocd"
LIB_DIR="$PREFIX/lib"
mkdir -p "$LIB_DIR"

USED_DYLIBS=$(otool -L "$BIN" | awk '{print $1}' | grep -v "^/usr/lib" | grep "\.dylib" || true)

for dylib in $USED_DYLIBS; do
    libname=$(basename "$dylib")
    cp "$dylib" "$LIB_DIR/"
    chmod 644 "$LIB_DIR/$libname"
    echo "Patching $libname in binary"
    install_name_tool -change "$dylib" "@executable_path/../lib/$libname" "$BIN"
done

# Success
echo ""
echo "✅ Done! OpenOCD EFM32S2 is built"
echo "Location: $PREFIX"
echo "Run it like: $PREFIX/bin/openocd"
