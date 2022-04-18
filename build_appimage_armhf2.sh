#!/bin/bash

source common.sh

QUIRKS_FILE=
APP_DIR=${BUILD_DIR}/AppDir
UPDATE_CMAKE_OPTIONS=""
BUILD_NUM="0"

while getopts "h?q:j:u:i:k:" opt; do
    case "$opt" in
    h|\?)
        echo "build.sh"
        echo "-j  Specify the number of jobs (the -j arg to make)"
        echo "-q  Specify the quirks file"
        echo "-u  Specify the update check URL"
        echo "-i  Specify the build id for update checking"
        echo "-k  Specify appimageupdate information"
        exit 0
        ;;
    j)  MAKE_JOBS=$OPTARG
        ;;
    q)  QUIRKS_FILE=$OPTARG
        ;;
    u)  UPDATE_CMAKE_OPTIONS="$UPDATE_CMAKE_OPTIONS -DENABLE_UPDATE_CHECK=ON -DUPDATE_CHECK_URL=$OPTARG"
        ;;
    i)  UPDATE_CMAKE_OPTIONS="$UPDATE_CMAKE_OPTIONS -DUPDATE_CHECK_BUILD_ID=$OPTARG"
        BUILD_NUM="${OPTARG}"
        ;;
    k)  UPDATE_CMAKE_OPTIONS="$UPDATE_CMAKE_OPTIONS -DENABLE_APPIMAGE_UPDATE_CHECK=1"
        export UPDATE_INFORMATION="$OPTARG"
        ;;
    esac
done

load_quirks "$QUIRKS_FILE"

create_build_directories
rm -rf ${APP_DIR}
mkdir -p ${APP_DIR}
call_quirk init

show_status "Downloading sources"
download_repo msa https://github.com/minecraft-linux/msa-manifest.git $(cat msa.commit)
download_repo mcpelauncher https://github.com/minecraft-linux/mcpelauncher-manifest.git $(cat mcpelauncher.commit)
download_repo mcpelauncher-ui https://github.com/minecraft-linux/mcpelauncher-ui-manifest.git $(cat mcpelauncher-ui.commit)
# download_repo curl https://github.com/curl/curl.git master
download_repo "mcpelauncher-ui/lib/AppImageUpdate" https://github.com/AppImage/AppImageUpdate 1b97acc55c89f742d51c3849eb62eb58464d8669
call_quirk build_start

install_component() {
  pushd $BUILD_DIR/$1
  check_run make install DESTDIR="${APP_DIR}"
  popd
}

build_component32() {
  show_status "Building $1"
  mkdir -p $BUILD_DIR/$1
  pushd $BUILD_DIR/$1
  echo "cmake" "${CMAKE_OPTIONS[@]}" "$SOURCE_DIR/$1"
  check_run cmake "${CMAKE_OPTIONS[@]}" "$SOURCE_DIR/$1"
  sed -i 's/\/usr\/lib\/x86_64-linux-gnu/\/usr\/lib\/arm-linux-gnueabihf/g' CMakeCache.txt
  sed -i 's/\/usr\/include\/x86_64-linux-gnu/\/usr\/include\/arm-linux-gnueabihf/g' CMakeCache.txt
  check_run make -j${MAKE_JOBS}
  popd
}

# reset_cmake_options
# add_cmake_options -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_TOOLCHAIN_FILE=${OUTPUT_DIR}/../armhftoolchain.txt -DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++
# build_component32 curl
# install_component curl

reset_cmake_options
add_cmake_options -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_MSA_QT_UI=ON -DMSA_UI_PATH_DEV=OFF -DCMAKE_TOOLCHAIN_FILE=${OUTPUT_DIR}/../armhftoolchain.txt -DCPACK_DEBIAN_PACKAGE_ARCHITECTURE=armhf -DCMAKE_ASM_FLAGS="--target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_C_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_CXX_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon -DNDEBUG -I ${PWD}/curlappimageca" -DCURL_INCLUDE_DIRS="$APP_DIR/usr/include" -DCURL_LIBRARIES="$APP_DIR/usr/lib/libcurl.so"
call_quirk build_msa
build_component32 msa
install_component msa
reset_cmake_options
add_cmake_options -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_TOOLCHAIN_FILE=${OUTPUT_DIR}/../armhftoolchain.txt -DCPACK_DEBIAN_PACKAGE_ARCHITECTURE=armhf -DMSA_DAEMON_PATH=. -DCMAKE_ASM_FLAGS="--target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_C_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_CXX_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon -DNDEBUG -I ${PWD}/curlappimageca" -DJNI_USE_JNIVM=ON -DXAL_WEBVIEW_QT_PATH=. -DCURL_INCLUDE_DIRS="$APP_DIR/usr/include" -DCURL_LIBRARIES="$APP_DIR/usr/lib/libcurl.so" -DQt5QuickCompiler_FOUND:BOOL=OFF -DENABLE_QT_ERROR_UI=OFF
call_quirk build_mcpelauncher
build_component32 mcpelauncher
install_component mcpelauncher
reset_cmake_options
download_repo versionsdb https://github.com/minecraft-linux/mcpelauncher-versiondb.git $(cat versionsdb.txt)
add_cmake_options -DCMAKE_INSTALL_PREFIX=/usr -DGAME_LAUNCHER_PATH=. $UPDATE_CMAKE_OPTIONS -DCMAKE_TOOLCHAIN_FILE=${OUTPUT_DIR}/../armhftoolchain.txt -DCPACK_DEBIAN_PACKAGE_ARCHITECTURE=armhf -DCMAKE_ASM_FLAGS="--target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_C_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon" -DCMAKE_CXX_FLAGS="-latomic --target=arm-linux-gnueabihf -march=armv7 -mfpu=neon -DNDEBUG -I ${PWD}/curlappimageca -DLAUNCHER_INIT_PATCH=\"if(!getenv(\\\"QTWEBENGINE_CHROMIUM_FLAGS\\\")) putenv(\\\"QTWEBENGINE_CHROMIUM_FLAGS=--no-sandbox\\\");\"" -DLAUNCHER_VERSION_NAME="$(cat version.txt).${BUILD_NUM}-AppImage-armhf" -DLAUNCHER_VERSION_CODE=${BUILD_NUM} -DLAUNCHER_CHANGE_LOG="Launcher $(cat version.txt)<br/>$(cat changelog.txt)" -DQt5QuickCompiler_FOUND:BOOL=OFF -DCURL_INCLUDE_DIRS="$APP_DIR/usr/include" -DCURL_LIBRARIES="$APP_DIR/usr/lib/libcurl.so" -DLAUNCHER_ENABLE_GOOGLE_PLAY_LICENCE_CHECK=ON -DLAUNCHER_DISABLE_DEV_MODE=OFF -DLAUNCHER_VERSIONDB_URL=https://raw.githubusercontent.com/minecraft-linux/mcpelauncher-versiondb/$(cat versionsdbremote.txt) -DLAUNCHER_VERSIONDB_PATH=$SOURCE_DIR/versionsdb
call_quirk build_mcpelauncher_ui

build_component32 mcpelauncher-ui
install_component mcpelauncher-ui

show_status "Packaging"

cp $SOURCE_DIR/mcpelauncher-ui/mcpelauncher-ui-qt/Resources/proprietary/mcpelauncher-icon-512.png $BUILD_DIR/mcpelauncher-ui-qt.png
cp $SOURCE_DIR/mcpelauncher-ui/mcpelauncher-ui-qt/mcpelauncher-ui-qt.desktop $BUILD_DIR/mcpelauncher-ui-qt.desktop

# download linuxdeploy and make it executable
wget -N https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-i386.AppImage
# also download Qt plugin, which is needed for the Qt UI
wget -N https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-i386.AppImage

wget -N https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage

wget -N https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-armhf

chmod +x linuxdeploy*-i386.AppImage
chmod +x appimagetool*.AppImage

export ARCH=arm

# git clone https://github.com/NixOS/patchelf.git
# cd patchelf
# ./bootstrap.sh
# ./configure
# make -j2
# cd ..

mkdir linuxdeploy
cd linuxdeploy
../linuxdeploy-i386.AppImage --appimage-extract
# fix arm
rm -rf squashfs-root/usr/bin/strip squashfs-root/usr/bin/patchelf
# ln -s ../../../../patchelf/src/patchelf squashfs-root/usr/bin/patchelf
# cp ../patchelf/src/patchelf squashfs-root/usr/bin/
# cp ../patchelf squashfs-root/usr/bin/
echo '#!/bin/bash' > squashfs-root/usr/bin/patchelf
# echo 'echo patchelf $@>>/home/christopher/linux-packaging-scripts/patchelf.log' >> squashfs-root/usr/bin/patchelf
chmod +x squashfs-root/usr/bin/patchelf
# ln -s /usr/arm-linux-gnueabihf/bin/strip squashfs-root/usr/bin/strip
# cp /usr/arm-linux-gnueabihf/bin/strip squashfs-root/usr/bin/strip
echo '#!/bin/bash' > squashfs-root/usr/bin/strip
chmod +x squashfs-root/usr/bin/strip
cd ..
mkdir linuxdeploy-plugin-qt
cd linuxdeploy-plugin-qt
../linuxdeploy-plugin-qt-i386.AppImage --appimage-extract
# fix arm
rm -rf squashfs-root/usr/bin/strip squashfs-root/usr/bin/patchelf
# ln -s ../../../../patchelf/src/patchelf squashfs-root/usr/bin/patchelf
# cp ../patchelf/src/patchelf squashfs-root/usr/bin/
# cp ../patchelf squashfs-root/usr/bin/
echo '#!/bin/bash' > squashfs-root/usr/bin/patchelf
# echo 'echo patchelf $@>>/home/christopher/linux-packaging-scripts/patchelf.log' >> squashfs-root/usr/bin/patchelf
chmod +x squashfs-root/usr/bin/patchelf
# ln -s /usr/arm-linux-gnueabihf/bin/strip squashfs-root/usr/bin/strip
# cp /usr/arm-linux-gnueabihf/bin/strip squashfs-root/usr/bin/strip
echo '#!/bin/bash' > squashfs-root/usr/bin/strip
chmod +x squashfs-root/usr/bin/strip
cd ..
mkdir appimagetool
cd appimagetool
../appimagetool-x86_64.AppImage --appimage-extract
cd ..
LINUXDEPLOY_BIN=linuxdeploy/squashfs-root/AppRun
LINUXDEPLOY_PLUGIN_QT_BIN=linuxdeploy-plugin-qt/squashfs-root/AppRun
APPIMAGETOOL_BIN=appimagetool/squashfs-root/AppRun

rm -rf ./*.AppImage
check_run $LINUXDEPLOY_BIN --appdir $APP_DIR -i $BUILD_DIR/mcpelauncher-ui-qt.png -d $BUILD_DIR/mcpelauncher-ui-qt.desktop

export QML_SOURCES_PATHS=$SOURCE_DIR/mcpelauncher-ui/mcpelauncher-ui-qt/qml/:$SOURCE_DIR/mcpelauncher/mcpelauncher-webview
check_run $LINUXDEPLOY_PLUGIN_QT_BIN --appdir $APP_DIR

# libnss needs it's subdirectory to load the google login view
check_run cp -r /usr/lib/arm-linux-gnueabihf/nss $APP_DIR/usr/lib/
# glib is excluded by appimagekit, but gmodule isn't which causes issues
check_run rm -rf "$APP_DIR/usr/lib/libgmodule-2.0.so.0"

curl -L -k https://curl.se/ca/cacert.pem --output $APP_DIR/usr/share/mcpelauncher/cacert.pem

rm $APP_DIR/AppRun
cp ./AppRun $APP_DIR/AppRun
chmod +x $APP_DIR/AppRun

export OUTPUT="Minecraft_Bedrock_Launcher-${ARCH}-$(cat version.txt).${BUILD_NUM}.AppImage"
export ARCH=arm
check_run $APPIMAGETOOL_BIN --comp xz ${UPDATE_INFORMATION+"-u"} ${UPDATE_INFORMATION} --runtime-file runtime-armhf $APP_DIR $OUTPUT
check_run mv Minecraft*.AppImage output
#cat '~/Downloads/version.x86_64.zsync'  |  sed -e 's/\(URL: \)\(.*\)/\1..\/test\/\2/g' | less
#mv *.zsync output/version.armhf.zsync
cat *.zsync | sed -e "s/\(URL: \)\(.*\)/\1..\/$(cat version.txt)-${BUILD_NUM}\/\2/g" > output/version.armhf.zsync
cleanup_build
