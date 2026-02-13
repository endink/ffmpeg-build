#!/bin/bash
set -e
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ------------------------------
# 配置 FFmpeg 版本和源码路径
# ------------------------------
FFMPEG_VERSION=${FFMPEG_VERSION:-4.4.6}
FFMPEG_DIR="$SCRIPT_DIR/ffmpeg-src/$FFMPEG_VERSION"

ANDROID_HOME_DIR=${ANDROID_HOME:-/mnt/e/WSL_Data/AndroidSDK}

# ------------------------------
# NDK & Android 配置
# ------------------------------
NDK_VERSION=${1:-r27d}              # 第一个参数：NDK 版本
BUILD_TYPE=${2:-static}             # 第二个参数：static 或 shared
API_LEVEL=${3:-29}                  # 第三个参数：默认 API 级别

NDK_ROOT=${ANDROID_HOME_DIR}/ndk/android-ndk-${NDK_VERSION}
TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT=$TOOLCHAIN/sysroot

# ------------------------------
# 安装路径
# ------------------------------
INSTALL_DIR=${INSTALL_DIR:-$SCRIPT_DIR/build/${FFMPEG_VERSION}/android/ndk-${NDK_VERSION}-android-${API_LEVEL}}

# ------------------------------
# 多 ABI 支持
# ------------------------------
if [ "$CI" == "true" ]; then
    ABIS=("armeabi-v7a" "arm64-v8a")
else
    ABIS=("arm64-v8a")
fi

# ------------------------------
# 根据 BUILD_TYPE 设置 configure 标志
# ------------------------------
if [ "$BUILD_TYPE" == "static" ]; then
    BUILD_FLAG="--enable-static --disable-shared"
elif [ "$BUILD_TYPE" == "shared" ]; then
    BUILD_FLAG="--disable-static --enable-shared"
else
    echo "Unknown BUILD_TYPE: $BUILD_TYPE. Must be 'static' or 'shared'."
    exit 1
fi

# ------------------------------
# FFmpeg configure 参数
# ------------------------------
CONFIG_ARGS=(
  --enable-avutil
  --enable-avcodec
  --enable-avformat
  --enable-swresample
  --enable-swscale
  --enable-optimizations
  --disable-programs
  --disable-doc
  --disable-debug
  --disable-ffplay
  --disable-ffprobe
  --disable-avdevice
  --disable-network
  --disable-postproc
  --disable-avfilter
  --disable-bsfs
  --disable-encoders
  --disable-decoders
  --disable-parsers
  --disable-muxers
  --disable-demuxers
  --disable-pthreads
  --disable-w32threads
  --disable-os2threads
  --disable-sdl2
  --disable-opengl
  --disable-vulkan
  --disable-ffnvcodec
  --disable-cuda
  --disable-amf
  --disable-libbluray
  --disable-libxml2
  --disable-libmodplug
  --disable-libtheora
  --disable-libvorbis
  --disable-libopus
  --disable-libilbc
  --disable-xlib
  --disable-zlib
  --disable-autodetect
  --enable-demuxers
  --enable-protocol=file
  --enable-protocol=pipe
  --enable-protocol=fd
  --enable-decoder=aac,aac_latm,mp3,flac,vorbis,opus,alac,ac3,eac3,dca,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s32le,pcm_f32le,pcm_f64le,pcm_alaw,pcm_mulaw,h264,hevc,vp8,vp9,av1,mpeg4,mpegvideo,mjpeg,rawvideo
  --enable-parser=aac,aac_latm,mpegaudio,ac3,dca,h264,hevc,av1,mpeg4video,mpegvideo,vp8,vp9,mjpeg
  --enable-muxer=mp4
)

# ------------------------------
# 循环构建每个 ABI
# ------------------------------
for ANDROID_ABI in "${ABIS[@]}"; do
    case "$ANDROID_ABI" in
        arm64-v8a) ARCH=aarch64; CPU=armv8-a ;;
        armeabi-v7a) ARCH=arm; CPU=armv7-a ;;
        x86) ARCH=x86; CPU=i686 ;;
        x86_64) ARCH=x86_64; CPU=x86-64 ;;
    esac

    HOST=${ARCH}-linux-android
    LIBDIR="$INSTALL_DIR/lib/$ANDROID_ABI"

    export CC="$TOOLCHAIN/bin/${HOST}${API_LEVEL}-clang"
    export CXX="$TOOLCHAIN/bin/${HOST}${API_LEVEL}-clang++"
    export AR="$TOOLCHAIN/bin/llvm-ar"
    export STRIP="$TOOLCHAIN/bin/llvm-strip"
    export LD="$TOOLCHAIN/bin/ld"

    export CFLAGS="-fPIC -DANDROID"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-static-libstdc++ -fPIC"

    # 创建 ABI 目录
    mkdir -p "$LIBDIR"
    mkdir -p "$INSTALL_DIR/include"

    cd "$FFMPEG_DIR"

    # 清理旧编译
    make distclean || true
    rm -rf "$LIBDIR"

    # 配置
    ./configure \
        --enable-cross-compile \
        --arch=$ARCH \
        --cpu=$CPU \
        --target-os=android \
        $BUILD_FLAG \
        --enable-pic \
        --sysroot=$SYSROOT \
        --cc=$CC \
        --cxx=$CXX \
        --prefix="$INSTALL_DIR" \
        --includedir="$INSTALL_DIR/include" \
        --libdir="$LIBDIR" \
        --extra-cflags="$CFLAGS" \
        --extra-cxxflags="$CXXFLAGS" \
        --extra-ldflags="$LDFLAGS" \
        "${CONFIG_ARGS[@]}"

    make -j$(nproc)
    make install

    echo "------------------------------------------"
    echo "FFmpeg build for $ANDROID_ABI (API $API_LEVEL, $BUILD_TYPE) finished:"
    echo "  include: $INSTALL_DIR/include"
    echo "  lib    : $LIBDIR"
    echo "------------------------------------------"
done

echo "All builds finished!"