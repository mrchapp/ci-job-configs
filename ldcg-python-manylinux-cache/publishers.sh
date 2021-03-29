#!/bin/bash

COPY_FROM=${WORKSPACE}/wheels/
PUBLISH_TO=ldcg/python-cache/

set -ex

ls -alR $COPY_FROM

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  $COPY_FROM \
  $PUBLISH_TO

set +x

echo "Python wheels: https://snapshots.linaro.org/${PUBLISH_TO}"
