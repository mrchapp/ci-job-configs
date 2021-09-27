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
"ARTIFACTORIAL_TOKEN": "$ARTIFACTORIAL_TOKEN"
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
export LAVA_JOB_PRIORITY="medium"
export OS_INFO=debian-${OS_FLAVOUR}
export DEPLOY_OS=debian
if [ "${DEVICE_TYPE}" = "dragonboard-410c" ] || [ "${DEVICE_TYPE}" = "dragonboard-820c" ] || [ "${DEVICE_TYPE}" = "dragonboard-845c" ]; then
	export QA_SERVER_PROJECT=${DEPLOY_OS}-${DEVICE_TYPE}
else
	echo "Device ${DEVICE_TYPE} not supported for testing"
	exit 0
fi

# boot and rootfs parameters
export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
export BOOT_URL_COMP="gz"
export LXC_BOOT_FILE=$(basename ${BOOT_URL} .gz)
export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${VENDOR}-${OS_FLAVOUR}-alip-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
export ROOTFS_URL_COMP="gz"
export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)

# Tests settings, thermal isn't work well in debian/db410c causes stall
if [ "${DEVICE_TYPE}" = "dragonboard-410c" ]; then
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="0s"
    export ETH_DEVICE="eth0"
elif [ "${DEVICE_TYPE}" = "dragonboard-820c" ]; then
    export PM_QA_TESTS="cpufreq cputopology"
    export WLAN_DEVICE="wlp1s0"
    export WLAN_TIME_DELAY="15s"
    export ETH_DEVICE="enP2p1s0"
elif [ "${DEVICE_TYPE}" = "dragonboard-845c" ]; then
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="15s"
    export ETH_DEVICE="enx000ec6817901"
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"

    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${VENDOR}-${OS_FLAVOUR}-gnome-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)
else
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="0s"
    export ETH_DEVICE="eth0"
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug thermal cputopology"
fi
export SMOKE_TESTS="pwd, lsb_release -a, uname -a, ip a, lscpu, vmstat, lsblk"

create_testing_variables_file out/submit_for_testing.yaml

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

# Submit to PMWG Lava server because it has special hw to do energy probes
./submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${PMWG_LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team qcomlt \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --testplan-device-path projects/lt-qcom/devices \
    ${DRY_RUN} \
    --test-case testcases/pmwg.yaml \
    --variables ../out/submit_for_testing.yaml
