#!/bin/bash

set -ex

# setup and download sources
KERNEL_VERSION=5.4.1
mkdir -p ${WORKSPACE}/out
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz
tar xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}

if [ "${DISTRO}" == "bionic" ]; then
    sudo apt update
    sudo apt install -y bc kmod cpio dpkg-dev wget flex bison bc kmod cpio libssl-dev lz4 libelf-dev libssl-dev build-essential rsync
    make mrproper
    wget https://git.linaro.org/ci/job/configs.git/plain/lt-qcom-linux/aic100/config-5.4.1-050401-generic -O .config
    make EXTRAVERSION=-050401-generic -j$(nproc) deb-pkg
    cp ../*.deb ${WORKSPACE}/out

elif [ "${DISTRO}" == "centos7" ]; then
    sudo yum check-update
    sudo yum install -y git which gcc ncurses-devel make gcc bc bison flex elfutils-libelf-devel openssl-devel vim rpm-build rsync
    make mrproper
    wget https://git.linaro.org/ci/job/configs.git/plain/lt-qcom-linux/aic100/config-5.4.1-1.el7.elrepo.x86_64 -O .config
    make EXTRAVERSION=-1.el7.elrepo.x86_64 -j$(nproc) rpm-pkg
    cp ~/rpmbuild/RPMS/x86_64/*.rpm ${WORKSPACE}/out
fi
