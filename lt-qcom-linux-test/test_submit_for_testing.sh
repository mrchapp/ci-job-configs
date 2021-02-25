#!/bin/bash

set -ex

mkdir -p out
virtualenv --python=$(which python3) .venv
source .venv/bin/activate

export LAVA_TEST_PLANS_GIT_REPO=https://github.com/alimon/lava-test-plans.git

export BUILD_NUMBER=774
export BUILD_URL=https://ci.linaro.org/job/lt-qcom-linux-integration/774/MACHINE=apq8016-sbc,label=docker-stretch-amd64/
export KERNEL_REPO=https://git.linaro.org/landing-teams/working/qualcomm/kernel.git/
export KERNEL_BRANCH=integration-linux-qcomlt
export KERNEL_COMMIT=d975b65255b62891a533fa57196a7bd1097a7825
export KERNEL_DESCRIBE=v5.11-439-gd975b65255b6
export KERNEL_CONFIG=defconfig
export KERNEL_TOOLCHAIN=unknown

export PUBLISH_SERVER=https://snapshots.linaro.org/

export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export QA_SERVER_PROJECT="linux-integration"

export DRY_RUN="--dry-run "

export MACHINE="sdm845-db845c"
export PUB_DEST=member-builds/qcomlt/linux-integration/${MACHINE}/774/
export BOOT_FILE=boot-linux-integration-v5.11-435-g01c71850a6a8-774-sdm845-db845c.img
export BOOT_ROOTFS_FILE=boot-rootfs-linux-integration-v5.11-435-g01c71850a6a8-774-sdm845-db845c.img
export ROOTFS_FILE=rpb-console-image-test-qemuarm64-20210219075501-702.rootfs.img.gz
export ROOTFS_DESKTOP_FILE=rpb-desktop-image-test-qemuarm64-20210219075501-702.rootfs.img.gz
bash submit_for_testing.sh
cp -r lava-test-plans/tmp/dragonboard-845c out/

export MACHINE="apq8016-sbc"
export PUB_DEST=member-builds/qcomlt/linux-integration/${MACHINE}/774/
export BOOT_FILE=boot-linux-integration-v5.11-435-g01c71850a6a8-774-apq8016-sbc.img
export BOOT_ROOTFS_FILE=boot-rootfs-linux-integration-v5.11-435-g01c71850a6a8-774-apq8016-sbc.img
export ROOTFS_FILE=rpb-console-image-test-qemuarm64-20210219075501-702.rootfs.img.gz
export ROOTFS_DESKTOP_FILE=rpb-desktop-image-test-qemuarm64-20210219075501-702.rootfs.img.gz
bash submit_for_testing.sh
cp -r lava-test-plans/tmp/dragonboard-410c out/

# cleanup virtualenv
deactivate
rm -rf .venv
