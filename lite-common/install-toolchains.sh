#!/bin/bash
# Toolchains are downloaded, installed, and cached on a persistent disk
# under ${HOME}/srv/toolchain/ .

set -ex

ZEPHYR_SDK_VER="0.13.0"

ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VER}/zephyr-sdk-${ZEPHYR_SDK_VER}-linux-x86_64-setup.run"
GNUARMEMB_TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2"

ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-${ZEPHYR_SDK_VER}"
GNUARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-9-2019-q4-major"

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

install_zephyr_sdk
install_arm_toolchain

sudo pip3 install cmake==3.20.2

cmake --version
${ZEPHYR_SDK_INSTALL_DIR}/sysroots/x86_64-pokysdk-linux/usr/bin/dtc --version
