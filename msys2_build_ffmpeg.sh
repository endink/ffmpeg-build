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
    export DEPS_INSTALL_DIR="$FFMPEG_SRC/_deps_install"
else
    STATIC_FLAGS="--enable-static --disable-shared"
    export DEPS_INSTALL_DIR="$INSTALL_DIR"
fi

echo "Src dir: $FFMPEG_SRC"
echo "Build type: $BUILD_TYPE"
echo "Flags: $STATIC_FLAGS"
echo

pacman -S --needed --noconfirm make automake pkg-config nasm yasm autoconf libtool coreutils

nasm -v


echo "VC_EXE_PATH: $VC_EXE_PATH"


echo "Build dependencies ..."

export SOURCE_ROOT="$SCRIPT_DIR/build/_deps"

if [ ! -z "$INSTALL_DIR" ];then
   export INSTALL_DIR=$(cygpath -u "$INSTALL_DIR")
else
   export INSTALL_DIR="${SCRIPT_DIR}/build/win64/$FFMPEG_VERSION"
fi


echo "Dependency Install DIR: $INSTALL_DIR"

function build_deps() {

 BZIP_DIR="$SOURCE_ROOT/bzip2"
 ZLIB_DIR="$SOURCE_ROOT/zlib"
 LZMA_DIR="$SOURCE_ROOT/lzma"
 
 
 ./msys2_build_ffmpeg.sh https://sourceware.org/pub/bzip2/bzip2-1.0.1.tar.gz "nmake" "$BZIP_DIR" || exit 1
 
 install -Dm644 "$BZIP_DIR/libbz2.lib" "$DEPS_INSTALL_DIR/lib/bz2.lib"
 install -Dm644 "$BZIP_DIR/bzlib.h"   "$DEPS_INSTALL_DIR/include/bzlib.h"
 
 
 ./msys2_build_ffmpeg.sh https://github.com/madler/zlib/archive/refs/tags/v1.3.1.2.tar.gz \
  "cmake" \
  "$ZLIB_DIR" \
  "-DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_TESTING=OFF" || exit 1
  mv -f "$DEPS_INSTALL_DIR/lib/zs.lib" "$DEPS_INSTALL_DIR/lib/zlib.lib"
  
  ./msys2_build_ffmpeg.sh https://github.com/tukaani-project/xz/releases/download/v5.8.2/xz-5.8.2.tar.gz \
  "cmake" \
  "$LZMA_DIR" \
  "-DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_XZ=OFF -DXZ_DOC=OFF -Dzlib_static_suffix=lib" || exit 1
}

build_deps


PGOPTIONS="
--enable-version3 \
--enable-zlib \
--enable-bzlib \
--enable-lzma \
\
--disable-ffplay \
--disable-sdl2 \
--disable-opengl \
--disable-vulkan \
--disable-ffnvcodec \
--disable-cuda \
--disable-amf \
--disable-libbluray \
--disable-libxml2 \
--disable-libmodplug \
--disable-libtheora \
--disable-libvorbis \
--disable-libopus \
--disable-libilbc \
\
--disable-vaapi \
--enable-w32threads \
--disable-avfilter \
--disable-postproc \
--enable-avutil \
--enable-avcodec \
--enable-avformat \
--enable-swresample \
--enable-swscale \
\
--disable-avdevice \
--disable-programs \
--disable-doc \
--disable-debug \
--disable-network \
--disable-devices \
--disable-encoders \
\
--disable-decoders \
--enable-decoder=rawvideo \
--enable-decoder=aac \
--enable-decoder=mp3 \
--enable-decoder=flac \
--enable-decoder=alac \
--enable-decoder=ac3 \
--enable-decoder=eac3 \
--enable-decoder=dca \
--enable-decoder=vorbis \
--enable-decoder=pcm_s16le \
--enable-decoder=pcm_s16be \
--enable-decoder=pcm_s24le \
--enable-decoder=pcm_s32le \
--enable-decoder=pcm_f32le \
--enable-decoder=h264 \
--enable-decoder=hevc \
--enable-decoder=vp7 \
--enable-decoder=vp8 \
--enable-decoder=vp9 \
--enable-decoder=av1 \
--enable-decoder=mjpeg \
\
--disable-parsers \
--enable-parser=aac \
--enable-parser=aac_latm \
--enable-parser=mpegaudio \
--enable-parser=flac \
--enable-parser=ac3 \
--enable-parser=dca \
--enable-parser=h264 \
--enable-parser=hevc \
--enable-parser=vp8 \
--enable-parser=vp9 \
--enable-parser=mjpeg \
--enable-parser=av1 \
\
--enable-hardcoded-tables \
\
--disable-protocols \
--enable-protocol=file \
\
--disable-muxers \
--enable-muxer=mp4
"


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

mkdir -p build
cd build


echo -e "\n=== Configure FFmpeg (MSVC) ==="

../configure \
    --toolchain=msvc \
    --arch=x86_64 \
    --target-os=win64 \
    $PGOPTIONS \
    $STATIC_FLAGS \
    --extra-cflags="${MSVC_CFLAGS}" \
    --extra-cxxflags="${MSVC_CFLAGS}" \
    --extra-ldflags="${MSVC_LDFLAGS}" \
    --prefix="$INSTALL_DIR_WIN" 
    

echo "=== Build ==="

make -j$(nproc)

echo "=== Install ==="
make install


mkdir -p "${INSTALL_DIR}/lib"

if [ -d "${INSTALL_DIR}/bin/" ];then
   cd "${INSTALL_DIR}/bin"
   mv -f *.lib "${INSTALL_DIR}/lib/" 2>/dev/null
fi

ls -l "${INSTALL_DIR}/lib"

echo "=== Done ==="

exit 0