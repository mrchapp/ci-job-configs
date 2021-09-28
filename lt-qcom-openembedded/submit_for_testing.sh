#!/bin/bash

set -ex

# Create variables file to use with lava-test-plans submit_for_testing.py
function create_testing_variables_file () {
	cat << EOF > $1
"LAVA_JOB_PRIORITY": "$LAVA_JOB_PRIORITY"

"PROJECT": "projects/lt-qcom/"
"PROJECT_NAME": "lt-qcom"
"OS_INFO": "$OS_INFO"

"BUILD_URL": "$BUILD_URL"
"BUILD_NUMBER": "$BUILD_NUMBER"

"DEPLOY_OS": "$DEPLOY_OS"
"BOOT_URL": "$BOOT_URL"
"BOOT_URL_COMP": "$BOOT_URL_COMP"
"LXC_BOOT_FILE": "$LXC_BOOT_FILE"
"ROOTFS_URL": "$ROOTFS_URL"
"ROOTFS_URL_COMP": "$ROOTFS_URL_COMP"
"LXC_ROOTFS_FILE": "$LXC_ROOTFS_FILE"

"SMOKE_TESTS": "$SMOKE_TESTS"
"WIFI_SSID_NAME": "LAVATESTX"
"WIFI_SSID_PASSWORD": "NepjqGbq"
"WLAN_DEVICE": "$WLAN_DEVICE"
"WLAN_TIME_DELAY": "$WLAN_TIME_DELAY"
"ETH_DEVICE": "$ETH_DEVICE"
"PM_QA_TESTS": "$PM_QA_TESTS"
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

# main parameters
export DEPLOY_OS=oe
export OS_INFO=openembedded-${DISTRO}-${MANIFEST_BRANCH}
export QA_SERVER_PROJECT=openembedded-rpb-${MANIFEST_BRANCH}

# boot and rootfs parameters, BOOT_URL comes from builders.sh
# and has not compression
export BOOT_URL_COMP=
export LXC_BOOT_FILE=$(basename ${BOOT_URL})

export LAVA_JOB_PRIORITY="medium"

case "${MACHINE}" in
  dragonboard-410c|dragonboard-820c|dragonboard-845c)
    export DEVICE_TYPE="${MACHINE}"

    # Tests settings, thermal fails in db410c
    if [ ${DEVICE_TYPE} = "dragonboard-410c" ]; then
      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"
    elif [ ${DEVICE_TYPE} = "dragonboard-820c" ]; then
      export PM_QA_TESTS="cpufreq cputopology"
      export WLAN_DEVICE="wlp1s0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enP2p1s0"
    elif [ ${DEVICE_TYPE} = "dragonboard-845c" ]; then
      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enp1s0u3"
    fi
    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk"

    create_testing_variables_file out/submit_for_testing.yaml
    case "${DISTRO}" in
      rpb)
        export ROOTFS_URL=${ROOTFS_SPARSE_BUILD_URL}
        export ROOTFS_URL_COMP="gz"
        export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)

        cd lava-test-plans
        ./submit_for_testing.py \
            --device-type ${DEVICE_TYPE} \
            --build-number ${BUILD_NUMBER} \
            --lava-server ${LAVA_SERVER} \
            --qa-server ${QA_SERVER} \
            --qa-server-team qcomlt \
            --qa-server-project ${QA_SERVER_PROJECT} \
            --testplan-device-path projects/lt-qcom/devices \
            ${DRY_RUN} \
            --test-case testcases/distro-smoke.yaml testcases/bt.yaml testcases/wifi.yaml \
            --variables ../out/submit_for_testing.yaml
      ;;
      rpb-wayland)
        echo "Currently no tests for rpb-wayland"
      ;;
    esac
    ;;
  *)
    echo "Skip DEVICE_TYPE for ${MACHINE}"
    ;;
esac
