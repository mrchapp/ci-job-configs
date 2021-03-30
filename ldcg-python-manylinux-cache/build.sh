#!/bin/bash

set -xe

cd $WORKSPACE

# remove generated vars and build script
rm -f *.sh

wget https://git.linaro.org/ci/job/configs.git/plain/ldcg-python-manylinux-cache/build-manylinux2014-wheels.sh

echo "PYTHON_PACKAGES=\"${PYTHON_PACKAGES}\"" >> vars.sh
echo "EXTRA_DEPENDENCIES_CENTOS=\"${EXTRA_DEPENDENCIES_CENTOS}\"" >> vars.sh
echo "EXTRA_PYTHON_PACKAGES=\"${EXTRA_PYTHON_PACKAGES}\"" >> vars.sh

# 00:01:17.010 /usr/local/bin/manylinux-entrypoint: line 8: /tmp/wheels/build-manylinux2014-wheels.sh: Permission denied
chmod 755 build-manylinux2014-wheels.sh

docker run -u root -v $PWD:/tmp/workspace quay.io/pypa/manylinux2014_aarch64 /tmp/workspace/build-manylinux2014-wheels.sh

# sort out wheel files for publishing

COPY_FROM=${WORKSPACE}/wheels/

for pkg in wheelhouse/*.whl
do
  pkgdir=$(echo `basename $pkg`|cut -d'-' -f1 | tr '[:upper:]_' '[:lower:]-')
  pkgfile=$(basename $pkg)

  # do we have this package in cache already?
  status=$(curl --head --silent https://snapshots.linaro.org/ldcg/python-cache/${pkgdir}/${pkgfile} | head -n 1)

  if $(echo $status | grep -q 404); then
    mkdir -p "${COPY_FROM}/${pkgdir}"
    cp $pkg  "${COPY_FROM}/${pkgdir}/"
  fi
done
