#!/bin/bash

set -xe

source "$(dirname $0)/vars.sh"

# some packages require deps from EPEL
yum install -y epel-release

if ! [ -z $EXTRA_DEPENDENCIES_CENTOS ]; then
    # if one of dependencies is missing or wrong then exit
    yum install -y ${EXTRA_DEPENDENCIES_CENTOS} || exit
fi

cd /tmp/workspace

# remove wheels and wheelhouse/ from previous jobs
# we do it here as they are root:root
rm -rf wheel* *.whl

# let use our own cache
# TODO(hrw): enable after populating it with manylinux2014 files
export PIP_EXTRA_INDEX_URL="https://snapshots.linaro.org/ldcg/python-cache/"

# make use of all CPU cores for some builds
export NPY_NUM_BUILD_JOBS="$(nproc)"
export GRPC_PYTHON_BUILD_EXT_COMPILER_JOBS="$(nproc)"

# create virtualenv for each Python version
# and update pip as we want 19+
for py in /opt/python/cp3[67891]*
do
    pyver=`basename $py`
    $py/bin/python -mvenv /tmp/$pyver
    source /tmp/$pyver/bin/activate
    pip install -U pip
    pip install wheel ${EXTRA_PYTHON_PACKAGES}
    deactivate
done

for pkg in $PYTHON_PACKAGES
do
    for py in /opt/python/cp3[67891]*
    do
        pyver=`basename $py`
        source /tmp/$pyver/bin/activate
        pkgname=$(python3 -c "import re;print(re.split(r'([<=>~]*)=', '${pkg}')[0])")
        pip wheel $pkg || true
        auditwheel repair $(ls -ct1 ${pkgname}*whl |head -n1) || true
        deactivate
    done
done
