#!/bin/bash

set -ex

# Create variables file to use with lava-test-plans submit_for_testing.py
function create_testing_variables_file () {
	cat << EOF > $1
"LAVA_JOB_PRIORITY": "$LAVA_JOB_PRIORITY"

"PROJECT": "projects/lt-qcom/"
"PROJECT_NAME": "lt-qcom"
"OS_INFO": "kernel"

"BUILD_URL": "$BUILD_URL"
"BUILD_NUMBER": "$BUILD_NUMBER"
"KERNEL_REPO": "$KERNEL_REPO"
"KERNEL_BRANCH": "$KERNEL_BRANCH"
"KERNEL_COMMIT": "$KERNEL_COMMIT"
"KERNEL_DESCRIBE": "$KERNEL_DESCRIBE"
"KERNEL_CONFIG": "$KERNEL_CONFIG"
"TOOLCHAIN": "$KERNEL_TOOLCHAIN"

"DEPLOY_OS": "oe"
"BOOT_URL": "$BOOT_URL"
"BOOT_URL_COMP": "$BOOT_URL_COMP"
"LXC_BOOT_FILE": "$LXC_BOOT_FILE"
"ROOTFS_URL": "$ROOTFS_URL"
"ROOTFS_URL_COMP": "$ROOTFS_URL_COMP"
"LXC_ROOTFS_FILE": "$LXC_ROOTFS_FILE"

"SMOKE_TESTS": "$SMOKE_TESTS"
"WLAN_DEVICE": "$WLAN_DEVICE"
"ETH_DEVICE": "$ETH_DEVICE"
"DEQP_FAIL_LIST": "$DEQP_FAIL_LIST"
EOF
}

rm -rf lava-test-plans
if [ "$LAVA_TEST_PLANS_GIT_REPO" ]; then
  git clone --depth 1 $LAVA_TEST_PLANS_GIT_REPO lava-test-plans
else
  git clone --depth 1 https://github.com/Linaro/lava-test-plans.git
fi
export LAVA_TEST_CASES_PATH=$(realpath lava-test-plans)
pip3 install -r "$LAVA_TEST_CASES_PATH/requirements.txt"

SEND_TESTJOB=false
case "${MACHINE}" in
  apq8016-sbc|apq8096-db820c|sdm845-db845c)
    SEND_TESTJOB=true

    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk, lscpu"
    export WLAN_DEVICE="wlan0"
    export ETH_DEVICE="eth0"

    if [ ${MACHINE} = "apq8016-sbc" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-410c"
      export DEQP_FAIL_LIST="deqp-freedreno-a307-fails.txt"
    elif [ ${MACHINE} = "apq8096-db820c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-820c"
      export DEQP_FAIL_LIST="deqp-freedreno-a530-fails.txt"
    elif [ ${MACHINE} = "sdm845-db845c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-845c"
      export DEQP_FAIL_LIST="deqp-freedreno-a630-fails.txt"
    fi
    ;;
  *)
    echo "Skip LAVA_DEVICE_TYPE for ${MACHINE}"
    ;;
esac

# Select which testcases will be send to LAVA
# - bootrr on integration, mainline and release.
# - smoke on integration, mainline and release with Dragonboard machines.
case "${MACHINE}" in
  apq8016-sbc|apq8096-db820c|sdm845-db845c)
      SMOKE_TEST_CASE=true
      DESKTOP_TEST_CASE=true
      MULTIMEDIA_TEST_CASE=true
  ;;
esac

if [ $SEND_TESTJOB = true ]; then
  export LAVA_JOB_PRIORITY="high"
  export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_FILE}
  export BOOT_URL_COMP=
  export LXC_BOOT_FILE=$(basename ${BOOT_URL})

  create_testing_variables_file out/submit_for_testing_bootrr.yaml

  cd lava-test-plans
  ./submit_for_testing.py \
      --device-type ${LAVA_DEVICE_TYPE} \
      --build-number ${KERNEL_DESCRIBE} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team qcomlt \
      --qa-server-project ${QA_SERVER_PROJECT} \
      --testplan-device-path projects/lt-qcom/devices \
      ${DRY_RUN} \
      --test-case testcases/kernel-bootrr.yaml \
      --variables ../out/submit_for_testing_bootrr.yaml
  cd ..

  if [ $SMOKE_TEST_CASE = true ]; then
    export LAVA_JOB_PRIORITY="medium"
    export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
    export BOOT_URL_COMP=
    export LXC_BOOT_FILE=$(basename ${BOOT_URL})
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_FILE}
    export ROOTFS_URL_COMP="gz"
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_FILE} .gz)

    create_testing_variables_file out/submit_for_testing_rootfs.yaml

    cd lava-test-plans
    ./submit_for_testing.py \
        --device-type ${LAVA_DEVICE_TYPE} \
        --build-number ${KERNEL_DESCRIBE} \
        --lava-server ${LAVA_SERVER} \
        --qa-server ${QA_SERVER} \
        --qa-server-team qcomlt \
        --qa-server-project ${QA_SERVER_PROJECT} \
        --testplan-device-path projects/lt-qcom/devices \
        ${DRY_RUN} \
        --test-case testcases/kernel-smoke.yaml \
        --variables ../out/submit_for_testing_rootfs.yaml
    cd ..
  fi

  if [ $DESKTOP_TEST_CASE = true ] || [ $MULTIMEDIA_TEST_CASE = true ]; then
    export LAVA_JOB_PRIORITY="medium"
    export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
    export BOOT_URL_COMP=
    export LXC_BOOT_FILE=$(basename ${BOOT_URL})
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_DESKTOP_FILE}
    export ROOTFS_URL_COMP="gz"
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_DESKTOP_FILE} .gz)

    create_testing_variables_file out/submit_for_testing_rootfs_desktop.yaml
  fi

  if [ $DESKTOP_TEST_CASE = true ]; then
    cd lava-test-plans
    ./submit_for_testing.py \
        --device-type ${LAVA_DEVICE_TYPE} \
        --build-number ${KERNEL_DESCRIBE} \
        --lava-server ${LAVA_SERVER} \
        --qa-server ${QA_SERVER} \
        --qa-server-team qcomlt \
        --qa-server-project ${QA_SERVER_PROJECT} \
        --testplan-device-path projects/lt-qcom/devices \
        ${DRY_RUN} \
        --test-case testcases/kernel-desktop.yaml \
        --variables ../out/submit_for_testing_rootfs_desktop.yaml
    cd ..
  fi

  if [ $MULTIMEDIA_TEST_CASE = true ]; then
    cd lava-test-plans
    ./submit_for_testing.py \
        --device-type ${LAVA_DEVICE_TYPE} \
        --build-number ${KERNEL_DESCRIBE} \
        --lava-server ${LAVA_SERVER} \
        --qa-server ${QA_SERVER} \
        --qa-server-team qcomlt \
        --qa-server-project ${QA_SERVER_PROJECT} \
        --testplan-device-path projects/lt-qcom/devices \
        ${DRY_RUN} \
        --test-case testcases/kernel-multimedia.yaml \
        --variables ../out/submit_for_testing_rootfs_desktop.yaml
    cd ..
  fi
fi
