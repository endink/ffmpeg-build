#!/usr/bin/env bash
set -e

# ========================================
# 参数检查
# ========================================

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage:"
    echo "  $0 <url> <cmake|make|nmake> <src_dir> \"<build_args>\""
    exit 1
fi

URL="$1"
BUILD_SYSTEM="$2"
SRC_DIR_NAME="$3"
BUILD_ARGS="${4:-""}"

# ========================================
# 目录定义
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT=${SOURCE_ROOT:-"${SCRIPT_DIR}/_deps"}
DOWNLOAD_DIR="$SOURCE_ROOT/download"
BUILD_ROOT="$SRC_DIR_NAME/build"
INSTALL_DIR=${DEPS_INSTALL_DIR:-"$SOURCE_ROOT/install"}

mkdir -p "$DOWNLOAD_DIR"

SRC_DIR="$SRC_DIR_NAME"

FILENAME="$(basename "$URL")"
ARCHIVE_PATH="$DOWNLOAD_DIR/$FILENAME"

echo
echo "==============================="
echo "Dependenc Building: $FILENAME"
echo ""
echo "URL:          $URL"
echo "Archive:      $ARCHIVE_PATH"
echo "BuildSystem:  $BUILD_SYSTEM"
echo "Source Dir:   $SRC_DIR"
echo "Build Args:   $BUILD_ARGS"
echo "==============================="
echo

# 保存 MSYS2_ARG_CONV_EXCL 以便还原
OLD_MSYS2_ARG_CONV_EXCL="$MSYS2_ARG_CONV_EXCL"

# ========================================
# 统一退出函数
# ========================================
function on_exit() {
    local code=$?
    # 还原 MSYS2_ARG_CONV_EXCL
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
            # zip 无法直接 strip-components
            TMP_DIR="$DOWNLOAD_DIR/__tmp_extract"
            rm -rf "$TMP_DIR"
            mkdir -p "$TMP_DIR"

            unzip -q "$ARCHIVE_PATH" -d "$TMP_DIR"

            # 取第一个子目录
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

# mkdir -p "$BUILD_ROOT"

mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/include"

# ========================================
# 构建
# ========================================


INSTALL_DIR_WIN=$(cygpath -w "$INSTALL_DIR")
SRC_DIR_WIN=$(cygpath -w "$SRC_DIR")
BUILD_DIR_WIN=$(cygpath -w "$BUILD_ROOT")



export MSYS2_ARG_CONV_EXCL="*"

MSVC_CFLAGS="/utf-8 /O2 /MD"

if [ "$BUILD_SYSTEM" = "cmake" ]; then

    mkdir -p build
    cd build

    echo "Configuring (CMake)..."

    cmake -G "Ninja" \
        -S "$SRC_DIR_WIN" \
        -B "$BUILD_DIR_WIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR_WIN" \
        -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL \
        -DCMAKE_C_FLAGS="$MSVC_CFLAGS" \
        -DCMAKE_CXX_FLAGS="$MSVC_CFLAGS" \
        $BUILD_ARGS \
        ..

    echo "Building..."
    cmake --build . --parallel
    echo "Installing..."
    cmake --install .

elif [ "$BUILD_SYSTEM" = "make" ]; then

    echo "Configuring (Autotools)..."

    if [ -f "./autogen.sh" ]; then
        ./autogen.sh
    fi

    if [ -f "./configure" ]; then
        ./configure \
            --prefix="$INSTALL_DIR_WIN" \
            --disable-shared \
            --enable-static \
            --extra-cflags="$MSVC_CFLAGS" \
            --extra-cxxflags="$MSVC_CFLAGS" \
            $BUILD_ARGS
    else
        echo "No configure script found."
        exit 1
    fi

    echo "Building..."
    make -j"$(nproc)"
    echo "Installing..."
    make install

elif [ "$BUILD_SYSTEM" = "nmake" ]; then

    echo "Building with NMake (MSVC)..."

    if ! command -v nmake >/dev/null 2>&1; then
        echo "nmake not found. Did you run vcvarsall?"
        exit 1
    fi

    if [ -f "makefile.msc" ]; then
        echo "Start nmake ..."
        nmake /D /f "makefile.msc" $BUILD_ARGS
    else
        echo "makefile.msc not found."
        exit 1
    fi



else
    echo "Unsupported build system: $BUILD_SYSTEM"
    exit 1
fi

echo