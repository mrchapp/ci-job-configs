#!/bin/bash

set -xe

# Ansible is noarch so we can just grab it from x86-64 repo
yum install -y centos-release-ansible-29
yum install -y ansible

cd /tmp/workspace

# remove wheels and venvs from previous jobs
# we do it here as they are root:root
rm -rf wheels *.whl cache* venv-*

cd configs/ldcg-python-manylinux-tensorflow/ansible

ansible-playbook playbooks/build-tf.yml
