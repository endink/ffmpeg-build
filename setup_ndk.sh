#!/bin/bash
# Build Android

script_dir=$(cd $(dirname $0);pwd)

export ndk_version=${1:-r25b}
ANDROID_HOME_DIR=${ANDROID_HOME:-/mnt/e/WSL_Data/AndroidSDK}

echo "AndroidHome: ${ANDROID_HOME_DIR}"

if [ ! -d "${ANDROID_HOME_DIR}" ];then 
    mkdir "${ANDROID_HOME_DIR}"
fi


export android_sdk_path="${ANDROID_HOME_DIR}"
export android_ndk_path="${ANDROID_HOME_DIR}/ndk"
sdkmanager_file="${android_sdk_path}/cmdline-tools/bin/sdkmanager"
#export PY=/usr/bin/python3.8

cd ${script_dir}

if [ ! -d "${android_sdk_path}" ]; then 
    mkdir -p "${android_sdk_path}"
fi

if [ ! -d "${android_ndk_path}" ]; then 
    mkdir -p "${android_ndk_path}"
fi


function download_android_sdk() {

set -e

if [ "$(uname)" == "Darwin" ]; then
  platform="darwin"
  platform_android_sdk="mac"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  platform="linux"
  platform_android_sdk="linux"
fi

#refer https://github.com/android/ndk/wiki/Unsupported-Downloads

ndk_url="https://dl.google.com/android/repository/android-ndk-${ndk_version}-${platform}.zip"

licenses="--accept-licenses"

if [ -d "${android_sdk_path}/platforms/android-30" ]
then
  echo "Warning: android_sdk_path is non empty. Installation of the Android SDK will be skipped."
else
  rm -rf /tmp/android_sdk/
  mkdir -p /tmp/android_sdk/
  if [ ! -f "${sdkmanager_file}" ];then
      curl https://dl.google.com/android/repository/commandlinetools-${platform_android_sdk}-7583922_latest.zip -o /tmp/android_sdk/commandline_tools.zip
      unzip /tmp/android_sdk/commandline_tools.zip -d ${android_sdk_path}
      ${sdkmanager_file} --update --sdk_root=${android_sdk_path}
      if [ "$licenses" == "--accept-licenses" ]
      then
        yes | ${sdkmanager_file} --licenses --sdk_root=${android_sdk_path}
      fi
  fi
  ${sdkmanager_file} "build-tools;30.0.3" "platform-tools" "platforms;android-30" "extras;android;m2repository" --sdk_root=${android_sdk_path}
  rm -rf /tmp/android_sdk/
  echo "Android SDK is now installed. Consider setting \$ANDROID_HOME environment variable to be ${android_sdk_path}"
fi

if [ -d "${android_ndk_path}/android-ndk-${ndk_version}" ]
then
  echo "Warning: android_ndk_path is non empty. Android NDK Installation will be ignored."
else
  rm -rf /tmp/android_ndk/
  mkdir -p /tmp/android_ndk/
  echo ""
  echo "Download NDK: ${ndk_url}"
  echo ""
  curl  ${ndk_url} -o /tmp/android_ndk/android_ndk.zip
  unzip /tmp/android_ndk/android_ndk.zip -d ${android_ndk_path}
  rm -rf /tmp/android_ndk/
  echo "Android NDK is now installed. Consider setting \$ANDROID_NDK_HOME environment variable to be ${android_ndk_path}/android-ndk-${ndk_version}"
fi


}


echo "Start install NDK ${ndk_version}"
download_android_sdk
