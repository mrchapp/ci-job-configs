#!/bin/bash

sudo apt-get -q=2 update

sudo apt-get -q=2 -y install ninja-build gperf python3-ply \
    gcc-arm-none-eabi rsync device-tree-compiler \
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

# Note that Zephyr SDK is needed even when building with the gnuarmemb
# toolchain, ZEPHYR_SDK_INSTALL_DIR is needed to find things like conf
ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.12.3/zephyr-sdk-0.12.3-setup.run"
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.12.3"

# GNU ARM Embedded is downloaded once (per release) and cached in a persistent
# docker volume under ${HOME}/srv/toolchain/.
GNUARMEMB_TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/8-2019q3/RC1.1/gcc-arm-none-eabi-8-2019-q3-update-linux.tar.bz2"
export GNUARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-8-2019-q3-update"

install_zephyr_sdk()
{
    test -d ${ZEPHYR_SDK_INSTALL_DIR} && return 0
    test -f ${ZEPHYR_SDK_INSTALL_DIR}.lck && exit 1
    touch ${ZEPHYR_SDK_INSTALL_DIR}.lck
    wget -q "${ZEPHYR_SDK_URL}"
    chmod +x $(basename ${ZEPHYR_SDK_URL})
    ./$(basename ${ZEPHYR_SDK_URL}) --quiet --nox11 -- <<< ${ZEPHYR_SDK_INSTALL_DIR}
    rm -f ${ZEPHYR_SDK_INSTALL_DIR}.lck
}

install_arm_toolchain()
{
    test -d ${GNUARMEMB_TOOLCHAIN_PATH} && return 0
    wget -q "${GNUARMEMB_TOOLCHAIN_URL}"
    top=$(dirname ${GNUARMEMB_TOOLCHAIN_PATH})
    rm -rf ${top}/_tmp.$$
    mkdir -p ${top}/_tmp.$$
    tar -C ${top}/_tmp.$$ -xaf $(basename ${GNUARMEMB_TOOLCHAIN_URL})
    mv ${top}/_tmp.$$/$(basename ${GNUARMEMB_TOOLCHAIN_PATH}) ${top}
}

ls -l ${HOME}/srv/toolchain/
install_zephyr_sdk
install_arm_toolchain
#find ${ZEPHYR_SDK_INSTALL_DIR}
${ZEPHYR_SDK_INSTALL_DIR}/sysroots/x86_64-pokysdk-linux/usr/bin/dtc --version

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
