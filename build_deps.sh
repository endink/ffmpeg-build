#!/usr/bin/env bash
set -e

# ========================================
# 参数检查
# ========================================
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage:"
    echo "  $0 <lib file name> <url> <cmake|make|nmake> <src_dir> [<build_args>...]"
    exit 1
fi

# 前三个参数固定
LIB_FILE_NAME="$1"
URL="$2"
BUILD_SYSTEM="$3"
SRC_DIR_NAME="$4"
shift 4  # 剩余参数都是 BUILD_ARGS，可选

# BUILD_ARGS 可为空，也可以是单个字符串或多个参数
if [ $# -gt 0 ]; then
    BUILD_ARGS=("$@")
else
    BUILD_ARGS=()
fi

# ========================================
# 目录定义
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT=${DEPS_SOURCE_ROOT:-"${SCRIPT_DIR}/build/_deps"}
DOWNLOAD_DIR="$SOURCE_ROOT/download"
BUILD_DIR="$SRC_DIR_NAME/build"
INSTALL_DIR=${DEPS_INSTALL_DIR:-"$SOURCE_ROOT/install"}
LIB_FILE_PATH="${INSTALL_DIR}/lib/$LIB_FILE_NAME"

if [ -f "$LIB_FILE_PATH" ];then
 echo "Skip build $LIB_FILE_NAME"
 exit 100
fi

# ------------------------------
# Android 检查
# ------------------------------
if [ ! -z "$ANDROID_API_LEVEL" ] && [ -d "$ANDROID_NDK_ROOT" ] && [ ! -z "$ANDROID_ABI" ] && [ ! -z "$ANDROID_SYSROOT" ] && [ ! -z "$ANDROID_NDK_VERSION" ]
then
    BUILD_PLATFORM="android"
    BUILD_DIR="$BUILD_DIR/android-${ANDROID_API_LEVEL}-ndk-${ANDROID_NDK_VERSION}/${ANDROID_ABI}"
fi

if [ -n "$MSYSTEM" ]; then
    BUILD_PLATFORM="msys2"
    BUILD_DIR="$BUILD_DIR/msys2"
fi


mkdir -p "$DOWNLOAD_DIR"

SRC_DIR="$SRC_DIR_NAME"

FILENAME="$(basename "$URL")"
FILE_PREFIX="${LIB_FILE_NAME%.*}"
ARCHIVE_PATH="$DOWNLOAD_DIR/${FILE_PREFIX}_${FILENAME}"

echo
echo "==============================="
echo "Dependenc Building: $FILENAME"
echo ""
echo "Platform:       $BUILD_PLATFORM"
echo "URL:            $URL"
echo "Archive:        $ARCHIVE_PATH"
echo "BuildSystem:    $BUILD_SYSTEM"
echo "Source Dir:     $SRC_DIR"
echo "Build Args:     ${BUILD_ARGS[*]}"
echo "==============================="
echo

# 保存 MSYS2_ARG_CONV_EXCL 以便还原
OLD_MSYS2_ARG_CONV_EXCL="$MSYS2_ARG_CONV_EXCL"

# ========================================
# 统一退出函数
# ========================================
function on_exit() {
    local code=$?
    export MSYS2_ARG_CONV_EXCL="$OLD_MSYS2_ARG_CONV_EXCL"
    
    if [ $code -ne 0 ]; then
        echo "--------------------------------"
        echo "Build failed !!"
        echo "--------------------------------"
    fi
}

trap on_exit EXIT

# ========================================
# 如果源码目录不存在才下载和解压
# ========================================
if [ ! -d "$SRC_DIR" ]; then

    echo "Source directory not found. Preparing source..."

    # ---------- 下载 ----------
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo "Downloading..."
        curl -L "$URL" -o "$ARCHIVE_PATH"
    else
        echo "Archive already exists. Skip download."
    fi

    echo "Extracting to $SRC_DIR..."
    mkdir -p "$SRC_DIR"

    case "$FILENAME" in
        *.tar.gz|*.tgz)
            tar -xzf "$ARCHIVE_PATH" --strip-components=1 -C "$SRC_DIR"
            ;;
        *.tar.bz2)
            tar -xjf "$ARCHIVE_PATH" --strip-components=1 -C "$SRC_DIR"
            ;;
        *.tar.xz)
            tar -xJf "$ARCHIVE_PATH" --strip-components=1 -C "$SRC_DIR"
            ;;
        *.zip)
            TMP_DIR="$DOWNLOAD_DIR/__tmp_extract"
            rm -rf "$TMP_DIR"
            mkdir -p "$TMP_DIR"
            unzip -q "$ARCHIVE_PATH" -d "$TMP_DIR"
            FIRST_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
            if [ -z "$FIRST_DIR" ]; then
                echo "Zip structure unexpected."
                exit 1
            fi
            mv "$FIRST_DIR"/* "$SRC_DIR"
            rm -rf "$TMP_DIR"
            ;;
        *)
            echo "Unsupported archive format: $FILENAME"
            rm -rf $SRC_DIR
            exit 1
            ;;
    esac

else
    echo "Source directory already exists. Skip download & extract."
fi

cd "$SRC_DIR"



echo "INSTALL: ${INSTALL_DIR}"

mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/include"

# ========================================
# 构建平台参数
# ========================================
case "$BUILD_PLATFORM" in
    android)
        PLATFORM_CMAKE_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"
            -DANDROID_ABI="${ANDROID_ABI}"
            -DANDROID_STL="c++_static"
            -DANDROID_PLATFORM="android-${ANDROID_API_LEVEL}"
        )
        PLATFORM_CFLAGS="-fPIC -DANDROID -ffunction-sections -fdata-sections"
        ;;
    msys2)
        INSTALL_DIR=$(cygpath -w "$INSTALL_DIR")
        SRC_DIR=$(cygpath -w "$SRC_DIR")
        BUILD_DIR=$(cygpath -w "$BUILD_DIR")
        PLATFORM_CMAKE_ARGS=(-G "Ninja")
        PLATFORM_CFLAGS="/utf-8 /O2 /MD"
        ;;
    *)
        echo "Unknown platform !!"
        ;;
esac

export MSYS2_ARG_CONV_EXCL="*"

# ========================================
# 构建逻辑
# ========================================
if [ "$BUILD_SYSTEM" = "cmake" ]; then

    mkdir -p "$BUILD_DIR"

    echo "Configuring (CMake)..."
   
    cmake \
        -S "$SRC_DIR" \
        -B "$BUILD_DIR" \
        "${PLATFORM_CMAKE_ARGS[@]}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL \
        -DCMAKE_C_FLAGS="$PLATFORM_CFLAGS" \
        -DCMAKE_CXX_FLAGS="$PLATFORM_CFLAGS" \
        "${BUILD_ARGS[@]}"

    echo "Building..."
    cmake --build "$BUILD_DIR" --config Release --parallel
    echo "Installing..."
    cmake --install "$BUILD_DIR" --config Release --prefix "$INSTALL_DIR"

elif [ "$BUILD_SYSTEM" = "make" ]; then

    EXTRA_ARGS=("${BUILD_ARGS[@]}")

    if [ -f "./autogen.sh" ]; then
        echo "Configuring (autogen)..."
        ./autogen.sh "${EXTRA_ARGS[@]}"
        EXTRA_ARGS=()
    fi

    if [ -f "./configure" ]; then
        echo "Configuring (configure file)..."
        ./configure \
            --prefix="$INSTALL_DIR" \
            --disable-shared \
            --enable-static \
            --extra-cflags="$PLATFORM_CFLAGS" \
            --extra-cxxflags="$PLATFORM_CFLAGS" \
            "${EXTRA_ARGS[@]}"
        EXTRA_ARGS=()
    fi
    
    echo "Building..."
    make clean
    make -j"$(nproc)" "${EXTRA_ARGS[@]}"
    echo "Installing..."
    make install "${EXTRA_ARGS[@]}"

elif [ "$BUILD_SYSTEM" = "nmake" ]; then

    echo "Building with NMake (MSVC)..."

    if ! command -v nmake >/dev/null 2>&1; then
        echo "nmake not found. Did you run vcvarsall?"
        exit 1
    fi

    if [ -f "makefile.msc" ]; then
        echo "Start nmake ..."
        nmake /D /f "makefile.msc" "${BUILD_ARGS[@]}"
    else
        echo "makefile.msc not found."
        exit 1
    fi

else
    echo "Unsupported build system: $BUILD_SYSTEM"
    exit 1
fi

echo