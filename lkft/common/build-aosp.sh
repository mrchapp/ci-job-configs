#!/bin/bash -ex

export PATH=${HOME}/bin:${PATH}
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

#BUILD_CONFIG_FILENAME=aosp-master-x15
#KERNEL_REPO_URL=/data/android/aosp-mirror/kernel/omap.git
#OPT_MIRROR="-m /data/android/aosp-mirror/platform/manifest.git"
#BUILD_ROOT="/data/android/aosp/pure-master/test-x15-lkft"
#CLEAN_UP=false
#IN_JENKINS=false

BUILD_ROOT="${BUILD_ROOT:-/home/buildslave/srv/aosp-public}"
OPT_MIRROR="${OPT_MIRROR:-}"
CLEAN_UP=${CLEAN_UP:-true}

ANDROID_ROOT="${BUILD_ROOT}/build/aosp"
KERNEL_ROOT="${BUILD_ROOT}/build/kernel"
DIR_PUB_SRC="${BUILD_ROOT}/dist"
AOSP_REPO_BACKUP="${BUILD_ROOT}/aosp-repo-backup"
ANDROID_IMAGE_FILES="boot.img dtb.img dtbo.img super.img vendor.img product.img system.img system_ext.img vbmeta.img userdata.img ramdisk.img ramdisk-debug.img recovery.img cache.img"
ANDROID_IMAGE_FILES="${ANDROID_IMAGE_FILES} vendor_boot-debug.img vendor_boot.img"

# functions for clean the environemnt before repo sync and build
function prepare_environment(){
    if [ ! -d "${BUILD_ROOT}" ]; then
      sudo mkdir -p "${BUILD_ROOT}"
      sudo chmod 777 "${BUILD_ROOT}"
    fi
    cd "${BUILD_ROOT}"

    # clean manifest files under ${ANDROID_ROOT}
    rm -rf "${ANDROID_ROOT}/.repo/manifests" "${ANDROID_ROOT}/.repo/manifests.git" "${ANDROID_ROOT}/.repo/manifests.xml" "${ANDROID_ROOT}/.repo/local_manifests" "${ANDROID_ROOT}/build-tools" "${ANDROID_ROOT}/jenkins-tools"

    # clean the build directory as it is used accross multiple builds
    # by removing all files except the .repo directory
    if ${CLEAN_UP}; then
        rm -fr "${AOSP_REPO_BACKUP}"
        if [ -d "${ANDROID_ROOT}/.repo" ]; then
            mv -f "${ANDROID_ROOT}/.repo" "${AOSP_REPO_BACKUP}"
        fi
        rm -fr "${ANDROID_ROOT}" && mkdir -p "${ANDROID_ROOT}"
        if [ -d "${AOSP_REPO_BACKUP}" ]; then
            mv -f "${AOSP_REPO_BACKUP}" "${ANDROID_ROOT}/.repo"
        fi
    fi
}

###############################################################
# Build the kernel images that would be used for the userspace
# All operations following should be done under ${KERNEL_ROOT}
###############################################################
function build_kernel(){
    if [ -z "${KERNEL_BUILD_CONFIG}" ]; then
        return
    fi
    rm -fr "${KERNEL_ROOT}" && mkdir -p "${KERNEL_ROOT}" && cd "${KERNEL_ROOT}"
    wget https://android-git.linaro.org/android-build-configs.git/plain/lkft/linaro-lkft.sh?h=lkft -O linaro-lkft.sh
    chmod +x linaro-lkft.sh
    ./linaro-lkft.sh -c "${KERNEL_BUILD_CONFIG}" -obk
}
###############################################################
# Build Android userspace images
# All operations following should be done under ${ANDROID_ROOT}
###############################################################
function build_android(){
    mkdir -p "${ANDROID_ROOT}" && cd "${ANDROID_ROOT}"
    rm -fr "${DIR_PUB_SRC}" && mkdir -p "${DIR_PUB_SRC}"
    rm -fr "${ANDROID_ROOT}/out/pinned-manifest"

    rm -fr android-build-configs linaro-build.sh
    wget -c https://android-git.linaro.org/android-build-configs.git/plain/linaro-build.sh -O linaro-build.sh
    chmod +x linaro-build.sh
    if [ -n "${ANDROID_BUILD_CONFIG}" ]; then
        bash -ex ./linaro-build.sh -c "${ANDROID_BUILD_CONFIG}"
        # ${ANDROID_BUILD_CONFIG} will be repo synced after build
        # shellcheck source=/dev/null
        source "android-build-configs/${ANDROID_BUILD_CONFIG}"
        export TARGET_PRODUCT
    elif [ -n "${TARGET_PRODUCT}" ]; then
        local opt_manfest_branch="-b master"
        local opt_maniefst_url="https://android.googlesource.com/platform/manifest"
        [ -n "${MANIFEST_BRANCH}" ] && opt_manfest_branch="-b ${MANIFEST_BRANCH}"
        [ -n "${MANIFEST_URL}" ] && opt_maniefst_url="-m ${MANIFEST_URL}"
        [ -n "${MAKE_TARGETS}" ] && export MAKE_TARGETS
        # shellcheck disable=SC2086
        bash -ex ./linaro-build.sh -tp "${TARGET_PRODUCT}" ${opt_maniefst_url} ${opt_manfest_branch}
    fi
    if [ "X${TARGET_PRODUCT}X" = "Xaosp_arm64X" ]; then
        # for cts vts
        DIR_PUB_SRC_PRODUCT="${ANDROID_ROOT}/out/target/product/generic_arm64"
    else
        DIR_PUB_SRC_PRODUCT="${ANDROID_ROOT}/out/target/product/${TARGET_PRODUCT}"
    fi

    mkdir -p "${DIR_PUB_SRC}"
    # shellcheck disable=SC2086
    cp -a ${ANDROID_ROOT}/out/pinned-manifest/*-pinned-manifest.xml "${DIR_PUB_SRC}/pinned-manifest.xml"
    wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O "${DIR_PUB_SRC}/BUILD-INFO.txt"

    if [ -z "${PUBLISH_FILES}" ]; then
        PUBLISH_FILES="${ANDROID_IMAGE_FILES}"
    fi

    for f in ${PUBLISH_FILES}; do
        if [ "X${f}X" = "Xandroid-cts.zipX" ]; then
            f_src_path="${ANDROID_ROOT}/out/host/linux-x86/cts/android-cts.zip"
        elif [ "X${f}X" = "Xandroid-vts.zipX" ]; then
            f_src_path="${ANDROID_ROOT}/out/host/linux-x86/vts/android-vts.zip"
        else
            f_src_path="${DIR_PUB_SRC_PRODUCT}/${f}"
        fi

        if [ ! -f "${f_src_path}" ]; then
            continue
        else
            mv -vf "${f_src_path}" "${DIR_PUB_SRC}/${f}"
        fi

        if [ "Xramdisk.img" = "X${f}" ] || [ "Xramdisk-debug.img" = "X${f}" ] || [ "Xandroid-cts.zip" = "X${f}" ] || [ "Xandroid-vts.zip" = "X${f}" ]; then
            # files no need to compress
            continue
        else
            xz -T 0 "${DIR_PUB_SRC}/${f}"
        fi
    done

    if [ -f "${DIR_PUB_SRC_PRODUCT}/build_fingerprint.txt" ]; then
        cp -vf "${DIR_PUB_SRC_PRODUCT}/build_fingerprint.txt" "${DIR_PUB_SRC}/"
    fi

    if [ -n "${ANDROID_BUILD_CONFIG}" ]; then
        cp -vf "android-build-configs/${ANDROID_BUILD_CONFIG}" "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
    else
        ANDROID_BUILD_CONFIG="build-config"
        rm -f "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
        [ -n "${TARGET_PRODUCT}" ] && echo "TARGET_PRODUCT=${TARGET_PRODUCT}" >> "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
        [ -n "${MANIFEST_BRANCH}" ] && echo "MANIFEST_BRANCH=${MANIFEST_BRANCH}" >> "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
        [ -n "${MANIFEST_URL}" ] && echo "MANIFEST_URL=${MANIFEST_URL}" >> "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
        [ -n "${MAKE_TARGETS}" ] && echo "MAKE_TARGETS=${MAKE_TARGETS}" >> "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
        [ -n "${PUBLISH_FILES}" ] && echo "PUBLISH_FILES=${PUBLISH_FILES}" >> "${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt"
    fi
    cd "${DIR_PUB_SRC}" && md5sum ./* > "MD5SUM.txt"
}

# clean workspace to save space
function clean_workspace(){
    # Delete sources after build to save space
    rm -fr "${ANDROID_ROOT}"
}

# export parameters for publish/job submission steps
function export_parameters(){
    if [ "X${f}X" = "Xandroid-cts.zipX" ]; then
        PUB_DEST_TARGET="android-cts"
    elif [ "X${f}X" = "Xandroid-vts.zipX" ]; then
        PUB_DEST_TARGET="android-vts"
    elif [ "X${TARGET_PRODUCT}" = "Xbeagle_x15" ]; then
        # beagle_x15 could not used as part of the url for snapshot site
        PUB_DEST_TARGET=x15
    else
        PUB_DEST_TARGET=${TARGET_PRODUCT}
    fi

    # Publish parameters
    # The pinned-manifest was copied into the publist directory as pinned-manifest.xml already
    cp -a "${DIR_PUB_SRC}/pinned-manifest.xml" "${WORKSPACE}/"
    echo "PUB_DEST=android/lkft/${PUB_DEST_TARGET}/${BUILD_NUMBER}" > "${WORKSPACE}/publish_parameters"
    echo "PUB_SRC=${DIR_PUB_SRC}" >> "${WORKSPACE}/publish_parameters"
    echo "PUB_EXTRA_INC=^[^/]+\.(txt|img|xz|dtb|dtbo|zip)$|MLO|vmlinux|System.map" >> "${WORKSPACE}/publish_parameters"
}

function main(){
    prepare_environment
    if [ -n "${KERNEL_BUILD_CONFIG}" ]; then
        build_kernel
        export LOCAL_KERNEL_HOME=${KERNEL_ROOT}/out/${KERNEL_BUILD_CONFIG}/vendor-kernel/dist
        kernel_ver=$(grep GKI_KERNEL_MAKEVERSION ${KERNEL_ROOT}/out/${KERNEL_BUILD_CONFIG}/misc_info.txt|cut -d= -f2)
        if [ -z "${kernel_ver}" ]; then
            kernel_ver=$(grep VENDOR_KERNEL_MAKEVERSION ${KERNEL_ROOT}/out/${KERNEL_BUILD_CONFIG}/misc_info.txt|cut -d= -f2 )
        fi
        export TARGET_KERNEL_USE=${kernel_ver}
    fi
    build_android

    if ${IN_JENKINS} && [ -n "${WORKSPACE}" ]; then
        export_parameters
        clean_workspace
    fi
}

main "$@"
