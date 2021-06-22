#!/bin/bash

if [ ! -d "${WORKSPACE}" ]; then
    set -x
    WORKSPACE=$(pwd)
    BUILD_NUMBER=0
else
    set -ex
fi

cd ${WORKSPACE}/linux

KERNEL_REPO="$GIT_URL"
KERNEL_COMMIT="$GIT_COMMIT"
KERNEL_BRANCH="$GIT_BRANCH"
if [ -z "${ARCH}" ]; then
    export ARCH=arm64
    export KERNEL_CONFIGS_arm64="defconfig distro.config"
fi
if [ -z "${KERNEL_VERSION}" ]; then
    KERNEL_VERSION=$(make kernelversion)
fi
if [ -z "${KERNEL_DESCRIBE}" ]; then
    git fetch --tags https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux.git
    git fetch --tags https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable.git
    KERNEL_DESCRIBE=$(git describe --always)
fi
if [ -z "${KDEB_CHANGELOG_DIST}" ]; then
    KDEB_CHANGELOG_DIST="unstable"
fi
if [ -z "${KERNEL_BUILD_TARGET}" ]; then
    KERNEL_BUILD_TARGET="all"
fi
KERNEL_CONFIGS=KERNEL_CONFIGS_$ARCH

# tcbindir from install-gcc-toolchain.sh
export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
export PATH=${tcbindir}:$PATH
KERNEL_TOOLCHAIN="$(ccache aarch64-none-linux-gnu-gcc --version | head -1)"

cat << EOF > ${WORKSPACE}/kernel_parameters
KERNEL_REPO=${KERNEL_REPO}
KERNEL_COMMIT=${KERNEL_COMMIT}
KERNEL_BRANCH=${KERNEL_BRANCH}
KERNEL_CONFIG=${!KERNEL_CONFIGS}
KERNEL_VERSION=${KERNEL_VERSION}
KERNEL_DESCRIBE=${KERNEL_DESCRIBE}
KERNEL_TOOLCHAIN=${KERNEL_TOOLCHAIN}
EOF

echo "Starting ${JOB_NAME} with the following parameters:"
cat ${WORKSPACE}/kernel_parameters

# SRCVERSION is the main kernel version, e.g. <version>.<patchlevel>.0.
# PKGVERSION is similar to make kernelrelease, but reimplemented, since it requires setting up the build (and all tags).
# e.g. SRCVERSION -> 4.9.0, PKGVERSION -> 4.9.47-530-g244b81e58a54, which leads to
#      linux-4.9.0-qcomlt (4.9.47-530-g244b81e58a54-99)
SRCVERSION=$(echo ${KERNEL_VERSION} | sed 's/\(.*\)\..*/\1.0/')
PKGVERSION=$(echo ${KERNEL_VERSION} | sed -e 's/\.0-rc/\.0~rc/')$(echo ${KERNEL_DESCRIBE} | awk -F- '{printf("-%05d-%s", $(NF-1),$(NF))}')

make distclean
make ${!KERNEL_CONFIGS}
if [ "${UPDATE_DEFCONFIG}" ]; then
	make savedefconfig
	cp defconfig arch/${ARCH}/configs
fi

make KERNELRELEASE=${SRCVERSION}-qcomlt-${ARCH} \
     KDEB_SOURCENAME=linux-${SRCVERSION}-qcomlt-${ARCH} \
     KDEB_PKGVERSION=${PKGVERSION}-${BUILD_NUMBER} \
     KDEB_CHANGELOG_DIST=${KDEB_CHANGELOG_DIST} \
     DEBEMAIL="dragonboard@lists.96boards.org" \
     DEBFULLNAME="Linaro Qualcomm Landing Team" \
     -j$(nproc) ${KERNEL_BUILD_TARGET}
make KERNELRELEASE=${SRCVERSION}-qcomlt-${ARCH} -j$(nproc) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=./INSTALL_MOD_PATH modules_install
cd ..

cat > params <<EOF
source=${JOB_URL}/ws/$(echo *.dsc)
repo=${TARGET_REPO}
EOF
