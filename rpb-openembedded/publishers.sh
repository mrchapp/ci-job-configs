#!/bin/bash

if [ -f ${WORKSPACE}/BUILD-INFO.txt ];then
    BUILD_INFO="--build-info ${WORKSPACE}/BUILD-INFO.txt"
else
    BUILD_INFO=""
fi

if [ -z "${DEPLOY_DIR_IMAGE}" ] || [ -z "${PUB_DEST}" ] || [ -z "${PUBLISH_SERVER}" ]
then
    echo "== missing publishing variables =="
    echo "DEPLOY_DIR_IMAGE = ${DEPLOY_DIR_IMAGE}"
    echo "PUB_DEST         = ${PUB_DEST}"
    echo "PUBLISH_SERVER   = ${PUBLISH_SERVER}"
    exit 1
fi

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  ${BUILD_INFO} \
  ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}

# Some (most?) of our OE jobs publish images in a $DISTRO subfolder, so we need
# to strip the folder when we create the 'latest' link
# However some job, build a single distro, and there is no such subfolder, in which
# case we want to link to use PUB_DEST directly.

# Warning. Bashism here. But we use bash, so.. use Bash regexp to catch if PUB_DEST
# ends with BUILD_NUMBER or not, and we catch trailing '/' just in case it's there
if [[ "$PUB_DEST" =~ ^.*/${BUILD_NUMBER}/?$ ]]; then
    time python3 ${HOME}/bin/linaro-cp.py \
	 --server ${PUBLISH_SERVER} \
	 --make-link ${PUB_DEST}
else
    time python3 ${HOME}/bin/linaro-cp.py \
	 --server ${PUBLISH_SERVER} \
	 --make-link $(dirname ${PUB_DEST})
fi
