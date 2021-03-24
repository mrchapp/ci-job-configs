#!/bin/bash

set -xe

rm -rf ${WORKSPACE}/*

if [ -e /etc/debian_version ]; then
    echo "deb http://deb.debian.org/debian/ buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y ansible/buster-backports
else
    sudo dnf -y distrosync
    sudo dnf -y install centos-release-ansible-29
    sudo dnf -y install ansible git python36
fi

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-cache/ansible

# generate yaml with vars

echo "python_packages:" >> vars/vars.yml

for pkg in $PYTHON_PACKAGES
do
    echo "  - ${pkg}" >> vars/vars.yml
done

echo "extra_dependencies_debian:" >> vars/vars.yml
echo "  - python3-dev" >> vars/vars.yml

for pkg in $EXTRA_DEPENDENCIES_DEBIAN
do
    echo "  - ${pkg}" >> vars/vars.yml
done

echo "extra_dependencies_centos:" >> vars/vars.yml
echo "  - python3-devel" >> vars/vars.yml

for pkg in $EXTRA_DEPENDENCIES_CENTOS
do
    echo "  - ${pkg}" >> vars/vars.yml
done

ansible-playbook -i inventory playbooks/run.yml
