#!/bin/bash

set -xe

cd $WORKSPACE

rm -rf *.sh configs

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cp configs/ldcg-python-manylinux-tensorflow/build-manylinux2014-wheels.sh .

# 00:01:17.010 /usr/local/bin/manylinux-entrypoint: line 8: /tmp/wheels/build-manylinux2014-wheels.sh: Permission denied
chmod 755 build-manylinux2014-wheels.sh

if [ "$build115" = "true" ]; then
    echo '  - "1.15"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars.yml
fi
if [ "$build24" = "true" ]; then
    echo '  - "2.4"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars.yml
fi
if [ "$build25" = "true" ]; then
    echo '  - "2.5"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars.yml
fi
if [ "$build26" = "true" ]; then
    echo '  - "2.6"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars.yml
fi
if [ "$buildgit" = "true" ]; then
    echo '  - "git"' >> configs/ldcg-python-manylinux-tensorflow/ansible/vars/vars.yml
fi

docker run --rm -u root --security-opt seccomp=unconfined -v $PWD:/tmp/workspace quay.io/pypa/manylinux2014_aarch64 /tmp/workspace/build-manylinux2014-wheels.sh
