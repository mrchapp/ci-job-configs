#!/bin/bash

set -ex
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_VERSION}.tar.xz
tar xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}

# Build deb packages
make mrproper
wget https://git.linaro.org/ci/job/configs.git/plain/lt-qcom-linux/aic100/${DEB_CONFIG} -O .config
make EXTRAVERSION=-050401-generic -j$(nproc) deb-pkg

# Build rpm packages
make mrproper
wget https://git.linaro.org/ci/job/configs.git/plain/lt-qcom-linux/aic100/${RPM_CONFIG} -O .config
make EXTRAVERSION=-050401-generic -j$(nproc) rpm-pkg

cd ..
ls -ltr


