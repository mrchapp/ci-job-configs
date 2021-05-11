#!/bin/bash

set -xe

cd $WORKSPACE

# remove generated vars and build script
rm -f *.sh

wget https://git.linaro.org/ci/job/configs.git/plain/ldcg-python-manylinux-tensorflow/build-manylinux2014-wheels.sh

# 00:01:17.010 /usr/local/bin/manylinux-entrypoint: line 8: /tmp/wheels/build-manylinux2014-wheels.sh: Permission denied
chmod 755 build-manylinux2014-wheels.sh

docker run -u root -v $PWD:/tmp/workspace quay.io/pypa/manylinux2014_aarch64 /tmp/workspace/build-manylinux2014-wheels.sh
