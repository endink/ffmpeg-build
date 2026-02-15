#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ------------------------------
# 配置 FFmpeg 版本和源码路径
# ------------------------------
FFMPEG_VERSION=${FFMPEG_VERSION:-4.4.6}
FFMPEG_DIR="$SCRIPT_DIR/ffmpeg-src/$FFMPEG_VERSION"

export ANDROID_HOME_DIR=${ANDROID_HOME:-/mnt/e/WSL_Data/AndroidSDK}


# ------------------------------
# NDK & Android 配置
# ------------------------------
export ANDROID_NDK_VERSION=${1:-r27d}              # 第一个参数：NDK 版本
BUILD_TYPE=${2:-static}             # 第二个参数：static 或 shared
export ANDROID_API_LEVEL=${3:-29}                  # 第三个参数：默认 API 级别

export ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-${ANDROID_HOME_DIR}/ndk/android-ndk-${ANDROID_NDK_VERSION}}
export ANDROID_TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
export ANDROID_SYSROOT=$ANDROID_TOOLCHAIN/sysroot

echo "Android NDK: $ANDROID_NDK_ROOT"

# ------------------------------
# 安装路径
# ------------------------------
INSTALL_DIR=${INSTALL_DIR:-$SCRIPT_DIR/build/${FFMPEG_VERSION}/android/ndk-${ANDROID_NDK_VERSION}-android-${ANDROID_API_LEVEL}}

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
CONFIG_ARGS="
--enable-zlib \
--enable-bzlib \
--enable-lzma \
--disable-autodetect \
--disable-pthreads \
--disable-w32threads \
--disable-os2threads \
--disable-protocols \
--enable-protocol=file,fd
"

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


function build_deps() {

 cd "$SCRIPT_DIR"
 set +e

 BZIP_DIR="$DEPS_SOURCE_ROOT/bzip2"
 ZLIB_DIR="$DEPS_SOURCE_ROOT/zlib"
 LZMA_DIR="$DEPS_SOURCE_ROOT/lzma"
 
  CFLAGS="-std=c11 -Wall -Winline -fPIC -DANDROID -ffunction-sections -fdata-sections --sysroot=$ANDROID_SYSROOT -isystem $ANDROID_SYSROOT/usr/include/$ANDROID_HOST"
  
  #refer: https://sourceware.org/git/?p=bzip2.git;a=blob;f=Makefile;h=f8a17722e1c30b4e14fba52543e24f27bf6470bc;hb=6a8690fc8d26c815e798c588f796eabe9d684cf0
  ./build_deps.sh \
    "libbz2.a" \
    https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz \
    "make" \
    "$BZIP_DIR" \
    "libbz2.a" \
    "AR=$AR" \
    "CC=$CC" \
    "CFLAGS=$CFLAGS" \
    "LDFLAGS=-static-libstdc++ -fPIC" \
    "PREFIX=$DEPS_INSTALL_DIR" 
  
  ret=$?
  if [ $ret -ne 0 ] && [ $ret -ne 100 ]; then
    exit 1
  fi
 
 # ./build_deps.sh \
 #  "libz.a" \
 #  https://github.com/madler/zlib/archive/refs/tags/v1.3.1.2.tar.gz \
 #  "cmake" \
 #  "$ZLIB_DIR" \
 #  -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_TESTING=OFF || exit 1
  
  ./build_deps.sh \
  "liblzma.a" \
  https://github.com/tukaani-project/xz/releases/download/v5.8.2/xz-5.8.2.tar.gz \
  "cmake" \
  "$LZMA_DIR" \
  -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_XZ=OFF -DXZ_DOC=OFF 
  
  ret=$?
  if [ $ret -ne 0 ] && [ $ret -ne 100 ]; then
    exit 1
  fi
  set -e
}

ORIGIN_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"

# ------------------------------
# 循环构建每个 ABI
# ------------------------------
for ANDROID_ABI in "${ABIS[@]}"; do
    case "$ANDROID_ABI" in

        arm64-v8a)
            ARCH=aarch64
            CPU=armv8-a
            HOST=aarch64-linux-android
            ;;

        armeabi-v7a)
            ARCH=arm
            CPU=armv7-a
            HOST=armv7a-linux-androideabi
            ;;

        x86)
            ARCH=x86
            CPU=i686
            HOST=i686-linux-android
            ;;

        x86_64)
            ARCH=x86_64
            CPU=x86-64
            HOST=x86_64-linux-android
            ;;

        *)
            echo "Unsupported ABI: $ANDROID_ABI"
            exit 1
            ;;

    esac


    export ANDROID_ABI="$ANDROID_ABI"
    LIBDIR="$INSTALL_DIR/lib/$ANDROID_ABI"

    export ANDROID_HOST="${HOST}"
    export CC="$ANDROID_TOOLCHAIN/bin/${HOST}${ANDROID_API_LEVEL}-clang"
    export CXX="$ANDROID_TOOLCHAIN/bin/${HOST}${ANDROID_API_LEVEL}-clang++"
    export AR="$ANDROID_TOOLCHAIN/bin/llvm-ar"
    export STRIP="$ANDROID_TOOLCHAIN/bin/llvm-strip"
    export LD="$CC"
    export RANLIB="$ANDROID_TOOLCHAIN/bin/llvm-ranlib"
    
    
    export DEPS_INSTALL_DIR="$SCRIPT_DIR/build/_deps_install/android-${ANDROID_API_LEVEL}-ndk-${ANDROID_NDK_VERSION}/${ANDROID_ABI}"
    export DEPS_SOURCE_ROOT="$SCRIPT_DIR/build/_deps"
    
    PKG_DIR="${DEPS_INSTALL_DIR}/lib/pkgconfig"
    export PKG_CONFIG_PATH="${PKG_DIR}:${ORIGIN_PKG_CONFIG_PATH}"
    
    build_deps
    
    echo "Depedencies build successful !"

    CFLAGS="-fPIC -DANDROID -ffunction-sections -fdata-sections -I${DEPS_INSTALL_DIR}/include -DLZMA_API_STATIC"
    if [ "$BUILD_TYPE" == "shared" ]; then
        CFLAGS="$CFLAGS -Os"
    fi
    
    LDFLAGS="-static-libstdc++ -fPIC -L${DEPS_INSTALL_DIR}/lib"
    if [ "$BUILD_TYPE" == "shared" ]; then
        LDFLAGS="$LDFLAGS -Wl,--gc-sections"
    fi
    
    # export LDFLAGS="$LDFLAGS"
    # export CXXFLAGS="CXXFLAGS"
    
   

    BUILD_DIR="${FFMPEG_DIR}/build/android/ndk-${ANDROID_NDK_VERSION}-android-${ANDROID_API_LEVEL}/$ANDROID_ABI"
    if [ -d "$BUILD_DIR" ];then
        echo "Clean build ...."
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    FINAL_ARGS="$("${SCRIPT_DIR}/get_options.sh" "$CONFIG_ARGS")"

    echo -e "\nFFmpeg Configuration: "
    echo "$FINAL_ARGS" | tr ' ' '\n'
    
    echo -e "\nconfigure log: $BUILD_DIR/ffbuild/config.log"
    echo -e "Please wait ...\n"



    # 配置
    "$FFMPEG_DIR/configure" \
        --enable-zlib \
        --enable-bzlib \
        --enable-lzma \
        --enable-cross-compile \
        --arch=$ARCH \
        --cpu=$CPU \
        --target-os=android \
        --sysroot="$ANDROID_SYSROOT" \
        --cc=$CC \
        --cxx=$CXX \
        --strip=$STRIP \
        --prefix="$INSTALL_DIR" \
        --incdir="$INSTALL_DIR/include" \
        --libdir="$LIBDIR" \
        --shlibdir="$LIBDIR" \
        --extra-cflags="${CFLAGS}" \
        --extra-cxxflags="${CFLAGS}" \
        --extra-ldflags="${LDFLAGS}" \
        ${FINAL_ARGS}
    
    
    clean_dir "$LIBDIR"
    clean_dir "$INSTALL_DIR/include"

    make -j$(nproc)
    make install
    
    if [ "$BUILD_TYPE" == "static" ];then
        rsync -av --ignore-existing "${DEPS_INSTALL_DIR}/include/" "${INSTALL_DIR}/include"
        rsync -av --ignore-existing "${DEPS_INSTALL_DIR}/lib/" "$LIBDIR"
    fi

    echo "------------------------------------------"
    echo "FFmpeg build for $ANDROID_ABI (API $ANDROID_API_LEVEL, $BUILD_TYPE) finished:"
    echo "  include: $INSTALL_DIR/include"
    echo "  lib    : $LIBDIR"
    echo "------------------------------------------"
done

echo "All builds finished!"