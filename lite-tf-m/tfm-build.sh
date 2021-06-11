#!/bin/bash
# Copyright (c) 2020, Linaro. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# Exit on error
set -e

# Cleanup previous build artifacts
rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake install bl2 secure_fw app unit_test test

# Set the readlink binary name:
if [ "$(uname)" == "Darwin" ]; then
    # For OS X this should be be 'greadlink' (brew install coreutils)
    readlink=greadlink
else
    # For Linux this should be 'readlink'
    readlink=readlink
fi

# Set the config file to use
#configfile=ConfigRegression

#target=AN521

# Generate the S and NS makefiles
#cmake -G"Unix Makefiles" \
#        -DPROJ_CONFIG=`$readlink -f ../configs/$configfile.cmake` \
#        -DTARGET_PLATFORM=$target \
#        -DCMAKE_BUILD_TYPE=Debug \
#        -DBL2=False \
#        -DCOMPILER=GNUARM \
#        ../

cmake -DTFM_PLATFORM=mps2/an521 \
      -DCMAKE_TOOLCHAIN_FILE=../toolchain_GNUARM.cmake \
      -DCMAKE_BUILD_TYPE=Debug \
      -DBL2=False \
      -DTEST_S=ON -DTEST_NS=ON \
      -DTFM_TEST_REPO_PATH=../../tf-m-tests \
      ../

# Build the binaries
make install

# Convert S and NS binaries to .hex file
arm-none-eabi-objcopy -S --gap-fill 0xff -O ihex \
        install/outputs/*/*/tfm_s.axf tfm_s.hex
arm-none-eabi-objcopy -S --gap-fill 0xff -O ihex \
        install/outputs/*/*/tfm_ns.axf tfm_ns.hex

# Generate a single hex file for convenience/QEMU sake
srec_cat tfm_s.hex -Intel tfm_ns.hex -Intel -o tfm_full.hex -Intel
