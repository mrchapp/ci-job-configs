#!/bin/bash

sudo apt-get -q=2 update

# gcc-arm-none-eabi
sudo apt-get -q=2 -y install ninja-build gperf python3-ply \
    rsync device-tree-compiler \
    python3-pip python3-serial python3-setuptools python3-wheel \
    python3-requests python3-pyelftools util-linux rename

set -ex

sudo pip3 install west
west --version

git clone -b ${BRANCH} https://github.com/zephyrproject-rtos/zephyr.git
west init -l zephyr/
west update

cd zephyr
git clean -fdx
if [ -n "${GIT_COMMIT}" ]; then
  git checkout ${GIT_COMMIT}
fi
echo "GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)" > ${WORKSPACE}/env_var_parameters
echo "EXTERNAL_BUILD_ID=$(git rev-parse --short=8 HEAD)-${BUILD_NUMBER}" >> ${WORKSPACE}/env_var_parameters

# Toolchains are downloaded once (per release) and cached in a persistent
# docker volume under ${HOME}/srv/toolchain/.
# Note that Zephyr SDK is needed even when building with the gnuarmemb
# toolchain, ZEPHYR_SDK_INSTALL_DIR is needed to find things like conf.
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.13.0"
export GNUARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-8-2019-q3-update"

# Set build environment variables
export LANG=C.UTF-8
ZEPHYR_BASE=${WORKSPACE}/zephyr
PATH=${ZEPHYR_BASE}/scripts:${PATH}
OUTDIR=${WORKSPACE}/zephyr-build/${BRANCH}/${ZEPHYR_TOOLCHAIN_VARIANT}/${PLATFORM}
export LANG ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache-zephyr/${BRANCH}"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'
mkdir -p "${CCACHE_DIR}"
rm -rf ${OUTDIR}

if [ -n "${CCACHE_CTRL}" ]; then
    time CCACHE_DIR=${CCACHE_DIR} ccache ${CCACHE_CTRL}
fi

echo ""
echo "########################################################################"
echo "    build (twister)"
echo "########################################################################"

# Show ccache stats both before and after build.
CCACHE_DIR=${CCACHE_DIR} ccache --show-stats

time ${ZEPHYR_BASE}/scripts/twister \
  --platform ${PLATFORM} \
  --inline-logs \
  --verbose \
  --build-only \
  --outdir ${OUTDIR} \
  --enable-slow \
  -x=USE_CCACHE=${USE_CCACHE} \
  ${TWISTER_EXTRA}

CCACHE_DIR=${CCACHE_DIR} ccache --show-stats

# Put report where rsync below will pick it up.
cp ${OUTDIR}/twister.csv ${OUTDIR}/${PLATFORM}/

cd ${ZEPHYR_BASE}
# OUTDIR is already per-platform, but it may get contaminated with unrelated
# builds e.g. due to bugs in twister script. It however stores builds in
# per-platform named subdirs under its --outdir (${OUTDIR} in our case), so
# we use ${OUTDIR}/${PLATFORM} paths below.
find ${OUTDIR}/${PLATFORM} -type f -name '.config' -exec rename 's/.config/zephyr.config/' {} +
rsync -avm \
  --include=zephyr.bin \
  --include=zephyr.config \
  --include=zephyr.elf \
  --include='twister.*' \
  --include='*/' \
  --exclude='*' \
  ${OUTDIR}/${PLATFORM} ${WORKSPACE}/out/
find ${OUTDIR}/${PLATFORM} -type f -name 'zephyr.config' -delete
# If there are support files, ship them.
BOARD_CONFIG=$(find "${ZEPHYR_BASE}/boards/" -type f -name "${PLATFORM}_defconfig")
BOARD_DIR=$(dirname ${BOARD_CONFIG})
test -d "${BOARD_DIR}/support" && rsync -avm "${BOARD_DIR}/support" "${WORKSPACE}/out/${PLATFORM}"

cd ${WORKSPACE}/
echo "=== contents of ${WORKSPACE}/out/ ==="
find out
echo "=== end of contents of ${WORKSPACE}/out/ ==="

CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
