#!/bin/bash

set -xe

# Ansible is noarch so we can just grab it from x86-64 repo
yum install -y http://mirror.centos.org/centos/7/configmanagement/x86_64/ansible-29/Packages/a/ansible-2.9.18-1.el7.noarch.rpm

cd /tmp/workspace

# remove wheels and wheelhouse/ from previous jobs
# we do it here as they are root:root
rm -rf wheel* *.whl cache*

git clone --depth 1 https://git.linaro.org/ci/job/configs.git                                                                                                                
                                                                                                                                                                             
cd configs/ldcg-python-manylinux-tensorflow/ansible
                                                                                                                                                                             
ansible-playbook playbooks/build-tf.yml
