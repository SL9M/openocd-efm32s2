#!/bin/bash
set -e

REPO_URL="https://github.com/loopj/openocd-efm32s2.git"
BUILD_DIR="$PWD/build"
PREFIX="$BUILD_DIR/opt"
DL_DIR="$BUILD_DIR/dl"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$PREFIX" "$DL_DIR"

# Clone OpenOCD fork
git clone --depth=1 "$REPO_URL" "$BUILD_DIR/src"
cd "$BUILD_DIR/src"

# Build dependencies (libusb, hidapi, libjaylink)
build_dep() {
  NAME=$1
  VER=$2
  URL=$3
  CONFIGURE_OPTS=$4

  cd "$DL_DIR"
  wget -q "$URL" -O "$NAME.tar.gz"
  
  DIR=$(tar tzf "$NAME.tar.gz" | head -1 | cut -f1 -d"/")
  tar xzf "$NAME.tar.gz"
  echo "Building $NAME from directory: $DIR"
  cd "$DIR"

  if [[ "$NAME" == libjaylink* ]]; then
    if [[ -f ./bootstrap.sh ]]; then
      ./bootstrap.sh
    else
      autoreconf -i
    fi
    ./configure --prefix="$PREFIX" --enable-static --disable-shared $CONFIGURE_OPTS
    make -j$(nproc)
    make install
  else
    if [[ -x ./bootstrap.sh ]]; then
      ./bootstrap.sh
    elif [[ -x ./bootstrap ]]; then
      ./bootstrap
    fi

    if [[ -x ./configure ]] || [[ -f ./configure ]]; then
      ./configure --prefix="$PREFIX" --enable-static --disable-shared $CONFIGURE_OPTS
    fi

    make -j$(nproc)
    make install
  fi
}

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

build_dep "libusb-1.0.26" "1.0.26" "https://dl.espressif.com/dl/libusb-1.0.26.tar.gz"
build_dep "hidapi-0.14.0" "0.14.0" "https://github.com/libusb/hidapi/archive/refs/tags/hidapi-0.14.0.tar.gz" "--disable-testgui CFLAGS=-std=gnu99"
build_dep "libjaylink-0.3.1" "0.3.1" "https://dl.espressif.com/dl/libjaylink-0.3.1.tar.gz"

# Build OpenOCD
cd "$BUILD_DIR/src"
./bootstrap
./configure --prefix="$PREFIX/openocd" \
  --disable-doxygen-html \
  --enable-remote-bitbang \
  --enable-static --disable-shared
make -j$(nproc)
make install-strip

echo "✅ OpenOCD built successfully at: $PREFIX/openocd/bin/openocd"