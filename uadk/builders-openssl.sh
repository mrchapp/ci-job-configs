#!/bin/bash -e

if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

echo "#${BUILD_NUMBER}-${ghprbActualCommit:0:8}" > ${WORKSPACE}/version.txt

# Build dependencies already pre-installed on the node
#sudo apt update -q=2
#sudo apt install -q=2 --yes --no-install-recommends zlib1g-dev libnuma-dev

# clean up directories
rm -rf uadk-master uadk-shared-v2

# use UADK master
git clone --depth 1 https://github.com/Linaro/uadk.git ${WORKSPACE}/uadk-master
cd ${WORKSPACE}/uadk-master
autoreconf -vfi

# shared build for v2
./configure \
  --host aarch64-linux-gnu \
  --target aarch64-linux-gnu \
  --prefix=${WORKSPACE}/uadk-shared-v2/usr/local \
  --includedir=${WORKSPACE}/uadk-shared-v2/usr/local/include/uadk \
  --disable-static \
  --enable-shared
make -j$(nproc)
make install && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-shared-v2/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/include/ \
  ${WORKSPACE}/uadk-master/test/sanity_test.sh

cd ${WORKSPACE}/uadk
autoreconf -vfi

./configure \
  --prefix=${WORKSPACE}/uadk-shared-v2/usr/local \
  --libdir=${WORKSPACE}/uadk-shared-v2/usr/local/lib/engines-1.1
LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib \
LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib \
C_INCLUDE_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/include \
make -j$(nproc)
make install && make clean

sudo \
  LD_LIBRARY_PATH=/usr/local/lib:${WORKSPACE}/uadk-shared-v2/usr/local/lib \
  ${WORKSPACE}/uadk/test/sanity_test.sh \
  ${WORKSPACE}/uadk-shared-v2/usr/local/lib/engines-1.1/uadk.so

cd ${WORKSPACE}
tar -cJf uadk-openssl.tar.xz uadk-*-v*/
