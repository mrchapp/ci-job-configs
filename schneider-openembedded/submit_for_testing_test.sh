#!/bin/bash

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git
pushd configs
git log -1
popd

