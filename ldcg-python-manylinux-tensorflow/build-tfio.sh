#!/bin/bash

set -xe

cd $WORKSPACE

rm -rf *.sh configs

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cp configs/ldcg-python-manylinux-tensorflow/build-tfio-manylinux2014-wheels.sh .

# 00:01:17.010 /usr/local/bin/manylinux-entrypoint: line 8: /tmp/wheels/build-manylinux2014-wheels.sh: Permission denied
chmod 755 build-tfio-manylinux2014-wheels.sh

if [ "$buildgit" = "true" ]; then
    echo '  - "git"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars-tfio.yml
fi

docker run --rm -u root --security-opt seccomp=unconfined -v $PWD:/tmp/workspace quay.io/pypa/manylinux2014_aarch64 /tmp/workspace/build-manylinux2014-wheels.sh
