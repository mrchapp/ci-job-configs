#!/bin/bash
set -ex

export LANG=C.UTF-8

if python3 --version | grep -q " 3\.[5]"; then
    # Zephyr 2.2+ requires Python3.6. As it's not available in official distro
    # packages for Ubuntu Xenial (16.04) which we use, install it from PPA.
    echo Upgrading Python from deadsnakes PPA
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get -q=2 update
    sudo apt-get install -y python3.6
    sudo ln -sf python3.6 /usr/bin/python3
fi

sudo apt-get -q=2 update

# python-is-python2 is needed for Google depot_tools below.
sudo apt-get -q=2 -y install python3-pip python3-setuptools python3-serial rename socat python-is-python2

# pip as shipped by distro may be not up to date enough to support some
# quirky PyPI packages, specifically cmake was caught like that.
sudo pip3 install --upgrade pip

sudo pip3 install pyelftools
# Zephyr requires very recent version of CMake. Strangely enough, such
# can be installed from PyPI.
sudo pip3 install cmake

sudo pip3 install west
west --version

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 ${GIT_URL} -b ${BRANCH} ${WORKSPACE}
(cd ${WORKSPACE}; git describe --always)

# We used to call git-retry shell wrapper, until it started to choose
# a wrong Python interpreter. "_" below is a param ignored when executing
# git_retry.py directly.
#python ${HOME}/depot_tools/git_retry.py _ submodule sync --recursive
#python ${HOME}/depot_tools/git_retry.py _ submodule update --init --recursive --checkout

#git clean -fdx

GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)
echo "GIT_COMMIT_ID=${GIT_COMMIT_ID}" >${WORKSPACE}/env_var_parameters

# Toolchains are downloaded once (per release) and cached in a persistent
# docker volume under ${HOME}/srv/toolchain/.
# Note that Zephyr SDK is needed even when building with the gnuarmemb
# toolchain, ZEPHYR_SDK_INSTALL_DIR is needed to find things like conf.
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.13.1"
export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-9-2019-q4-major"

# Set build environment variables
ZEPHYR_BASE=${WORKSPACE}
PATH=${ZEPHYR_BASE}/scripts:${PATH}
OUTDIR=${HOME}/srv/zephyr/${ZEPHYR_TOOLCHAIN_VARIANT}/${PLATFORM}
export ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'
python3 -c "import sys; print(sys.getdefaultencoding())"

# Clone Zephyr
git clone --depth 1 ${ZEPHYR_GIT_URL} -b ${ZEPHYR_BRANCH} zephyr
cd zephyr
git describe --always
ZEPHYR_GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)
echo "ZEPHYR_GIT_COMMIT_ID=${ZEPHYR_GIT_COMMIT_ID}" >>${WORKSPACE}/env_var_parameters
cd ..
west init -l zephyr/
west update
(cd zephyr; git clean -fdx)
. zephyr/zephyr-env.sh

# Build ID to use in external systems, like LAVA/SQUAD. Should include
# ${BUILD_NUMBER}, to avoid mixing up results of different builds of the
# same project git revision.
echo "EXTERNAL_BUILD_ID=${GIT_COMMIT_ID}-z${ZEPHYR_GIT_COMMIT_ID}-${BUILD_NUMBER}" >>${WORKSPACE}/env_var_parameters

echo ""
echo "########################################################################"
echo "    Build"
echo "########################################################################"

