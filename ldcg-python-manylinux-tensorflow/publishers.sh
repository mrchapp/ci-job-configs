#!/bin/bash

# First publish wheels to cache

COPY_FROM=${WORKSPACE}/cache_upload/
PUBLISH_TO=ldcg/python-cache/

set -ex

ls -alR $COPY_FROM

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py

time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  $COPY_FROM \
  $PUBLISH_TO || true

echo "Python wheels: https://snapshots.linaro.org/${PUBLISH_TO}"

# Now is time to upload tensorflow

if [ `echo $JOB_NAME | cut -d'/' -f1` == 'ldcg-python-manylinux-tensorflow-nightly' ]; then
  OUTPUT_PATH="ldcg/python/tensorflow-manylinux-nightly/$(date -u +%Y%m%d)-${BUILD_NUMBER}/"
else
  OUTPUT_PATH="ldcg/python/tensorflow-manylinux/${BUILD_NUMBER}/"
fi

time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  /${WORKSPACE}/wheels \
  $OUTPUT_PATH || true

echo "Python wheels: https://snapshots.linaro.org/$OUTPUT_PATH"
