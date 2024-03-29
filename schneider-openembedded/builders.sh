#!/bin/bash
set -e

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "Running cleanup_exit..."
}

replace_dmverity_var()
{
	local variable
	local localconf
	local newvalue

	variable="DM_VERITY_IMAGE_NAME"
	localconf="conf/local.conf"
	newvalue="${1}"

	sed -i 's/'${variable}' ?=.*/'${variable}' ?= "'${newvalue}'"/' ${localconf}
	grep ${variable} ${localconf} || true
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip android-tools-fsutils chrpath cpio diffstat gawk gfortran libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml (version pinned for Python-2.7 compat)
pip install --user 'ruamel.yaml.clib==0.2.2'
pip install --user 'ruamel.yaml<0.17'

set -ex

#DEL mkdir -p ${HOME}/bin
#DEL curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
#DEL chmod a+x ${HOME}/bin/repo
#DEL export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   #DEL repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   sstatecache=${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
   if [[ "${IMAGES}" == *clean* ]]; then
     rm -rf ${sstatecache}
   fi
   mkdir -p ${HOME}/srv/oe/downloads ${sstatecache}
   #DEL mkdir -p build
   #DEL ln -s ${HOME}/srv/oe/downloads
   #DEL ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
fi


#DEL if [ "${ghprbPullId}" ]; then
#DEL     echo "Applying Github pull-request #${ghprbPullId} from ${ghprbGhRepository}"
#DEL     sed -i -e "s|name=\"${ghprbGhRepository}\"|name=\"${ghprbGhRepository}\" revision=\"refs/pull/${ghprbPullId}/head\"|" .repo/manifest.xml
#DEL fi

#DEL repo sync
#DEL cp .repo/manifest.xml source-manifest.xml
#DEL repo manifest -r -o pinned-manifest.xml
#DEL MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

#DEL  record changes since last build, if available
#DEL if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
#DEL     repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
#DEL else
#DEL     echo "latest build published does not have pinned-manifest.xml, skipping diff report"
#DEL fi

#DEL if [ -n "$GERRIT_PROJECT" ] && [ $GERRIT_EVENT_TYPE == "patchset-created" ]; then
#DEL     GERRIT_URL="http://${GERRIT_HOST}/${GERRIT_PROJECT}"
#DEL     cd `grep -rni $GERRIT_PROJECT\" .repo/manifest.xml | grep -Po 'path="\K[^"]*'`
#DEL     if git pull ${GERRIT_URL} ${GERRIT_REFSPEC} | grep -q "Automatic merge failed"; then
#DEL         git reset --hard
#DEL         echo "Error: *** Error patch merge failed"
#DEL         exit 1
#DEL     fi
#DEL     cd -
#DEL fi

# RFS 2021/04/02 workaround "Host key verification failed" on github cloud
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"

git clone ${DISTRO_URL_BASE}/${DISTRO_DIR} -b ${MANIFEST_BRANCH}
cd ${DISTRO_DIR}
git log -1
git submodule init
git submodule update

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
#DEL rm -rf conf build/conf build/tmp/

# Accept EULA if/when needed
#DEL export EULA_dragonboard410c=1
#DEL export EULA_stih410b2260=1
#DEL source setup-environment build

# Set the machine to the value expected by the Yocto environment
# We set it back again later
machine_orig=${MACHINE}
case "${MACHINE}" in
  *rzn1*)
    MACHINE=rzn1d400-bestla
    ;;
  *soca9*)
    MACHINE=snarc-soca9
    ;;
esac

# SUBMODULES is set to:
#	none		no update
#	''		update default set in setup-env...
#	all		tell setup-env... to update all submodules
#	'<something>'	pass the variable to submodule update
if [[ ${MANIFEST_BRANCH} == linaro-* ]];
then
	if [[ "${SUBMODULES}" != "none" ]]; then
	  ./setup-environment -s build-${machine_orig}/
	fi
fi

source ./setup-environment build-${machine_orig}/

ln -s ${HOME}/srv/oe/downloads
ln -s ${sstatecache} sstate-cache

# Add job BUILD_NUMBER to output files names, overriding the
# default suffix of "-${DATETIME}" from bitbake.conf
cat << EOF >> conf/auto.conf
IMAGE_VERSION_SUFFIX = "-${BUILD_NUMBER}"
EOF

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF

# Make sure we don't use rm_work in CI slaves since they are non persistent build nodes
cat << EOF >> conf/auto.conf
INHERIT_remove = "rm_work"
EOF

# allow the top level job to append to auto.conf
if [ -f ${WORKSPACE}/auto.conf ]; then
    cat ${WORKSPACE}/auto.conf >> conf/auto.conf
fi

# add useful debug info
cat conf/auto.conf

[ "${DISTRO}" = "rpb" ] && IMAGES+=" ${IMAGES_RPB}"
[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" ${IMAGES_RPB_WAYLAND}"

# These machines only build the basic rpb-console-image
case "${MACHINE}" in
  am57xx-evm|intel-core2-32|intel-corei7-64)
     IMAGES="rpb-console-image"
     ;;
esac

postfile=$(mktemp /tmp/postfile.XXXXX.conf)
echo KERNEL_VERSION_PATCHLEVEL = \"${KERNEL_VERSION_PATCHLEVEL}\" > ${postfile}
echo PREFERRED_VERSION_linux-rzn1 = \"${KERNEL_VERSION_PATCHLEVEL}.%\" >> ${postfile}
echo PREFERRED_VERSION_linux-socfpga = \"${KERNEL_VERSION_PATCHLEVEL}.%\" >> ${postfile}
cat ${postfile}
bbopt="-R ${postfile}"

if [ "${clean_packages}" != "" ]; then
    bitbake ${bbopt} -c cleansstate ${clean_packages}
    bitbake ${bbopt} ${build_packages}
fi

# Cleanup mbedtls/edgeagent repos, the gitsm fetcher gets confused easily
#rm -rf ${HOME}/srv/oe/downloads/git2/*mbedtls*
#rm -rf ${HOME}/srv/oe/downloads/git2/*optiga*
#rm -rf ${HOME}/srv/oe/downloads/git2/*EdgeAgent*
#rm -rf ${HOME}/srv/oe/downloads/git2/*Azure*
#rm -rf ${HOME}/srv/oe/downloads/git2/*Microsoft*
#rm -rf ${HOME}/srv/oe/downloads/git2/*kgabis.parson*
#bitbake ${bbopt} -c cleansstate mbedtls edgeagent

# Build all ${IMAGES}
dipimg="prod-image"
devimg="dev-image"
sdkimg="sdk-image"

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

if [[ "${IMAGES}" == *"${dipimg}"* ]]; then
	replace_dmverity_var "${dipimg}"

	grep -c ^processor /proc/cpuinfo
	grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}'

	time bitbake ${bbopt} ${dipimg}

	# Make a copy of the CVE report using a fixed filename, because:
	# 1) later invocations of bitbake may overwrite the report, and
	# 2) facilitate later retrieval from snapshots.linaro.org via "latest" link.
	cp ${DEPLOY_DIR_IMAGE}/${dipimg}-${MACHINE}.cve ${DEPLOY_DIR_IMAGE}/${dipimg}-${MACHINE}.rootfs.cve

	case "${MACHINE}" in
		*rzn1*)
			cat tmp/work-shared/${MACHINE}/dm-verity/prod-image.squashfs-lzo.verity.env || true
			;;
	esac

	ls -al ${DEPLOY_DIR_IMAGE} || true
	ls -al ${DEPLOY_DIR_IMAGE}/optee || true
	ls -al ${DEPLOY_DIR_IMAGE}/cm3 || true
	ls -al ${DEPLOY_DIR_IMAGE}/u-boot || true
	ls -al ${DEPLOY_DIR_IMAGE}/fsbl || true

	# Copy license and manifest information into the deploy dir
	cp -aR ./tmp/deploy/licenses/prod-image-*/*.manifest ${DEPLOY_DIR_IMAGE}
fi

if [[ "${IMAGES}" == *"${devimg}"* ]]; then
	replace_dmverity_var ""
	time bitbake ${bbopt} ${devimg} || true
	tar zcf ${DEPLOY_DIR_IMAGE}/edgeagent-debug.tar.gz tmp/*/*/edgeagent downloads/git2/*EdgeAgent* downloads/git2/*cmocka* downloads/git2/*Azure* downloads/git2/*Microsoft* downloads/git2/*kgabis* || true

	# Make a copy of the CVE report using a fixed filename
	cp ${DEPLOY_DIR_IMAGE}/${devimg}-${MACHINE}.cve ${DEPLOY_DIR_IMAGE}/${devimg}-${MACHINE}.rootfs.cve || true

	ls -al ${DEPLOY_DIR_IMAGE} || true
	ls -al ${DEPLOY_DIR_IMAGE}/cm3 || true
	ls -al ${DEPLOY_DIR_IMAGE}/u-boot || true
	ls -al ${DEPLOY_DIR_IMAGE}/fsbl || true
	ls -al ${DEPLOY_DIR_IMAGE}/optee || true

	time bitbake ${bbopt} ${sdkimg} || true

	# Make a copy of the CVE report using a fixed filename
	cp ${DEPLOY_DIR_IMAGE}/${sdkimg}-${MACHINE}.cve ${DEPLOY_DIR_IMAGE}/${sdkimg}-${MACHINE}.rootfs.cve || true

	DEPLOY_DIR_SDK=$(bitbake -e | grep "^DEPLOY_DIR="| cut -d'=' -f2 | tr -d '"')/sdk
	cp -aR ${DEPLOY_DIR_SDK} ${DEPLOY_DIR_IMAGE} || true
fi

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
#DEL mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
#DEL cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

### Begin CVE check

if [ -e ${DEPLOY_DIR_IMAGE}/${dipimg}-${MACHINE}.rootfs.cve ] ; then

	# Get the current CVE report
	cp ${DEPLOY_DIR_IMAGE}/${dipimg}-${MACHINE}.rootfs.cve cve-${MACHINE}.new

	# Fetch previous CVE report
	LATEST_DEST=$(echo $PUB_DEST | sed -e "s#/$BUILD_NUMBER/#/latest/#")
	rm -f cve-${MACHINE}.old
	wget -nv -O cve-${MACHINE}.old ${BASE_URL}/${LATEST_DEST}/prod-image-${MACHINE}.rootfs.cve || true

	# Download may fail (404 error), or might not contain the report (auth error)
	if ! grep -q "PACKAGE NAME" cve-${MACHINE}.old 2>/dev/null; then
		# Use current CVE list, to avoid diff-against-nothing
		cp cve-${MACHINE}.new cve-${MACHINE}.old
		# Append a fake entry that will appear in the diff
		cat <<-EOF >>cve-${MACHINE}.old
		PACKAGE NAME: failed-to-download-previous-CVEs
		PACKAGE VERSION: 0.0
		CVE: CVE-xxxx-yyyy
		CVE STATUS: Unpatched
		CVE SUMMARY: Unable to download CVE results for previous build. Comparison disabled.
		CVSS v2 BASE SCORE: 0.0
		CVSS v3 BASE SCORE: 0.0
		VECTOR: LOCAL
		MORE INFORMATION: none
		EOF
	fi

	# Do diffs between old and current CVE report.
	wget -nv -O diff-cve https://git.linaro.org/ci/job/configs.git/plain/schneider-openembedded/diff-cve
	gawk -f diff-cve cve-${MACHINE}.old cve-${MACHINE}.new | tee ${WORKSPACE}/cve-${MACHINE}.txt

	# Same thing, but against arbitrary (but fixed) baseline
	case "${MACHINE}" in
		*rzn1*)
		wget -nv -O cve-${MACHINE}.base https://releases.linaro.org/members/schneider/openembedded/2021.08.dunfell/rzn1d-5.10/prod-image-rzn1d400-bestla.rootfs.cve
		;;
		*soca9*)
		wget -nv -O cve-${MACHINE}.base https://releases.linaro.org/members/schneider/openembedded/2021.08.dunfell/soca9-5.10/prod-image-snarc-soca9.rootfs.cve
		;;
	esac
	gawk -f diff-cve cve-${MACHINE}.base cve-${MACHINE}.new > ${WORKSPACE}/base-cve-${MACHINE}.txt
fi

### End CVE check

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4 \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.iso \
      ${DEPLOY_DIR_IMAGE}/*.iso \
      ${DEPLOY_DIR_IMAGE}/*.jffs* \
      ${DEPLOY_DIR_IMAGE}/*.cpio.gz \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  *rzn1*)
    pushd ${DEPLOY_DIR_IMAGE}
    rm -f uImage*
    popd
    ;;
  *soca9*)
    # re-create the SoCA9 DTB with a shorter filename
    pushd ${DEPLOY_DIR_IMAGE}
    mv zImage-*soca9*_bestla_512m*.dtb zImage-soca9_qspi_micronN25Q_bestla_512m.dtb || true
    mv zImage-*soca9*.dtb zImage-soca9_qspi_micronN25Q_bestla_512m.dtb || true
    rm -f *[12]G*.dtb || true
    rm -f *freja*.dtb || true
    rm -f *socfpga_cyclone5_socdk*.dtb || true
    popd
    ;;
  juno|stih410-b2260|orangepi-i96)
    ;;
  *)
    for rootfs in $(find ${DEPLOY_DIR_IMAGE} -type f -name *.rootfs.ext4.gz); do
      gunzip -k ${rootfs}
      sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
      rm -f ${rootfs%.gz}
      gzip -9 ${rootfs%.ext4.gz}.img
    done
    ;;
esac

ls -al ${DEPLOY_DIR_IMAGE}/*

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. Reference Platform Build - CE OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":${MANIFEST_URL/.git/\/commit}/${MANIFEST_COMMIT}
EOF

if [ -e "/srv/oe/manifest-changes.txt" ]; then
  # the space after pre.. tag is on purpose
  cat > ${DEPLOY_DIR_IMAGE}/README.textile << EOF

h4. Manifest changes

pre.. 
EOF
  cat /srv/oe/manifest-changes.txt >> ${DEPLOY_DIR_IMAGE}/README.textile
  mv /srv/oe/manifest-changes.txt ${DEPLOY_DIR_IMAGE}
fi

# Identify snapshots as public
touch ${DEPLOY_DIR_IMAGE}/OPEN-EULA.txt

# Need different files for each machine
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_DESKTOP_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-desktop-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*-*rzn1*-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm)
    # LAVA image is too big for am57xx-evm
    ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
    # FIXME: several dtb files case
    ;;
  intel-core2-32|intel-corei7-64)
    # No LAVA testing on intel-core* machines
    ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
    ;;
  juno)
    # FIXME: several dtb files case
    ;;
  *rzn1*)
    ROOTFS_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "prod-image-${MACHINE}-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_DEV_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-${MACHINE}-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    WIC_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-rzn1*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-rzn1*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)

    # The following images will have their size reported to SQUAD
    UBOOT=$(find ${DEPLOY_DIR_IMAGE}/u-boot -type f -name "u-boot-${MACHINE}-${BUILD_NUMBER}.bin.spkg")
    UBOOT_IMG=$(basename ${UBOOT})
    UBOOT_FIT=$(find ${DEPLOY_DIR_IMAGE}/u-boot -type f -name "u-boot-${MACHINE}-${BUILD_NUMBER}.itb")
    UBOOT_FIT_IMG=$(basename ${UBOOT_FIT})
    DTB=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*rzn1*bestla*.dtb")
    DTB_IMG=$(basename ${DTB})
    KERNEL=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage--*rzn1*.bin")
    KERNEL_IMG=$(basename ${KERNEL})
    KERNEL_FIT=$(find ${DEPLOY_DIR_IMAGE} -type f -name "fitImage*.itb")
    KERNEL_FIT_IMG=$(basename ${KERNEL_FIT})
    FSBL=$(find ${DEPLOY_DIR_IMAGE}/fsbl -type f -name "fsbl-fip-${MACHINE}-${BUILD_NUMBER}.spkg")
    FSBL_IMG=$(basename ${FSBL})
    OPTEE_FIT=$(find ${DEPLOY_DIR_IMAGE}/optee -type f -name "optee-os-${MACHINE}-${BUILD_NUMBER}.itb")
    OPTEE_FIT_IMG=$(basename ${OPTEE_FIT})
    UBI=$(find ${DEPLOY_DIR_IMAGE} -type f -name "prod-image-${MACHINE}-${BUILD_NUMBER}.rootfs.fitubi")
    UBI_IMG=$(basename ${UBI})
    WIC_DEV=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-${MACHINE}-${BUILD_NUMBER}.rootfs.wic.bz2")
    WIC_DEV_IMG=$(basename ${WIC_DEV})
    WIC_DEV_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-${MACHINE}-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    ;;
  *soca9*)
    ROOTFS_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "prod-image-snarc-soca9-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_DEV_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-snarc-soca9*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    WIC_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "prod-image-snarc-soca9-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)

    # The following images will have their size reported to SQUAD
    UBOOT=$(find ${DEPLOY_DIR_IMAGE} -type f -name "u-boot-with-spl-${BUILD_NUMBER}.sfp")
    UBOOT_IMG=$(basename ${UBOOT})
    DTB=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*soca9*.dtb")
    DTB_IMG=$(basename ${DTB})
    KERNEL=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage--*soca9*.bin")
    KERNEL_IMG=$(basename ${KERNEL})
    WIC=$(find ${DEPLOY_DIR_IMAGE} -type f -name "prod-image-snarc-soca9-${BUILD_NUMBER}.rootfs.wic.bz2")
    WIC_IMG=$(basename ${WIC})
    WIC_DEV=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-snarc-soca9-${BUILD_NUMBER}.rootfs.wic.bz2")
    WIC_DEV_IMG=$(basename ${WIC_DEV})
    WIC_DEV_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dev-image-snarc-soca9-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    ;;
  *)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

# Set MACHINE back to the origin value
MACHINE=${machine_orig}

send_image_size_to_squad()
{
    local metric=$1
    local filename=$2
    local image_size=0

    # get file size
    if [ ! -z "{filename}" ] && [ -e "${filename}" ]; then
        image_size=$(stat --printf="%s" ${filename})
    fi

    echo metric=$metric
    echo filename=$(basename $filename)
    echo image_size=$image_size

    # send the metric to SQUAD
    curl --header "Auth-Token: ${QA_REPORTS_TOKEN}" --form metrics='{"'${metric}'": "'${image_size}'"}' ${QA_SERVER}/api/submit/${QA_SERVER_TEAM}/${QA_SERVER_PROJECT}/${BUILD_NUMBER}/${MACHINE}
}

# Send image sizes to SQUAD
# note: we specifically want to report a zero image size if the image doesn't exist
#       this works around a SQUAD bug and allows metrics graphs showing multiple
#       boards to look sane when one of those boards has no values for the metric
send_image_size_to_squad "IMG_SIZE_UBOOT"      "${UBOOT}"
send_image_size_to_squad "IMG_SIZE_UBOOT_FIT"  "${UBOOT_FIT}"
send_image_size_to_squad "IMG_SIZE_DTB"        "${DTB}"
send_image_size_to_squad "IMG_SIZE_KERNEL"     "${KERNEL}"
send_image_size_to_squad "IMG_SIZE_KERNEL_FIT" "${KERNEL_FIT}"
send_image_size_to_squad "IMG_SIZE_FSBL"       "${FSBL}"
send_image_size_to_squad "IMG_SIZE_OPTEE_FIT"  "${OPTEE_FIT}"
send_image_size_to_squad "IMG_SIZE_UBI"        "${UBI}"
send_image_size_to_squad "IMG_SIZE_WIC"        "${WIC}"
send_image_size_to_squad "IMG_SIZE_WIC_DEV"    "${WIC_DEV}"

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
MANIFEST_COMMIT=${BUILD_NUMBER}
ROOTFS_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_IMG}
ROOTFS_DESKTOP_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DESKTOP_IMG}
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
OPTEE_ITB_URL=${BASE_URL}${PUB_DEST}/optee/${OPTEE_FIT_IMG}
FSBL_URL=${BASE_URL}${PUB_DEST}/fsbl/${FSBL_IMG}
UBOOT_ITB_URL=${BASE_URL}${PUB_DEST}/u-boot/${UBOOT_FIT_IMG}
KERNEL_FIT_URL=${BASE_URL}${PUB_DEST}/${KERNEL_FIT_IMG}
KERNEL_ZIMAGE_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
WIC_IMAGE_URL=${BASE_URL}${PUB_DEST}/${WIC_IMG}
WIC_BMAP_URL=${BASE_URL}${PUB_DEST}/${WIC_BMAP}
WIC_DEV_IMAGE_URL=${BASE_URL}${PUB_DEST}/${WIC_DEV_IMG}
WIC_DEV_BMAP_URL=${BASE_URL}${PUB_DEST}/${WIC_DEV_BMAP}
UBI_IMAGE_URL=${BASE_URL}${PUB_DEST}/${UBI_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TAR_BZ2}
NFSROOTFS_DEV_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DEV_TAR_BZ2}
RECOVERY_IMAGE_URL=${BASE_URL}${PUB_DEST}/juno-oe-uboot.zip
LXC_ROOTFS_IMG=$(basename ${ROOTFS_IMG} .gz)
DEVICE_TYPE=${MACHINE}
EOF
