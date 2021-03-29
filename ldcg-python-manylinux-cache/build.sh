#!/bin/bash

COPY_FROM=/home/buildslave/wheels/

set -xe

rm -rf ${WORKSPACE}/*

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-manylinux-cache/

echo "PYTHON_PACKAGES=\"${PYTHON_PACKAGES}\"" >> vars.sh
echo "EXTRA_DEPENDENCIES_CENTOS=\"${EXTRA_DEPENDENCIES_CENTOS}\"" >> vars.sh

# 00:01:17.010 /usr/local/bin/manylinux-entrypoint: line 8: /tmp/wheels/build-manylinux2014-wheels.sh: Permission denied
chmod 755 build-manylinux2014-wheels.sh

docker run -u root -v $PWD:/tmp/wheels quay.io/pypa/manylinux2014_aarch64 /tmp/wheels/build-manylinux2014-wheels.sh

for pkg in wheelhouse/*.whl
do
  pkgdir=$(echo `basename $pkg`|cut -d'-' -f1 | tr '[:upper:]_' '[:lower:]-')

  # do we have this package in cache already?
  status=$(curl --head --silent {{ pip_extra_index_url }}/${pkgdir}/${pkg} | head -n 1)

  if $(echo $status | grep -q 404); then
    mkdir -p "${COPY_FROM}/${pkgdir}"
    mv $pkg  "${COPY_FROM}/${pkgdir}/"
  fi
done
