#!/bin/bash

set -ex

mkdir -p out
virtualenv --python=$(which python3) .venv
source .venv/bin/activate

export LAVA_TEST_PLANS_GIT_REPO=https://github.com/alimon/lava-test-plans.git

export BUILD_URL=https://ci.linaro.org/job/lt-qcom-debian-images-dragonboard410c/1092/
export BUILD_NUMBER=1092
export OS_FLAVOUR=sid
export VENDOR=linaro
export PLATFORM_NAME=dragonboard-410c
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export PMWG_LAVA_SERVER=https://pmwg.validation.linaro.org/RPC2/
export ARTIFACTORIAL_TOKEN="nosecret"
export DRY_RUN="--dry-run "

export DEVICE_TYPE=dragonboard-410c
export PUBLISH_SERVER=https://snapshots.linaro.org/
export PUB_DEST=96boards/dragonboard410c/${VENDOR}/debian/${BUILD_NUMBER}
bash submit_for_testing.sh
cp -r lava-test-plans/tmp/dragonboard-410c out/

# cleanup virtualenv
deactivate
rm -rf .venv
