#!/bin/bash

set -e
set -x   # 打印每条命令，方便调试

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# FFmpeg 版本
#FFMPEG_VERSION=n6.1.4
FFMPEG_VERSION=n4.4.6
# NDK & Android 配置
#NDK_VERSION=r25b
NDK_VERSION=r27d
ANDROID_NDK_API_LEVEL=29
ANDROID_ABI=arm64-v8a

FFMPEG_DIR=$SCRIPT_DIR/ffmpeg-src/$FFMPEG_VERSION

case "$ANDROID_ABI" in
  arm64-v8a)
    ARCH=aarch64
    CPU=armv8-a
    ;;
  armeabi-v7a)
    ARCH=arm
    CPU=armv7-a
    ;;
  x86)
    ARCH=x86
    CPU=i686
    ;;
  x86_64)
    ARCH=x86_64
    CPU=x86-64
    ;;
esac

# 如果没有源码则自动 clone
if [ ! -d "$FFMPEG_DIR" ]; then
    echo "Cloning FFmpeg $FFMPEG_VERSION ..."
    git clone --depth 1 -v --progress -b $FFMPEG_VERSION https://github.com/FFmpeg/FFmpeg.git "$FFMPEG_DIR"
fi

NDK=/mnt/e/WSL_Data/AndroidSDK/ndk/android-ndk-${NDK_VERSION}
HOST=aarch64-linux-android

TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT=$TOOLCHAIN/sysroot

PREFIX=$SCRIPT_DIR/build/${FFMPEG_VERSION}/android/ndk-${NDK_VERSION}-android-${ANDROID_NDK_API_LEVEL}/$ANDROID_ABI

export CC="$TOOLCHAIN/bin/${HOST}${ANDROID_NDK_API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${HOST}${ANDROID_NDK_API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export LD="$TOOLCHAIN/bin/ld"

# 静态 libc++（关键）
export CFLAGS="-fPIC -DANDROID"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-static-libstdc++ -fPIC"
export EXTRA_ASFLAGS="-fPIC"

# ---- 配置选项 ----
CONFIG_ARGS=(
  # 基础组件
  --enable-avutil
  --enable-avcodec
  --enable-avformat
  --enable-swresample
  --enable-swscale
  # 汇编
  #--disable-hardcoded-tables
  --enable-optimizations
  --disable-asm
  # 禁用不必要模块，减小体积
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
  # 必须启用的协议和解析器
  --enable-protocol=file
  --enable-protocol=pipe
  --enable-protocol=fd
  --enable-decoder=aac,aac_latm,mp3,flac,vorbis,opus,alac,ac3,eac3,dca,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s32le,pcm_f32le,pcm_f64le,pcm_alaw,pcm_mulaw,h264,hevc,vp8,vp9,av1,mpeg4,mpegvideo,mjpeg,rawvideo
  --enable-parser=aac,aac_latm,mpegaudio,ac3,dca,h264,hevc,av1,mpeg4video,mpegvideo,vp8,vp9,mjpeg
  --enable-muxer=mp4
)

cd "$FFMPEG_DIR"

# 清理旧编译，确保 -fPIC 生效
make distclean || true
rm -rf "$PREFIX"

# 配置
./configure \
   --enable-cross-compile \
  --arch=$ARCH \
  --cpu=$CPU \
  --target-os=android \
  --enable-static \
  --disable-shared \
  --enable-pic \
  --sysroot=$SYSROOT \
  --cc=$CC \
  --cxx=$CXX \
  --prefix="$PREFIX" \
  --extra-cflags="$CFLAGS" \
  --extra-cxxflags="$CXXFLAGS" \
  --extra-ldflags="$LDFLAGS" \
  "${CONFIG_ARGS[@]}"

# 编译安装
make -j$(nproc)
make install

echo "FFmpeg Android ARM64 static build finished!"
echo "Install path: $PREFIX"
