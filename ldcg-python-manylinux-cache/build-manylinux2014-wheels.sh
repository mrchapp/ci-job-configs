#!/bin/bash

set -xe

source var.sh

# some packages require deps from EPEL
yum install -y epel-release

# if one of dependencies is missing or wrong then exit
yum install -y ${EXTRA_DEPENDENCIES_CENTOS} || exit

cd /tmp/wheels

# create virtualenv for each Python version
# and update pip as we want 19+
for py in /opt/python/cp3[6789]*
do
    pyver=`basename $py`
    $py/bin/python -mvenv /tmp/$pyver
    source /tmp/$pyver/bin/activate
    pip install -U pip wheel
    deactivate
done

for pkg in $PYTHON_PACKAGES
do
    for py in /opt/python/cp3[6789]*
    do
        pyver=`basename $py`
        pkgname=`echo $pkg | cut -d'=' -f1`
        echo $pkgname
        source /tmp/$pyver/bin/activate
        pip wheel $pkg
        auditwheel repair ${pkgname}*${pyver}-linux_aarch64.whl
        deactivate
    done
done
