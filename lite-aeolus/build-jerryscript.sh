timeout 8m make -f ./targets/zephyr/Makefile.zephyr BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp build/${PLATFORM}/zephyr/zephyr/zephyr.bin out/${PLATFORM}/
