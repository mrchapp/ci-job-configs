#!/bin/bash

set -ex

mkdir -p out
virtualenv --python=$(which python3) .venv
source .venv/bin/activate

export LAVA_TEST_PLANS_GIT_REPO=https://github.com/alimon/lava-test-plans.git

export BUILD_URL=https://ci.linaro.org/job/lt-qcom-openembedded-rpb-dunfell/451/
export BUILD_NUMBER=451
export DISTRO=rpb
export MANIFEST_BRANCH=dunfell
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export DRY_RUN="--dry-run "

export MACHINE=dragonboard-410c
export BOOT_URL=https://snapshots.linaro.org/96boards/dragonboard410c/linaro/openembedded/dunfell/451/rpb/boot-apq8016-sbc--5.13-r0-dragonboard-410c-20210927115635-451.img
export ROOTFS_SPARSE_BUILD_URL=https://snapshots.linaro.org/96boards/dragonboard410c/linaro/openembedded/dunfell/451/rpb/rpb-console-image-test-dragonboard-410c-20210927115635-451.rootfs.img.gz

bash submit_for_testing.sh
cp -r lava-test-plans/tmp/dragonboard-410c out/

# cleanup virtualenv
deactivate
rm -rf .venv
