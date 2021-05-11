#!/bin/bash

set -xe

cd /tmp/workspace

# remove wheels and wheelhouse/ from previous jobs
# we do it here as they are root:root
rm -rf wheel* *.whl cache*

git clone --depth 1 https://git.linaro.org/ci/job/configs.git                                                                                                                
                                                                                                                                                                             
cd configs/ldcg-python-manylinux-tensorflow/ansible
                                                                                                                                                                             
ansible-playbook playbooks/build-tf.yml
