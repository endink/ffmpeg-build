#!/usr/bin/env bash
set -e

FFMPEG_SRC="$1" # ffmepg source code dir
BUILD_TYPE="$2" # shared / static
FFMPEG_VERSION="$3" # ffmpeg version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$FFMPEG_SRC" ]; then
    echo "Usage: $0 <ffmpeg_source_dir>"
    exit 1
fi

if [ ! -d "$FFMPEG_SRC" ]; then
    echo "Error: '$FFMPEG_SRC' is not a directory."
    exit 1
fi

if [ ! -f "$FFMPEG_SRC/configure" ]; then
    echo "Error: '$FFMPEG_SRC' does not look like an FFmpeg source directory."
    exit 1
fi

if [ -z "$BUILD_TYPE" ]; then
    BUILD_TYPE="static"
fi

if [ "$BUILD_TYPE" = "shared" ]; then
    STATIC_FLAGS="--disable-static --enable-shared"
else
    STATIC_FLAGS="--enable-static --disable-shared"
fi

echo "Src dir: $FFMPEG_SRC"
echo "Build type: $BUILD_TYPE"
echo "Flags: $STATIC_FLAGS"
echo

pacman -S --needed --noconfirm make automake pkg-config nasm yasm autoconf libtool coreutils rsync

nasm -v


echo "VC_EXE_PATH: $VC_EXE_PATH"

clean_dir() {
    local dir="$1"

    if [ -z "$dir" ]; then
        echo "clean_dir: directory path is empty!"
        return 1
    fi

    if [ ! -d "$dir" ]; then
        echo "clean_dir: directory '$dir' does not exist, creating..."
        mkdir -p "$dir"
    fi

    echo "Cleaning folder: $dir"
    rm -rf "$dir"/*
}


echo "Build dependencies ..."


if [ ! -z "$INSTALL_DIR" ];then
   export INSTALL_DIR=$(cygpath -u "$INSTALL_DIR")
else
   export INSTALL_DIR="${SCRIPT_DIR}/build/win64/$FFMPEG_VERSION"
fi


echo "Dependency Install DIR: $INSTALL_DIR"

function build_deps() {

 set +e
 BZIP_DIR="$DEPS_SOURCE_ROOT/bzip2"
 ZLIB_DIR="$DEPS_SOURCE_ROOT/zlib"
 LZMA_DIR="$DEPS_SOURCE_ROOT/lzma"
 
 
 
 
 ./build_deps.sh "bz2.lib" https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz "nmake" "$BZIP_DIR"
 ret=$?
 if [ $ret -eq 0 ]; then
     install -Dm644 "$BZIP_DIR/libbz2.lib" "$DEPS_INSTALL_DIR/lib/bz2.lib"
     install -Dm644 "$BZIP_DIR/bzlib.h"   "$DEPS_INSTALL_DIR/include/bzlib.h"
 elif [ $ret -ne 0 ] && [ $ret -ne 100 ]; then
    exit 1
 fi
 
 
 ./build_deps.sh "zlib.lib" https://github.com/madler/zlib/archive/refs/tags/v1.3.1.2.tar.gz \
  "cmake" \
  "$ZLIB_DIR" \
  -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_TESTING=OFF -Dzlib_static_suffix=lib
  
  ret=$?
  ls -l "${DEPS_INSTALL_DIR}/lib/"
  if [ $ret -eq 0 ];then
    mv "${DEPS_INSTALL_DIR}/lib/zs.lib" "${DEPS_INSTALL_DIR}/lib/zlib.lib"
  elif [ $ret -ne 0 ] && [ $ret -ne 100 ]; then
    exit 1
  fi
  
  ./build_deps.sh "lzma.lib" https://github.com/tukaani-project/xz/releases/download/v5.8.2/xz-5.8.2.tar.gz \
  "cmake" \
  "$LZMA_DIR" \
  -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_XZ=OFF -DXZ_DOC=OFF
  
  ret=$?
  if [ $ret -ne 0 ] && [ $ret -ne 100 ]; then
    exit 1
  fi
  
  set -e
  
}


export DEPS_SOURCE_ROOT="$SCRIPT_DIR/build/_deps"
export DEPS_INSTALL_DIR="$SCRIPT_DIR/build/_deps_install/win64"

build_deps


merge_options() {
    first="$1"
    second="$2"

    tmp_file=$(mktemp)

    printf '%s\n' "$first" "$second" \
    | tr ' ' '\n' \
    | while IFS= read -r opt; do
        [ -z "$opt" ] && continue

        case "$opt" in
            *=*) key=${opt%%=*} ;;
            *)   key=$opt ;;
        esac

        sed -i "/^$key=/d" "$tmp_file" 2>/dev/null
        sed -i "/^$key$/d" "$tmp_file" 2>/dev/null

        echo "$opt" >> "$tmp_file"
    done

    result=$(paste -sd' ' "$tmp_file")
    rm -f "$tmp_file"

    echo "$result"
}


export MSYS2_ARG_CONV_EXCL="/utf-8;/O2;/MD"
    
MSVC_CFLAGS="/utf-8 /O2 /MD -DLZMA_API_STATIC"
MSVC_LDFLAGS="/OPT:REF /OPT:ICF"


INSTALL_DIR_WIN=$(cygpath -m "${INSTALL_DIR}")
LIB_DIR=$(cygpath -w "${DEPS_INSTALL_DIR}/lib")
INCLUDE_DIR=$(cygpath -w "${DEPS_INSTALL_DIR}/include")


PKG_DIR=$(cygpath -w "${DEPS_INSTALL_DIR}/lib/pkgconfig")


export PKG_CONFIG_PATH="${PKG_DIR}"

echo "Test libs..."
echo ""

pkg-config --libs --cflags zlib

echo ""
echo "Test Donw"

cd "$FFMPEG_SRC"

echo "INSTALL DIR: $INSTALL_DIR_WIN"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

export LIB="$LIB_DIR;$LIB"
export INCLUDE="$INCLUDE_DIR;$INCLUDE"


BUILD_DIR="$FFMPEG_SRC/build/win64"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"


echo -e "\n=== Configure FFmpeg (MSVC) ==="

CONFIG_ARGS="
--enable-version3 \
--enable-zlib \
--enable-bzlib \
--enable-lzma \
--disable-protocols \
--enable-protocol=file \
"

FINAL_ARGS="$("${SCRIPT_DIR}/get_options.sh" "$CONFIG_ARGS")"

echo "$FINAL_ARGS" | tr ' ' '\n'



echo -e "\nconfigure log: $BUILD_DIR/ffbuild/config.log"
echo -e "Please wait ...\n"

"$FFMPEG_SRC/configure" \
    --toolchain=msvc \
    --arch=x86_64 \
    --target-os=win64 \
    $FINAL_ARGS \
    $STATIC_FLAGS \
    --extra-cflags="${MSVC_CFLAGS}" \
    --extra-cxxflags="${MSVC_CFLAGS}" \
    --extra-ldflags="${MSVC_LDFLAGS}" \
    --prefix="$INSTALL_DIR_WIN" 
    

echo "=== Build ==="

clean_dir "$INSTALL_DIR"


make -j$(nproc)

echo "=== Install ==="
make install


mkdir -p "${INSTALL_DIR}/lib"

if [ -d "${INSTALL_DIR}/bin/" ];then
   cd "${INSTALL_DIR}/bin"
   mv -f *.lib "${INSTALL_DIR}/lib/" 2>/dev/null
fi

if [ "$BUILD_TYPE" == "static" ];then
    rsync -av --ignore-existing "${DEPS_INSTALL_DIR}/" "${INSTALL_DIR}/"
fi

ls -l "${INSTALL_DIR}/lib"

echo "=== Done ==="

exit 0